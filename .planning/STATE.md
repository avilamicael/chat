# State: Chatwoot Commercial Fork

**Initialized:** 2026-05-11

## Project Reference

- **Project doc:** `.planning/PROJECT.md`
- **Core value:** Atendimento omnichannel com workflow visual (Kanban) e integrações de saída confiáveis e seguras com o ecossistema externo do cliente.
- **Current milestone:** v1.0 Webhook Hardening
- **Current focus:** Tornar o sistema de webhooks de Kanban (`app/jobs/kanban/webhook_job.rb`) vendável como integração profissional para CRMs/automações — retry, HMAC, idempotency, observabilidade.

## Current Position

- **Phase:** 1 — Reliability Foundation (context gathered, ready to plan)
- **Plan:** —
- **Status:** Context locked in `01-CONTEXT.md`; awaiting `/gsd-plan-phase 1`
- **Progress:** Phase 0/3 (0% executed); Phase 1 discuss ✓

```
[░░░░░░░░░░░░░░░░░░░░] 0% — 3 phases, 0 complete
Phase 1: ●○○ (discuss done; plan + execute pending)
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

- **Last action:** `/gsd-discuss-phase 1` completed; CONTEXT.md locked with 7 decisions (job shape=wrapper, queue=:medium, attempts=5, header=X-Chatwoot-Delivery, spec=yes, caller patched, retry exhausted=log)
- **Next action:** `/gsd-plan-phase 1` (or `/gsd-progress` to route automatically)
- **Resume file:** `.planning/phases/01-reliability-foundation/01-CONTEXT.md`
- **Files written this session (cumulative):**
  - `.planning/codebase/` (7 docs, commit 56322c13f)
  - `.planning/PROJECT.md` (76751c272)
  - `.planning/config.json` (f1e6a99dc)
  - `.planning/REQUIREMENTS.md` + `.planning/ROADMAP.md` + this STATE.md (7a5614cf5, edits in 0c973d77d)
  - `.planning/phases/01-reliability-foundation/01-CONTEXT.md` + `01-DISCUSSION-LOG.md` (0c973d77d)

---
*State initialized: 2026-05-11*
