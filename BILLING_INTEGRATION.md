# Integração de Billing Externo com Chatwoot

> Documento de referência para construção do backend externo de gestão de planos + integração Stripe/AbacatePay.
> Última atualização: 2026-04-15

---

## 1. Visão Geral da Arquitetura

```
┌──────────────┐         ┌──────────────────┐         ┌──────────────────┐
│  Stripe /    │webhook  │  Backend Externo │ PATCH   │   Chatwoot       │
│  AbacatePay  │────────▶│  (a construir)   │────────▶│   Platform API   │
└──────────────┘         │                  │         │                  │
                         │  - Planos        │         │  - Account       │
┌──────────────┐         │  - Assinaturas   │         │  - User          │
│  Landing     │         │  - Trials        │         │  - Limits        │
│  Page /      │────────▶│  - Overrides     │         │  - Features      │
│  Dashboard   │         │  - Admin UI      │         │  - Custom Attrs  │
└──────────────┘         └──────────────────┘         └──────────────────┘
```

**Princípios:**
- **Backend externo é fonte da verdade** de planos, preços, assinaturas
- **Chatwoot é consumidor burro** — só executa o que a Platform API mandar
- **Super Admin do Chatwoot** usado apenas em emergência (backend fora do ar)
- **Tudo atômico:** 1 PATCH aplica plano inteiro (limits + features + custom_attributes)

---

## 2. Autenticação — PlatformApp

O Chatwoot expõe uma Platform API projetada para sistemas externos ("service accounts") gerenciarem contas, usuários e permissões.

### 2.1 Criar o PlatformApp

1. Logar como Super Admin: `http://<host>/super_admin/platform_apps`
2. Clicar em **New Platform App**
3. Nome: `Billing Backend` (ou similar)
4. Após criar, copiar o `access_token` gerado
5. Guardar o token de forma segura no backend externo (variável de ambiente)

### 2.2 Usar o token

Todas as requisições Platform API exigem o header:

```
api_access_token: <access_token_do_platform_app>
Content-Type: application/json
```

### 2.3 Regra de Permissibles (IMPORTANTE)

Um PlatformApp só enxerga recursos que **ele próprio criou** (ou foram explicitamente vinculados via `platform_app_permissibles`).

- Criou o PlatformApp **antes** das contas existirem → tudo bem, ele verá as novas
- Criou o PlatformApp **depois** de já ter contas → precisa vincular manualmente via Rails console:

```ruby
# Vincular todas as contas existentes ao PlatformApp
app = PlatformApp.find_by(name: "Billing Backend")
Account.find_each do |account|
  app.platform_app_permissibles.find_or_create_by!(permissible: account)
end

# Idem para usuários (se o backend externo precisar mexer em users existentes)
User.find_each do |user|
  app.platform_app_permissibles.find_or_create_by!(permissible: user)
end
```

---

## 3. Endpoints Platform API — Referência Completa

Base URL: `https://<seu-chatwoot>/platform/api/v1`

### 3.1 Accounts

| Método | Endpoint | Ação |
|--------|----------|------|
| GET | `/accounts` | Listar contas do PlatformApp |
| GET | `/accounts/:id` | Ver conta |
| POST | `/accounts` | Criar conta |
| PATCH | `/accounts/:id` | Atualizar (plano, limites, features, status) |
| DELETE | `/accounts/:id` | Deletar conta (assíncrono) |

**Payload completo aceito (create/update):**

```json
{
  "name": "Acme Inc",
  "locale": "pt_BR",
  "domain": "acme.chatwoot.com",
  "support_email": "suporte@acme.com",
  "status": "active",
  "limits": {
    "agents": 10,
    "inboxes": 5,
    "captain_responses": 500,
    "captain_documents": 100,
    "emails": 1000,
    "kanban_boards": 3
  },
  "features": {
    "sla": true,
    "captain_integration": true,
    "custom_roles": false,
    "kanban": true
  },
  "custom_attributes": {
    "plan_name": "pro",
    "plan_expires_at": "2026-05-15",
    "subscribed_quantity": 10,
    "billing_provider": "stripe",
    "billing_customer_id": "cus_xxx",
    "billing_subscription_id": "sub_xxx"
  }
}
```

**Resposta (create):** 200 OK com o objeto `Account`.

**Notas:**
- `status`: `"active"` ou `"suspended"`. Conta suspensa fica inacessível.
- `limits`: jsonb — só aceita as chaves listadas no schema (`enterprise/app/models/enterprise/account/plan_usage_and_limits.rb`). Chave desconhecida dá erro de validação.
- `features`: apenas booleanos. Chave não listada em `config/features.yml` é ignorada (não dá erro).
- `custom_attributes`: jsonb totalmente livre — use para metadados do backend externo.

### 3.2 Users

| Método | Endpoint | Ação |
|--------|----------|------|
| POST | `/users` | Criar usuário |
| GET | `/users/:id` | Ver usuário |
| PATCH | `/users/:id` | Atualizar usuário |
| DELETE | `/users/:id` | Deletar usuário |
| GET | `/users/:id/login` | Gerar SSO URL (login automático) |
| POST | `/users/:id/token` | Gerar token de acesso do usuário |

**Payload (create/update):**

```json
{
  "name": "Maria Silva",
  "display_name": "Maria",
  "email": "maria@acme.com",
  "password": "senha_inicial",
  "custom_attributes": {
    "external_user_id": "user_123"
  }
}
```

**SSO — login transparente:**
`GET /users/:id/login` retorna `{ "url": "https://..." }`. O backend externo pode gerar esse link e redirecionar o usuário logado no dashboard externo direto para dentro do Chatwoot, sem pedir senha.

**Detalhe:** `create` faz `find_or_initialize` pelo email — chamar duas vezes com mesmo email não duplica.

### 3.3 Account Users (vincular usuário a uma conta)

| Método | Endpoint | Ação |
|--------|----------|------|
| GET | `/accounts/:account_id/account_users` | Listar usuários da conta |
| POST | `/accounts/:account_id/account_users` | Vincular usuário com papel |
| DELETE | `/accounts/:account_id/account_users` | Remover usuário da conta |

**Payload (POST):**

```json
{
  "user_id": 42,
  "role": "administrator"
}
```

**Papéis disponíveis:**
- `"administrator"` — acesso total à conta
- `"agent"` — acesso limitado (sem configurações)

**Payload (DELETE):**

```json
{
  "user_id": 42
}
```

### 3.4 Agent Bots

| Método | Endpoint | Ação |
|--------|----------|------|
| GET | `/agent_bots` | Listar bots |
| POST | `/agent_bots` | Criar bot |
| PATCH | `/agent_bots/:id` | Atualizar |
| DELETE | `/agent_bots/:id` | Deletar |
| DELETE | `/agent_bots/:id/avatar` | Remover avatar |

Payload: `name`, `description`, `account_id`, `outgoing_url`, `avatar_url`.

---

## 4. Fluxos de Integração

### 4.1 Onboarding — cliente paga pela primeira vez

```
Stripe webhook: checkout.session.completed
     │
     ▼
Backend Externo:
  1. Identifica o plano comprado (pelo price_id)
  2. POST /users (cria usuário Chatwoot com email do cliente)
  3. POST /accounts (cria conta com limits/features do plano)
  4. POST /accounts/:id/account_users { user_id, role: "administrator" }
  5. GET /users/:id/login (gera SSO)
  6. Envia email para cliente com link de acesso (SSO URL)
```

**Implementação Postman para testar:**

```http
### 1. Criar usuário
POST {{base_url}}/platform/api/v1/users
api_access_token: {{token}}
Content-Type: application/json

{
  "name": "Cliente Teste",
  "email": "cliente@teste.com",
  "password": "SenhaForte123!"
}

### 2. Criar conta
POST {{base_url}}/platform/api/v1/accounts
api_access_token: {{token}}
Content-Type: application/json

{
  "name": "Empresa Teste",
  "locale": "pt_BR",
  "limits": { "agents": 5, "inboxes": 3, "kanban_boards": 2 },
  "features": { "kanban": true, "macros": true, "captain_integration": false },
  "custom_attributes": {
    "plan_name": "starter",
    "plan_expires_at": "2026-05-15",
    "billing_provider": "stripe"
  }
}

### 3. Vincular usuário à conta
POST {{base_url}}/platform/api/v1/accounts/{{account_id}}/account_users
api_access_token: {{token}}
Content-Type: application/json

{
  "user_id": {{user_id}},
  "role": "administrator"
}

### 4. Gerar SSO para o cliente
GET {{base_url}}/platform/api/v1/users/{{user_id}}/login
api_access_token: {{token}}
```

### 4.2 Upgrade/Downgrade de plano

```
Stripe webhook: customer.subscription.updated
     │
     ▼
Backend Externo:
  1. Busca Account.id pelo billing_customer_id em custom_attributes
  2. PATCH /accounts/:id com novo limits + features + custom_attributes
```

**1 única chamada atualiza tudo:**

```http
PATCH {{base_url}}/platform/api/v1/accounts/{{account_id}}
api_access_token: {{token}}
Content-Type: application/json

{
  "limits": { "agents": 20, "inboxes": 10, "kanban_boards": 10 },
  "features": { "sla": true, "captain_integration": true, "custom_roles": true },
  "custom_attributes": {
    "plan_name": "business",
    "plan_expires_at": "2026-05-15"
  }
}
```

### 4.3 Cancelamento / Pagamento falhou

```
Stripe webhook: customer.subscription.deleted OU invoice.payment_failed
     │
     ▼
Backend Externo:
  - Opção A (soft): PATCH limits zerados + features desligadas, mas conta ativa (usuário pode ver histórico)
  - Opção B (hard): PATCH status: "suspended"
```

### 4.4 Expiração de plano (job diário)

O Chatwoot **não** tem enforcement nativo de expiração. O backend externo deve rodar cron diário:

```
Cada 24h, backend externo:
  1. SELECT accounts WHERE plan_expires_at < NOW() AND status = 'active'
  2. Para cada uma: PATCH /accounts/:id { status: "suspended" }
  3. Notificar cliente por email
```

Alternativa: cron consulta seus próprios dados internos de assinatura em vez de `custom_attributes.plan_expires_at` no Chatwoot.

### 4.5 Override manual (dar X dias de bônus, liberar feature extra)

**Sempre no backend externo, nunca direto no Chatwoot.**

```
Admin do backend externo:
  1. Clica "Estender trial +7 dias" no cliente Y
  2. Backend atualiza sua própria tabela de assinatura
  3. Backend faz PATCH no Chatwoot com novo plan_expires_at
  4. Log no backend: quem fez, quando, por quê
```

Para liberar uma feature pontual:

```http
PATCH {{base_url}}/platform/api/v1/accounts/{{account_id}}
{
  "features": { "sla": true }
}
```

---

## 5. Catálogo de Features (63 disponíveis)

Liga/desliga via `features: { nome: true|false }` no PATCH.

### 5.1 Comunicação & Canais

| Feature | Descrição |
|---------|-----------|
| `inbound_emails` | Emails recebidos |
| `channel_email` | Canal Email |
| `channel_facebook` | Canal Facebook |
| `channel_website` | Canal Website/Widget |
| `channel_instagram` | Canal Instagram |
| `channel_tiktok` | Canal TikTok |
| `channel_voice` 💎 | Canal de Voz |
| `email_continuity_on_api_channel` | Continuidade email em canal API |
| `custom_reply_email` | Email de resposta customizado |
| `custom_reply_domain` | Domínio de resposta customizado |
| `quoted_email_reply` | Citar email original na resposta |
| `voice_recorder` | Gravador de áudio |

### 5.2 Colaboração & Organização

| Feature | Descrição |
|---------|-----------|
| `agent_management` | Gestão de agentes |
| `team_management` | Gestão de times |
| `inbox_management` | Gestão de caixas |
| `labels` | Etiquetas |
| `macros` | Macros |
| `canned_responses` | Respostas prontas |
| `custom_attributes` | Atributos customizados |
| `agent_bots` | Bots de atendimento |
| `auto_resolve_conversations` | Auto-resolução |
| `assignment_v2` | Nova lógica de atribuição |
| `advanced_assignment` 💎 | Atribuição avançada |

### 5.3 Automação & Qualidade

| Feature | Descrição |
|---------|-----------|
| `automations` | Regras de automação |
| `sla` 💎 | SLAs |
| `conversation_required_attributes` 💎 | Atributos obrigatórios |
| `csat_review_notes` 💎 | Notas em reviews CSAT |

### 5.4 IA

| Feature | Descrição |
|---------|-----------|
| `captain_integration` 💎 | Captain (IA) |
| `captain_integration_v2` 💎 | Captain V2 |
| `captain_tasks` | Tarefas via Captain |

### 5.5 Kanban (seu fork)

| Feature | Descrição |
|---------|-----------|
| `kanban` 💎 | Módulo Kanban/Funis |

> Limite numérico de boards: use `limits.kanban_boards` (ver seção 6).

### 5.6 Ajuda & Conteúdo

| Feature | Descrição |
|---------|-----------|
| `help_center` | Central de ajuda |

### 5.7 Reports & Analytics

| Feature | Descrição |
|---------|-----------|
| `reports` | Relatórios |
| `report_rollup` | Agregação de relatórios |

### 5.8 Integrações

| Feature | Descrição |
|---------|-----------|
| `integrations` | Módulo de integrações |
| `linear_integration` | Linear |
| `notion_integration` | Notion |
| `crm` | CRM genérico |
| `crm_integration` | Integração CRM externa |
| `campaigns` | Campanhas |
| `whatsapp_campaign` | Campanhas WhatsApp |

### 5.9 Enterprise / Governança

| Feature | Descrição |
|---------|-----------|
| `custom_roles` 💎 | Papéis customizados |
| `audit_logs` 💎 | Logs de auditoria |
| `saml` 💎 | SAML SSO |
| `disable_branding` 💎 | White-label |
| `ip_lookup` | Lookup de IP |

### 5.10 Outras

| Feature | Descrição |
|---------|-----------|
| `chatwoot_v4` | UI V4 |

**Legenda:** 💎 = `premium: true` em `config/features.yml`.

**Features marcadas `deprecated` ou `chatwoot_internal`:** ignorar, não incluir nos planos. Lista completa em `config/features.yml`.

---

## 6. Catálogo de Limits

Aplicados via `limits: { chave: numero }` no PATCH. Schema validado em `enterprise/app/models/enterprise/account/plan_usage_and_limits.rb`.

| Chave | Recurso limitado | Enforçado em |
|-------|------------------|--------------|
| `agents` | Número máximo de agentes | `agents_controller.rb#validate_limit` |
| `inboxes` | Número máximo de caixas de entrada | Model/validação |
| `captain_responses` | Respostas Captain por mês | Contador mensal em `custom_attributes` |
| `captain_documents` | Documentos Captain total | Contador em `custom_attributes` |
| `emails` | Rate limit de emails (por hora) | Job de envio |
| `kanban_boards` | Número máximo de boards Kanban | `kanban_boards_controller.rb#validate_board_limit` |

**Comportamento quando chave não está setada:** `ChatwootApp.max_limit` (ilimitado).
**Comportamento quando chave é `0`:** bloqueia criação totalmente.

**Exemplo de plano com limites zerados (ex: downgrade para free):**
```json
{ "limits": { "agents": 1, "inboxes": 1, "kanban_boards": 0 } }
```

---

## 7. Modelo de Planos Sugerido (para o backend externo)

Estrutura que cabe num JSON de configuração estática ou tabela no DB do backend:

```javascript
// Starter é o "menor denominador comum" — só WhatsApp (Baileys), 2 agentes, 1 inbox.
// Cada plano superior acrescenta limites e features explicitamente. Um `false` explícito
// é importante: ele DESLIGA features que podem estar ativadas em features.yml por default.
const PLANS = {
  starter: {
    name: "Starter",
    price_brl: 4900,              // R$ 49
    stripe_price_id: "price_xxx",
    abacatepay_product_id: "prod_xxx",
    limits: {
      agents: 2,
      inboxes: 1,
      kanban_boards: 1,
      captain_responses: 0,
      captain_documents: 0,
      emails: 100
    },
    features: {
      // Canais: só WhatsApp (via Baileys, não tem flag)
      inbound_emails: false,
      channel_email: false,
      channel_facebook: false,
      channel_website: false,
      channel_instagram: false,
      channel_tiktok: false,
      channel_voice: false,
      custom_reply_email: false,
      custom_reply_domain: false,

      // Produtividade básica
      kanban: true,
      labels: true,
      macros: true,
      canned_responses: true,
      agent_management: true,
      inbox_management: true,
      team_management: true,
      custom_attributes: true,
      auto_resolve_conversations: true,
      reports: true,
      voice_recorder: true,
      automations: true,
      crm: true,

      // Bloqueadas no starter (explicitamente)
      companies: false,
      captain_integration: false,
      captain_integration_v2: false,
      captain_tasks: false,
      sla: false,
      custom_roles: false,
      audit_logs: false,
      disable_branding: false,
      campaigns: false,
      whatsapp_campaign: false,
      saml: false,
      advanced_search: false,
      advanced_assignment: false,
      conversation_required_attributes: false,
      csat_review_notes: false,
      help_center: false
    }
  },
  pro: {
    name: "Pro",
    price_brl: 14900,
    limits: {
      agents: 10,
      inboxes: 5,
      kanban_boards: 5,
      captain_responses: 500,
      captain_documents: 50,
      emails: 1000
    },
    features: {
      // Canais: WhatsApp + email + website
      inbound_emails: true,
      channel_email: true,
      channel_website: true,
      channel_facebook: false,
      channel_instagram: false,
      channel_tiktok: false,
      channel_voice: false,

      // Tudo do starter
      kanban: true,
      labels: true,
      macros: true,
      canned_responses: true,
      agent_management: true,
      inbox_management: true,
      team_management: true,
      custom_attributes: true,
      auto_resolve_conversations: true,
      reports: true,
      voice_recorder: true,
      automations: true,
      crm: true,
      help_center: true,
      campaigns: true,
      whatsapp_campaign: true,

      // Novidades do Pro
      sla: true,
      captain_integration: true,
      captain_integration_v2: true,
      captain_tasks: true,

      // Ainda bloqueado no Pro
      companies: false,
      custom_roles: false,
      audit_logs: false,
      disable_branding: false,
      saml: false,
      advanced_search: false,
      advanced_assignment: false,
      conversation_required_attributes: false,
      csat_review_notes: false
    }
  },
  business: {
    name: "Business",
    price_brl: 39900,
    limits: {
      agents: 50,
      inboxes: 20,
      kanban_boards: 999,
      captain_responses: 5000,
      captain_documents: 500,
      emails: 10000
    },
    features: {
      // Todos os canais
      inbound_emails: true,
      channel_email: true,
      channel_website: true,
      channel_facebook: true,
      channel_instagram: true,
      channel_tiktok: true,
      channel_voice: true,

      // Tudo do Pro
      kanban: true,
      labels: true,
      macros: true,
      canned_responses: true,
      agent_management: true,
      inbox_management: true,
      team_management: true,
      custom_attributes: true,
      auto_resolve_conversations: true,
      reports: true,
      voice_recorder: true,
      automations: true,
      crm: true,
      help_center: true,
      campaigns: true,
      whatsapp_campaign: true,
      sla: true,
      captain_integration: true,
      captain_integration_v2: true,
      captain_tasks: true,

      // Exclusivo do Business
      companies: true,
      custom_roles: true,
      audit_logs: true,
      disable_branding: true,
      saml: true,
      advanced_assignment: true,
      conversation_required_attributes: true,
      csat_review_notes: true
    }
  }
}

function buildPatchPayload(planKey, customerOverrides = {}) {
  const plan = PLANS[planKey];
  return {
    limits: { ...plan.limits, ...customerOverrides.limits },
    features: { ...plan.features, ...customerOverrides.features },
    custom_attributes: {
      plan_name: planKey,
      plan_expires_at: customerOverrides.expires_at,
      billing_provider: customerOverrides.provider,
      billing_customer_id: customerOverrides.customer_id,
      billing_subscription_id: customerOverrides.subscription_id
    }
  };
}
```

---

## 8. Integração Stripe — Eventos Relevantes

| Evento Stripe | O que fazer no Chatwoot |
|---------------|-------------------------|
| `checkout.session.completed` | Criar Account + User + vincular |
| `customer.subscription.created` | PATCH Account com plano |
| `customer.subscription.updated` | PATCH Account com novo plano (upgrade/downgrade) |
| `customer.subscription.deleted` | PATCH status=suspended (ou downgrade para free) |
| `invoice.payment_succeeded` | PATCH plan_expires_at (estender) |
| `invoice.payment_failed` | Avisar cliente; após N tentativas, suspender |

**Segurança:**
- Sempre validar assinatura do webhook (`Stripe-Signature` header)
- Guardar `customer.id` do Stripe em `custom_attributes.billing_customer_id` para lookup futuro
- Idempotência: Stripe pode reenviar webhook, use `event.id` como chave de dedupe

---

## 9. Integração AbacatePay — Eventos Relevantes

AbacatePay tem documentação em: https://docs.abacatepay.com/

Fluxo equivalente:
- Criar pagamento PIX → `POST /billing` na API do AbacatePay
- Webhook `billing.paid` → criar/atualizar Account
- Sem renovação automática (PIX não é recorrente) → rodar job de expiração

---

## 10. Estrutura Sugerida para Backend Externo

```
billing-backend/
├── src/
│   ├── plans/
│   │   └── catalog.ts           # PLANS object
│   ├── providers/
│   │   ├── stripe/
│   │   │   ├── webhook.ts       # handler do webhook
│   │   │   └── client.ts
│   │   └── abacatepay/
│   │       ├── webhook.ts
│   │       └── client.ts
│   ├── chatwoot/
│   │   ├── platform-client.ts   # wrapper axios com token
│   │   ├── account-service.ts   # createAccount, updateAccount
│   │   └── user-service.ts
│   ├── admin/
│   │   ├── routes.ts            # UI para overrides manuais
│   │   └── auth.ts
│   ├── jobs/
│   │   └── expire-plans.ts      # cron diário
│   └── db/
│       └── schema.sql           # customers, subscriptions, audit_log
└── .env
    CHATWOOT_BASE_URL=https://...
    CHATWOOT_PLATFORM_TOKEN=...
    STRIPE_SECRET_KEY=...
    STRIPE_WEBHOOK_SECRET=...
    ABACATEPAY_API_KEY=...
```

---

## 11. Testes no Postman — Checklist

Antes de construir o backend, valide os fluxos no Postman:

- [ ] Criar PlatformApp no Super Admin e copiar token
- [ ] `POST /users` — criar usuário teste
- [ ] `POST /accounts` — criar conta teste com plano starter
- [ ] `POST /accounts/:id/account_users` — vincular usuário como admin
- [ ] `GET /users/:id/login` — obter SSO URL, abrir no browser, verificar login automático
- [ ] `PATCH /accounts/:id` — upgrade para pro, verificar se limites mudam na UI do Chatwoot
- [ ] Criar 3 boards Kanban → quarto deve retornar 402
- [ ] `PATCH /accounts/:id { "status": "suspended" }` — verificar que conta fica inacessível
- [ ] `DELETE /accounts/:id` — cleanup

### Variáveis de ambiente Postman

```
base_url         = http://localhost:3000
token            = <access_token_do_platform_app>
account_id       = <preenchido após create>
user_id          = <preenchido após create>
```

---

## 12. Pendências / Considerações Futuras

### No Chatwoot
- [ ] Se precisar de limites novos (`kanban_cards_per_board`, `campaigns`, etc.) — adicionar no schema `plan_usage_and_limits.rb` + enforçar no controller respectivo
- [ ] Considerar endpoint `POST /platform/api/v1/accounts/:id/apply_plan` que aceita `{ plan_name }` e aplica tudo — só se a lógica no backend ficar repetitiva
- [ ] Expor endpoint `GET /platform/api/v1/features` listando features disponíveis (hoje só via `config/features.yml`)

### No Backend Externo
- [ ] Dashboard do cliente (ver plano, invoices, trocar cartão)
- [ ] Impersonate: admin do backend logar como cliente via SSO
- [ ] Relatórios de MRR, churn, conversão trial → pago
- [ ] Migration em lote (se trocar preços/limites de um plano, como aplicar em clientes ativos?)

### Segurança
- [ ] Rotacionar o `access_token` do PlatformApp periodicamente
- [ ] Rate limit no endpoint do webhook para evitar replay
- [ ] Guardar audit log no backend externo de toda mudança de plano (quem, quando, por quê)

---

## 13. Arquivos-chave no Chatwoot (para referência ao implementar)

| Arquivo | Para que serve |
|---------|----------------|
| `app/controllers/platform/api/v1/accounts_controller.rb` | Contrato da Platform API de Accounts |
| `app/controllers/platform/api/v1/users_controller.rb` | Contrato da Platform API de Users |
| `app/controllers/platform/api/v1/account_users_controller.rb` | Vinculação user ↔ account |
| `app/controllers/platform_controller.rb` | Validação de token e permissibles |
| `app/models/platform_app.rb` | Model do PlatformApp |
| `enterprise/app/models/enterprise/account/plan_usage_and_limits.rb` | Schema de limits + leitura de plano |
| `config/features.yml` | Catálogo completo de features |
| `app/controllers/api/v1/accounts/agents_controller.rb:96-106` | Referência de enforcement de limite |
| `app/controllers/api/v1/accounts/kanban_boards_controller.rb` | Enforcement de kanban_boards (implementado nesta sessão) |
