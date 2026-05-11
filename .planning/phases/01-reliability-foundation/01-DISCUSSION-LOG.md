# Discussion Log — Phase 1: Reliability Foundation

**Date:** 2026-05-11
**Mode:** discuss (default)
**Output:** `01-CONTEXT.md` (canonical decisions for downstream agents)

This log is for human reference / retrospective. Downstream agents (researcher, planner, executor) read `01-CONTEXT.md` instead.

## Scout Findings (pre-discussion)

Lightweight codebase scan before presenting gray areas revealed that **the infra needed for Phases 1 + 2 already exists** in the codebase:

| Need | Existing | File:Line |
|------|----------|-----------|
| Retry pattern | `retry_on CustomExceptions::Webhook::RetriableError, wait: :polynomially_longer, attempts: 5` | `app/jobs/webhook_job.rb:3` |
| HMAC signing | `X-Chatwoot-Signature: sha256=#{HMAC(secret, "#{ts}.#{body}")}` (Stripe-style with timestamp prefix) | `lib/webhooks/trigger.rb:50` |
| Delivery ID header | `X-Chatwoot-Delivery` | `lib/webhooks/trigger.rb:47` |
| Retriable exception | `CustomExceptions::Webhook::RetriableError` | `lib/custom_exceptions/webhook.rb` |
| Failure dispatcher | `raise CustomExceptions::Webhook::RetriableError, "Webhook request failed: #{e.message}"` after `StandardError` | `lib/webhooks/trigger.rb:26` |

**Implication:** Phase 1's "build retry + delivery ID" reduces to "consume `Webhooks::Trigger.execute` from `Kanban::WebhookJob`". The original assumption (build from scratch) was wrong. Roadmap header name (`X-Webhook-Id`) had to be aligned with existing convention (`X-Chatwoot-Delivery`) to avoid SDK fragmentation.

## Gray Areas Presented

User selected all 4:

1. ✅ Convergência do job
2. ✅ Nome da fila Sidekiq
3. ✅ Header de delivery ID + persistência
4. ✅ Specs neste phase

## Discussion Turns

### Area 1 — Convergência do job

**Options presented:**
- A — Deletar `Kanban::WebhookJob`, caller usa `WebhookJob` direto com `:kanban_webhook`
- **B — Wrapper magro (selected)** — `Kanban::WebhookJob` mantém classe, delega para `Webhooks::Trigger.execute`
- C — Standalone, copia padrão inline

**Decision:** B (wrapper magro).

**Reasoning surfaced:**
- A acoplaria Kanban a `Webhooks::ErrorHandler.perform`, que filtra por `payload[:event] in %w[message_created message_updated]` — eventos Kanban (`kanban.card_*`) não batem, viraria no-op semantically dirty.
- C duplicaria toda a lógica de `lib/webhooks/trigger.rb` (HMAC, headers, RestClient, timeout). Risco de drift.
- B preserva isolamento, ganha retry/HMAC/delivery_id de graça, e dá ponto de extensão para Phases 2 e 3.

### Area 2 — Nome da fila Sidekiq

**Options:**
- **A — `:medium` (selected)** — matches `WebhookJob` canonical
- B — `:webhooks` nova fila dedicada (intent original do roadmap)
- C — `:low` (defer aggressively)

**Decision:** A (`:medium`).

**Reasoning surfaced:**
- `:medium` é drenado antes de `:default` em `config/sidekiq.yml:21-28` — já dá prioridade efetiva sobre jobs de app comum.
- Adicionar `:webhooks` requereria entender por que upstream Chatwoot escolheu priority-based em vez de per-domain — risco de divergir e dar conflict em rebase futuro.
- Roadmap atualizado: success criterion #2 da Phase 1 e HARD-03 reescritos para refletir `:medium`. Fila dedicada migra para backlog v2 se métricas exigirem.

### Area 3 — Header de delivery ID + persistência

**Options:**
- **A — `X-Chatwoot-Delivery` + in-flight (selected)**
- B — `X-Webhook-Id` (genérico, como roadmap dizia)
- C — `X-Chatwoot-Delivery` + persistir já em Phase 1 (criar tabela)

**Decision:** A.

**Reasoning surfaced:**
- B fragmenta SDK do receptor (mesmo cliente recebe webhooks de canal + Kanban; precisaria checar dois nomes).
- C fundiria Phase 1 com parte de Phase 3 — viola granularity coarse e tira o caráter cirúrgico da Phase 1.
- A reusa convenção existente em `lib/webhooks/trigger.rb:47` e mantém Phase 3 como dona da tabela `kanban_webhook_deliveries`.

**Side-effects:** Edits em `REQUIREMENTS.md` HARD-06, `ROADMAP.md` Phase 1 SC#3, `ROADMAP.md` Phase 2 "Depends on" — todos para renomear `X-Webhook-Id` → `X-Chatwoot-Delivery`.

### Area 4 — Specs

**Options:**
- **A — Criar `spec/jobs/kanban/webhook_job_spec.rb` (selected)**
- B — Pular, validar via UAT

**Decision:** A (override explícito da regra "avoid specs unless asked" do CLAUDE.md do projeto, por backend-critical risk).

**Cobertura mínima definida** (será mandato para o planner):
1. `queue_as :medium`
2. `retry_on` configurado
3. Delega para `Webhooks::Trigger.execute` com args/kwargs corretos (mock)
4. Job re-enqueua em RetriableError
5. Log warn em discard com delivery_id
6. delivery_id propagado intacto em retries

**Padrão a replicar:** `spec/jobs/webhook_job_spec.rb`.

## Follow-up Decisions

### Retry attempts

**Q:** 5 (match canonical) / Sidekiq default 25 / custom 3?
**A:** 5, `wait: :polynomially_longer` (match canonical). Janela ~16min, mesma do main system.

### Discard handler

**Q:** Log only / chamar `Webhooks::ErrorHandler` / criar Conversation activity?
**A:** Log only (`Rails.logger.warn` estruturado). ErrorHandler não aplica (eventos não batem); activity polui timeline.

### Roadmap edit policy

**Q:** Atualizar roadmap+requirements para refletir `X-Chatwoot-Delivery` e `:medium`?
**A:** Sim. Edits aplicados nesta sessão antes de escrever CONTEXT.md.

## Deferred Ideas

- Fila Sidekiq `:webhooks` dedicada — backlog v2, se métricas exigirem.
- Idempotency client-side helper / SDK snippet — não-código, oportunidade de doc comercial.
- Métricas Prometheus — v1.1+ conceitual.

## Files Edited In This Discussion

- `.planning/REQUIREMENTS.md` — HARD-03 e HARD-06 reescritos
- `.planning/ROADMAP.md` — Phase 1 SC#2, Phase 1 SC#3, Phase 2 "Depends on" atualizados
- `.planning/phases/01-reliability-foundation/01-CONTEXT.md` — novo (canonical para downstream)
- `.planning/phases/01-reliability-foundation/01-DISCUSSION-LOG.md` — este arquivo

---
*Discussion completed: 2026-05-11*
