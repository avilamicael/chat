# Requirements: Chatwoot Commercial Fork

**Defined:** 2026-05-11
**Core Value:** Atendimento omnichannel com workflow visual (Kanban) e integrações de saída confiáveis e seguras com o ecossistema externo do cliente.

**Milestone v1.0:** Webhook Hardening — tornar o sistema de webhooks do Kanban vendável como integração profissional para CRMs/automações.

## v1 Requirements

Requirements para release v1.0 (Webhook Hardening). Each maps to a roadmap phase.

### Reliability

Garantir que webhooks são entregues mesmo quando o receptor está instável, e que falhas em um receptor não afetam outras automações do sistema.

- [ ] **HARD-01**: `Kanban::WebhookJob` faz retry automático com backoff exponencial quando o receptor retorna 5xx ou timeout (reusa `CustomExceptions::Webhook::RetriableError` + Sidekiq retry nativo)
- [ ] **HARD-03**: `Kanban::WebhookJob` roda em fila Sidekiq dedicada `:webhooks` (não mais `:default`), com configuração de concorrência isolada
- [ ] **HARD-06**: Cada evento de webhook tem um identificador único (`X-Webhook-Id: <uuid>`) propagado nos retries, permitindo que o receptor faça deduplicação

### Security

Permitir que o receptor valide autenticidade do payload — sem isso, qualquer um que descobrir a URL pode enviar payloads forjados.

- [ ] **HARD-02**: Webhook envia header `X-Chatwoot-Signature: sha256=<hmac>` calculado com secret persistido por board (ou por account — decisão a refinar no plan-phase). Secret é gerado automaticamente, exibido uma vez na UI, e pode ser rotacionado.

### Observability

Permitir que o cliente debug e opere a integração sem precisar abrir ticket de suporte.

- [ ] **HARD-04**: Tela "Log de Entregas" em Configurações da Coluna mostra últimos N envios com: status code, tempo de resposta, retry count, timestamp e payload enviado. Persiste localmente (DB próprio, retenção configurável).
- [ ] **HARD-05**: Botão "Testar webhook" na config da coluna envia payload de exemplo (estrutura igual à real, com `event: kanban.test`) e mostra o resultado inline.
- [ ] **HARD-07**: No log de entregas, botão "Reenviar" em entregas falhas dispara um novo job mantendo o `X-Webhook-Id` original (para dedup correto no receptor).

## v2 Requirements

Reconhecidas mas adiadas — não entram no v1.0.

### Multi-target & Filtering

- **MULT-01**: Múltiplas URLs por coluna (fan-out interno) — adiado, cliente compõe via n8n/Make.
- **FILT-01**: Toggle "incluir últimas X mensagens da conversation no payload" — adiado, padrão atual é fire-trigger-then-pull.

### Advanced Security

- **SECG-01**: Rate limiting por board/destination URL para prevenir abuso de "testar webhook".
- **SECG-02**: IP allowlist por board (receptor declara IPs de origem aceitos).

## Out of Scope

Exclusões explícitas — documentadas para prevenir re-adicionamento.

| Feature | Reason |
|---------|--------|
| Múltiplas URLs por coluna | Cliente compõe externamente (n8n/Make/Zapier fan-out). Mantém escopo focado em "webhook que sai bem", não em orquestração de webhooks. |
| Conteúdo de mensagens no payload | Padrão Stripe/GitHub: webhook é gatilho, não data dump. Receptor faz follow-up call em `GET /api/v1/accounts/X/conversations/Y/messages`. |
| Camada de retry custom | Sidekiq nativo + `CustomExceptions::Webhook::RetriableError` já cobrem. Construir retry próprio seria reinventar a roda. |
| JWT como auth method | HMAC é padrão da indústria de webhooks (Stripe, GitHub, Slack). JWT adicionaria complexidade sem ganho. |
| Webhook UI fora da config da coluna (página dedicada) | Log e teste ficam contextuais à coluna que dispara. Página global de "todos os webhooks" pode vir em v2 se cliente pedir. |

## Traceability

Mapeamento gerado pelo `/gsd-roadmapper` em 2026-05-11.

| Requirement | Phase | Status |
|-------------|-------|--------|
| HARD-01 | Phase 1 — Reliability Foundation | Pending |
| HARD-02 | Phase 2 — HMAC Signature | Pending |
| HARD-03 | Phase 1 — Reliability Foundation | Pending |
| HARD-04 | Phase 3 — Delivery Observability | Pending |
| HARD-05 | Phase 3 — Delivery Observability | Pending |
| HARD-06 | Phase 1 — Reliability Foundation | Pending |
| HARD-07 | Phase 3 — Delivery Observability | Pending |

**Coverage:**
- v1 requirements: 7 total
- Mapped to phases: 7 (100%)
- Unmapped: 0 ✓

**Per-phase requirement count:**
- Phase 1 (Reliability Foundation): 3 requirements (HARD-01, HARD-03, HARD-06)
- Phase 2 (HMAC Signature): 1 requirement (HARD-02)
- Phase 3 (Delivery Observability): 3 requirements (HARD-04, HARD-05, HARD-07)

---
*Requirements defined: 2026-05-11*
*Last updated: 2026-05-11 — traceability filled by /gsd-roadmapper*
