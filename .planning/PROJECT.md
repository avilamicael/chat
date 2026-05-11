# Chatwoot Commercial Fork

## What This Is

Fork comercial do Chatwoot (Rails 7 + Vue 3 + Sidekiq) com features próprias além do upstream — destaque para um sistema de Kanban operacional com colunas, cards e webhooks de transição. O produto é vendido/operado como plataforma white-label de atendimento omnichannel + workflow visual, com integrações de saída para o ecossistema externo do cliente (CRMs, n8n, Make, Zapier).

## Core Value

Atendimento omnichannel com workflow visual (Kanban) e **integrações de saída confiáveis e seguras** com o ecossistema externo — sem isso, o produto vira ferramenta de uso interno, não plataforma vendível.

## Requirements

### Validated

<!-- Capacidades já presentes no codebase mapeado em .planning/codebase/ -->

- ✓ **Atendimento omnichannel** (canais Twilio, Facebook, Instagram, Slack, Email, WebSocket) — herdado do upstream
- ✓ **Integração WhatsApp via Baileys API** (repo sibling `/home/micael/chatwoot_vps/baileys-api`) — customização do fork
- ✓ **Kanban próprio** (boards, colunas, cards) com persistência por conversation
- ✓ **Webhook outbound em transições de coluna** (`kanban.card_entered_column` / `card_left_column`) — funcional mas frágil (ver Active)
- ✓ **Auto-reopen de conversation em nova mensagem**
- ✓ **Multi-tenancy por Account** + Auth (Devise) + Permissões (Pundit) — herdado
- ✓ **Sidekiq + filas + ActionCable broadcasts** — herdado
- ✓ **Infra geral de webhook retry** com `CustomExceptions::Webhook::RetriableError` — existe no sistema amplo, mas `Kanban::WebhookJob` ainda não consome

### Active

<!-- Milestone v1.0 — Webhook Hardening (vender a integração com postura profissional) -->

**Críticos (must antes do lançamento)**
- [ ] **HARD-01**: Retry com backoff exponencial via Sidekiq nativo no `Kanban::WebhookJob`
- [ ] **HARD-02**: Assinatura HMAC (`X-Chatwoot-Signature: sha256=...`) com secret por board ou por account
- [ ] **HARD-03**: Fila Sidekiq dedicada `:webhooks` (isolar lentidão do receptor das outras automações)

**Importantes**
- [ ] **HARD-04**: Log de entregas na UI (Configurações da coluna): últimos N envios com status code, tempo de resposta, retry count
- [ ] **HARD-05**: Botão "Testar webhook" na config da coluna (envia payload de exemplo)
- [ ] **HARD-06**: Idempotency key (`X-Webhook-Id: <uuid>`) — receptor dedupar em caso de retry

**Nice-to-have**
- [ ] **HARD-07**: Botão "reenviar" manualmente um evento que falhou (na tela de log)

### Out of Scope

- **Múltiplas URLs por coluna** — cliente compõe externamente (n8n/Make/Zapier fan-out). Se quiser automação robusta, contrata serviço de automação à parte (nosso ou de terceiros).
- **Incluir conteúdo de mensagens no payload** — receptor faz follow-up call em `GET /api/v1/accounts/X/conversations/Y/messages`. Padrão Stripe/GitHub: webhook é gatilho, não data dump.
- **Camada de retry custom** — Sidekiq retry nativo já cobre, e o projeto já tem `CustomExceptions::Webhook::RetriableError`. Reusar.

## Context

- **Codebase mapeada** em `.planning/codebase/` (commit 56322c13f) — 7 documentos cobrindo stack, integrações, arquitetura, estrutura, convenções, testes e concerns. Use como referência primária ao planejar fases.
- **Webhook system atual** (`app/jobs/kanban/webhook_job.rb`): fire-and-forget, `queue_as :default`, `open_timeout 5s` + `read_timeout 10s`, rescue silencioso via `Rails.logger.error`. Sem retry, sem assinatura, sem persistência de tentativas.
- **Payload atual** já documentado em `.planning/codebase/INTEGRATIONS.md`: `event, board, column, card, conversation (sem mensagens!), contact, assignee`.
- **Workflow legado** de todos em `.planning/todos/` (4 done) continuará coexistindo no início para captura informal.
- **Cliente-alvo**: empresas que rodam SaaS de atendimento e querem integração visual Kanban → CRM/automação externa, sem desenvolver tudo do zero.
- **Posicionamento comercial**: "integração profissional" — retry automático, HMAC, isolamento de fila, observabilidade na UI.

## Constraints

- **Tech stack**: Rails 7 + Vue 3 Composition API (`<script setup>`) + Tailwind + Sidekiq + PostgreSQL — definido pelo upstream Chatwoot, não negociável
- **Estilo**: Tailwind only, no scoped CSS, no inline styles — per `AGENTS.md`
- **Compatibilidade**: não pode quebrar features existentes do Kanban; webhooks atuais (sem assinatura) precisam seguir funcionando para clientes legados durante transição
- **Filosofia**: MVP focus, no defensive programming desnecessário, happy path first — per `AGENTS.md`
- **Auth de webhook**: HMAC (padrão Stripe/GitHub), não JWT
- **Retry**: Sidekiq nativo + reuso de `CustomExceptions::Webhook::RetriableError`, sem camada custom

## Key Decisions

| Decisão | Racional | Outcome |
|---------|----------|---------|
| HMAC com `X-Chatwoot-Signature: sha256=...` para autenticar webhooks | Padrão da indústria (Stripe/GitHub/Slack); mais simples que JWT; receptor valida com biblioteca padrão | — Pending |
| Secret por board (não por account) | Permite cliente isolar credenciais por funil/projeto; revogar 1 secret não derruba todos os webhooks | — Pending (rever no plan-phase se simplificar para por-account) |
| Não incluir conteúdo de mensagens no payload | Webhook é gatilho, não data dump; receptor pull-on-demand via API REST | — Pending |
| Retry com Sidekiq nativo + reuso de `CustomExceptions::Webhook::RetriableError` | Já existe no projeto para o sistema geral de webhooks; reuso vs reinvenção | — Pending |
| Múltiplas URLs por coluna fora do escopo do v1.0 | Cliente compõe via ferramenta externa (n8n/Make); se quer robusto, contrata serviço de automação à parte | — Pending |
| Idempotency key como UUID por evento (não por card) | Retry traz mesmo UUID; novo evento (mesmo card, nova transição) tem UUID diferente | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-11 after initialization (brownfield bootstrap)*
