# Roadmap: Chatwoot Commercial Fork — v1.0 Webhook Hardening

**Created:** 2026-05-11
**Granularity:** coarse (3 phases — derived from requirement categories Reliability / Security / Observability)
**Milestone:** v1.0 Webhook Hardening — tornar o sistema de webhooks do Kanban vendável como integração profissional para CRMs/automações externas.
**Coverage:** 7/7 v1 requirements mapped

## Phases

- [ ] **Phase 1: Reliability Foundation** — Job retry com backoff, fila dedicada, idempotency UUID propagado em retries (HARD-01, HARD-03, HARD-06)
- [ ] **Phase 2: HMAC Signature** — Assinatura `X-Chatwoot-Signature: sha256=...` com secret por board, geração/rotação via UI (HARD-02)
- [ ] **Phase 3: Delivery Observability** — Log de entregas na UI, botão testar webhook, botão reenviar evento falho (HARD-04, HARD-05, HARD-07)

## Phase Details

### Phase 1: Reliability Foundation
**Slug:** `reliability-foundation`
**Goal:** Cliente receptor recebe 100% dos eventos de Kanban mesmo quando seu endpoint está temporariamente indisponível ou lento, sem que falhas em um receptor afetem outras automações do sistema.
**Depends on:** Nothing (foundational; foundation for Phases 2 and 3)
**Requirements:** HARD-01, HARD-03, HARD-06
**Success Criteria** (what must be TRUE):
  1. Quando o receptor retorna 5xx ou timeout, o webhook é re-tentado automaticamente com backoff exponencial via Sidekiq nativo, e a entrega chega ao receptor se ele voltar dentro de ~30 minutos (janela do Sidekiq retry default).
  2. `Kanban::WebhookJob` roda em fila Sidekiq `:medium` (mesma do canonical `WebhookJob` — reusa infra existente em `config/sidekiq.yml`, evita divergência da convenção de prioridade do Chatwoot upstream). Isolamento real virá via fila :webhooks dedicada se métricas pós-lançamento mostrarem necessidade — registrado como v2.
  3. Cada evento carrega um header `X-Chatwoot-Delivery: <uuid>` que se mantém idêntico em todos os retries do mesmo evento (e diferente para o próximo evento do mesmo card), permitindo que o receptor faça dedup com segurança. *Nota: header reutiliza convenção existente em `lib/webhooks/trigger.rb:47` — SDK consistente com webhooks de canais.*
  4. Cliente que testa hoje (sem assinatura, sem retry) continua recebendo webhooks — mudança não quebra integrações existentes; UUID e novo header são aditivos.
**Plans:** TBD
**UI hint**: no

### Phase 2: HMAC Signature
**Slug:** `hmac-signature`
**Goal:** Cliente receptor pode validar com 5 linhas de código padrão (estilo Stripe/GitHub) que o payload recebido foi de fato originado pelo Chatwoot, e pode rotacionar o segredo quando suspeitar de comprometimento — sem suporte humano.
**Depends on:** Phase 1 (a assinatura cobre o payload + header `X-Chatwoot-Delivery` introduzidos na Phase 1; sem isso o dedup-id seria forjável)
**Requirements:** HARD-02
**Success Criteria** (what must be TRUE):
  1. Todo webhook de Kanban sai com header `X-Chatwoot-Signature: sha256=<hmac>` calculado sobre o body com o secret do board, e receptor consegue validar usando `OpenSSL::HMAC` (Ruby) ou `crypto.createHmac` (Node) em ~5 linhas.
  2. Cliente vê o secret **uma única vez** no momento da criação/rotação do board, com aviso "copie agora, não será mostrado de novo" — depois disso o backend só armazena hash/encrypted-blob.
  3. Cliente consegue clicar "rotacionar secret" na config do board e gerar um novo secret; webhooks subsequentes usam o novo secret; secret antigo deixa de funcionar imediatamente.
  4. Boards legados sem secret continuam enviando webhooks sem header de assinatura (modo backward-compatible) — receptor opt-in para validar.
**Plans:** TBD
**UI hint**: yes

### Phase 3: Delivery Observability
**Slug:** `delivery-observability`
**Goal:** Cliente debuga e opera a integração de webhook sem abrir ticket de suporte: vê o que saiu, com que status voltou, e consegue testar e re-disparar manualmente da própria UI.
**Depends on:** Phase 1 (log precisa registrar retry_count e UUID), Phase 2 (log mostra se assinatura foi enviada e qual secret-id foi usado, para auditoria de rotação)
**Requirements:** HARD-04, HARD-05, HARD-07
**Success Criteria** (what must be TRUE):
  1. Cliente abre Configurações da Coluna → aba "Log de Entregas" e vê os últimos N envios em tabela com colunas: timestamp, evento, status code, tempo de resposta (ms), retry count, e payload expandível inline.
  2. Cliente clica "Testar webhook" na config da coluna, recebe payload de exemplo (`event: kanban.test`, estrutura idêntica à real) no seu endpoint, e o resultado aparece inline na UI em ≤5s (sucesso ou erro com status code).
  3. Cliente abre uma entrega que falhou no log, clica "Reenviar", e um novo job é disparado mantendo o `X-Webhook-Id` original — receptor com dedup corretamente trata como retry, não como evento novo.
  4. Log persiste em tabela própria com retenção configurável (default: últimos 100 envios por coluna OU últimos 7 dias, o que for menor), sem inflar o storage para clientes high-volume.
**Plans:** TBD
**UI hint**: yes

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Reliability Foundation | 0/0 | Not started | - |
| 2. HMAC Signature | 0/0 | Not started | - |
| 3. Delivery Observability | 0/0 | Not started | - |

## Dependency Graph

```
Phase 1 (Reliability) ──┬─→ Phase 2 (HMAC)        ──┐
                        │                            ├─→ Phase 3 (Observability)
                        └────────────────────────────┘
```

**Parallelization note (config: parallelization=true):**
Phase 1 and Phase 2 are technically independent at the code level (retry/queue/UUID lives in job class + Sidekiq config; HMAC lives in payload-signing + model field). They can run in parallel if two implementer threads exist. Under solo developer + Claude default, recommend **serial** for cleaner integration testing: Phase 1 stabilizes the new job semantics first, then Phase 2 adds signing on top. Phase 3 **must** wait for both — it surfaces retry_count, UUID, and signature-status in the UI.

## Notes

- All phases reuse existing infrastructure where it exists:
  - Phase 1: `CustomExceptions::Webhook::RetriableError` (already in codebase, used by `app/jobs/webhook_job.rb`) — backport pattern to `Kanban::WebhookJob`.
  - Phase 2: HMAC signing pattern from `lib/webhooks/trigger.rb` line 51 (`OpenSSL::HMAC`) — extract or duplicate.
  - Phase 3: Delivery log is a NEW table (`kanban_webhook_deliveries`); the standard `WebhookJob` doesn't have a persisted log either, so no existing pattern to reuse — design fresh.
- Compatibility constraint per PROJECT.md: webhooks atuais (sem assinatura, sem UUID) precisam seguir funcionando para clientes legados durante transição. Phase 1 changes are additive (new header, new queue, retry on errors that previously dropped); Phase 2 is opt-in per board (no secret = no signature header); Phase 3 is purely additive UI.
- Enterprise overlay check (per CLAUDE.md): `Kanban::*` is fork-custom (not upstream Chatwoot OSS), so no Enterprise mirror expected. Verify in plan-phase before editing.

---
*Roadmap created: 2026-05-11*
