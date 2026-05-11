# State: Chatwoot Commercial Fork

**Initialized:** 2026-05-11

## Project Reference

- **Project doc:** `.planning/PROJECT.md`
- **Core value:** Atendimento omnichannel com workflow visual (Kanban) e integrações de saída confiáveis e seguras com o ecossistema externo do cliente.
- **Current milestone:** v1.0 Webhook Hardening
- **Current focus:** Tornar o sistema de webhooks de Kanban (`app/jobs/kanban/webhook_job.rb`) vendável como integração profissional para CRMs/automações — retry, HMAC, idempotency, observabilidade.

## Current Position

- **Phase:** None active (roadmap created, awaiting `/gsd-plan-phase 1`)
- **Plan:** —
- **Status:** Roadmap ready
- **Progress:** Phase 0/3 (0%)

```
[░░░░░░░░░░░░░░░░░░░░] 0% — 3 phases, 0 complete
```

## Performance Metrics

- Roadmap derived from 7 v1 requirements across 3 categories (Reliability, Security, Observability)
- 100% requirement coverage (7/7 HARD-* mapped)
- Granularity: coarse (3 phases matches category boundaries)

## Accumulated Context

### Key Decisions (from PROJECT.md)
- HMAC `X-Chatwoot-Signature: sha256=...` (padrão Stripe/GitHub), não JWT
- Secret por board (não por account) — revisitar no `/gsd-plan-phase 2` se simplificar
- Retry: Sidekiq nativo + reuso `CustomExceptions::Webhook::RetriableError` (sem retry custom)
- Idempotency UUID por evento (não por card) — retry preserva mesmo UUID
- Sem múltiplas URLs por coluna; sem conteúdo de mensagens no payload (gatilho, não data dump)

### Todos
- (none yet — created at phase planning time)

### Blockers
- (none)

### Decisions Pending Plan-Phase
- Phase 2: secret por board vs. secret por account (PROJECT.md flags this for revisit)
- Phase 3: retenção exata do delivery log (sugestão inicial: 100 envios OU 7 dias, o que for menor)
- Phase 3: schema do `kanban_webhook_deliveries` (campos, indexes, FK)

## Codebase Anchors

- **Job to harden:** `app/jobs/kanban/webhook_job.rb` (fire-and-forget atual)
- **Pattern to reuse (retry):** `app/jobs/webhook_job.rb` + `CustomExceptions::Webhook::RetriableError`
- **Pattern to reuse (HMAC):** `lib/webhooks/trigger.rb` line 51 (`OpenSSL::HMAC`)
- **Caller:** `app/services/kanban/column_actions_service.rb` line 30 (enqueues without validation)
- **Tests gap:** `spec/jobs/kanban/` does not exist — zero tests for `Kanban::WebhookJob`
- **Frontend area:** Kanban board/column settings (Vue 3 Composition API, `<script setup>`, Tailwind only)

## Session Continuity

- **Last action:** Roadmapper created `.planning/ROADMAP.md` and this STATE.md
- **Next action:** User runs `/gsd-plan-phase 1` to plan Phase 1 (Reliability Foundation)
- **Files written this session:**
  - `.planning/ROADMAP.md`
  - `.planning/STATE.md`
  - `.planning/REQUIREMENTS.md` (Traceability section updated)

---
*State initialized: 2026-05-11*
