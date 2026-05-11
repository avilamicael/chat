# Phase 1 Context: Reliability Foundation

**Phase:** 01 — Reliability Foundation
**Date:** 2026-05-11
**Status:** Context gathered, ready to plan

<domain>
Tornar o `Kanban::WebhookJob` confiável e idempotente sem inventar infra nova. Hoje o job é fire-and-forget (`queue_as :default`, rescue silencioso, sem retry, sem delivery ID, sem assinatura). O sistema Chatwoot **já tem** toda a infra necessária em `lib/webhooks/trigger.rb` (HMAC + delivery ID em headers) e `app/jobs/webhook_job.rb` (retry pattern com `CustomExceptions::Webhook::RetriableError`). Phase 1 reusa essa infra.

**Phase entrega:** Webhooks de Kanban recebidos com 100% de confiabilidade quando o receptor está temporariamente fora, com header `X-Chatwoot-Delivery: <uuid>` estável em retries para dedup, rodando em fila Sidekiq com prioridade superior a jobs de aplicação comum.
</domain>

<canonical_refs>
**LOCKED — downstream agents MUST read these before planning/executing.**

- `app/jobs/kanban/webhook_job.rb` — Job atual (fire-and-forget; será reescrito como wrapper magro)
- `app/jobs/webhook_job.rb` — Pattern canonical de retry: `retry_on CustomExceptions::Webhook::RetriableError, wait: :polynomially_longer, attempts: 5` + `discard_on` + delega para `Webhooks::Trigger.execute`. Copiar a forma.
- `lib/webhooks/trigger.rb` — Infra de execução; faz HMAC (linha 50), envia `X-Chatwoot-Delivery` (linha 47), levanta `RetriableError` (linha 26) em StandardError não-fatal. **Não modificar nesta phase** — só consumir.
- `lib/custom_exceptions/webhook.rb` — Define `CustomExceptions::Webhook::RetriableError`. Já pronto.
- `app/services/kanban/column_actions_service.rb:30` — Caller; enqueue do `Kanban::WebhookJob.perform_later`. Vai mudar para passar `delivery_id:` (e futuramente `secret:` em Phase 2).
- `config/sidekiq.yml` — Configuração de filas. **Não modificar** nesta phase (mantém priority queues atuais; só mudamos `queue_as` no job).
- `.planning/PROJECT.md` — Core Value, Key Decisions
- `.planning/ROADMAP.md` — Phase 1 success criteria (atualizado nesta sessão: HARD-06 header renomeado, HARD-03 fila revisada)
- `.planning/REQUIREMENTS.md` — HARD-01, HARD-03, HARD-06 (atualizado nesta sessão)
- `.planning/codebase/TESTING.md` — Padrões de teste de jobs com ActiveJob::TestHelper, `assert_performed_jobs`, RetriableError assertions
- `CLAUDE.md` (= `AGENTS.md`) — Regras de estilo, Enterprise overlay check, "avoid specs unless asked" (overrideado nesta phase por decisão explícita)
</canonical_refs>

<decisions>

### Decisão 1: Job shape — Wrapper magro

`Kanban::WebhookJob` permanece como classe própria, mas delega para `Webhooks::Trigger.execute` com `webhook_type=:kanban_webhook`.

**Forma final esperada (referência para o planner):**
```ruby
module Kanban
  class WebhookJob < ApplicationJob
    queue_as :medium

    retry_on CustomExceptions::Webhook::RetriableError, wait: :polynomially_longer, attempts: 5
    discard_on CustomExceptions::Webhook::RetriableError do |job, error|
      payload = job.arguments[1]
      delivery_id = job.kwargs[:delivery_id] if job.respond_to?(:kwargs)
      Rails.logger.warn(
        "[Kanban::WebhookJob] retries exhausted url=#{job.arguments[0]} " \
        "event=#{payload && payload[:event]} delivery_id=#{delivery_id} error=#{error.message}"
      )
    end

    def perform(url, payload, secret: nil, delivery_id: nil)
      return if url.blank?

      Webhooks::Trigger.execute(url, payload, :kanban_webhook, secret: secret, delivery_id: delivery_id)
    end
  end
end
```

**Por que wrapper, não delete-and-reuse:**
- `Webhooks::ErrorHandler.perform` (chamado pelo `WebhookJob` canonical em discard_on) reage a `payload[:event] in %w[message_created message_updated]`. Eventos Kanban (`kanban.card_*`) não batem → seria efetivamente no-op, mas semanticamente errado.
- Phase 2 (HMAC) e Phase 3 (log persistente) podem precisar de hooks Kanban-específicos sem mexer no sistema canonical. Wrapper isola.

**Por que NÃO copy-paste standalone (opção C):**
- Duplicaria a lógica de `lib/webhooks/trigger.rb` (HMAC, headers, RestClient::Request, timeout). Risco de drift entre as duas implementações ao longo do tempo.

### Decisão 2: Fila Sidekiq — `:medium`

`queue_as :medium` (não `:default`, não `:webhooks` nova). 

**Por quê:**
- Matches o `WebhookJob` canonical (`app/jobs/webhook_job.rb:2`). Consistência > especialização aqui.
- Sidekiq drena `:medium` antes de `:default` (`config/sidekiq.yml:21-28`), então webhook tem prioridade efetiva sobre jobs de app comum mesmo sem fila dedicada.
- **Não tocar em `config/sidekiq.yml`** — adicionar `:webhooks` requereria entender por que o upstream Chatwoot escolheu priority-based em vez de per-domain, e gera conflito potencial em rebases futuros.
- Roadmap atualizado: success criteria #2 da Phase 1 agora menciona `:medium`. HARD-03 atualizado em REQUIREMENTS.md. Fila `:webhooks` dedicada vai para backlog v2 se métricas exigirem.

### Decisão 3: Retry config — `attempts: 5, wait: :polynomially_longer`

Match exato do `WebhookJob` canonical. Polynomial backoff (defaults do ActiveJob): aproximadamente 3s, 16s, 81s, 256s, 625s. Janela total de recuperação: ~16 minutos.

**Não usar:**
- Sidekiq default (25 tries, ~30min) — substituído pelo `retry_on` do ActiveJob; não vale aumentar.
- `attempts: 3` — janela muito curta para falhas transient comuns (DNS, deploy de cliente).

### Decisão 4: Discard handler — só log warn

Quando os 5 retries esgotam:
```ruby
Rails.logger.warn(
  "[Kanban::WebhookJob] retries exhausted url=#{url} event=#{event} delivery_id=#{id} error=#{e.message}"
)
```

Phase 3 vai capturar isso na tabela `kanban_webhook_deliveries` e exibir na UI. Por enquanto: log estruturado, fácil de grep em produção.

**Não chamar:**
- `Webhooks::ErrorHandler.perform` — não aplica a eventos Kanban (filtra por `message_created/message_updated`).
- Criar `Conversation::ActivityMessage` — polui timeline, mistura conceitos (webhook ≠ conversation event).

### Decisão 5: Delivery ID — `X-Chatwoot-Delivery` + in-flight

**Header:** `X-Chatwoot-Delivery: <uuid>` (reusa `lib/webhooks/trigger.rb:47`, NÃO `X-Webhook-Id` como o roadmap original dizia). Receptor único do cliente trata canal-webhook e Kanban-webhook com mesmo header → SDK consistente.

**Geração:** `SecureRandom.uuid` em `Kanban::ColumnActionsService#execute_action` quando o action_name é `send_webhook`. Passa como kwarg `delivery_id:` ao `Kanban::WebhookJob.perform_later`.

**Estabilidade em retries:** Sidekiq serializa os args do job no enqueue (Redis). Em retry, os mesmos args são desserializados — o UUID se mantém idêntico. Verificado conceitualmente; planner deve adicionar spec cobrindo isso.

**Persistência:** apenas in-flight nesta phase. Tabela `kanban_webhook_deliveries` (com colunas delivery_id, status, response_code, response_time_ms, retry_count, etc.) é responsabilidade da Phase 3.

**Atualização do roadmap nesta sessão:**
- `REQUIREMENTS.md` HARD-06: header renomeado para `X-Chatwoot-Delivery`
- `ROADMAP.md` Phase 1 success criterion #3: idem
- `ROADMAP.md` Phase 2 "Depends on": referência ao header atualizada

### Decisão 6: Caller (ColumnActionsService) — passar delivery_id

`app/services/kanban/column_actions_service.rb:30` muda de:
```ruby
when 'send_webhook'
  Kanban::WebhookJob.perform_later(action['url'], webhook_payload) if action['url'].present?
```
para:
```ruby
when 'send_webhook'
  if action['url'].present?
    Kanban::WebhookJob.perform_later(
      action['url'],
      webhook_payload,
      delivery_id: SecureRandom.uuid
    )
  end
```

Phase 2 (HMAC) adiciona `secret:` aqui também. Não fazer agora.

### Decisão 7: Specs — Sim, criar `spec/jobs/kanban/webhook_job_spec.rb`

Override explícito da regra "avoid specs unless asked" do CLAUDE.md, por:
- Backend crítico (regressão silenciosa em webhook quebra integrações de cliente vendido como "profissional")
- Cobertura atual: zero (`spec/jobs/kanban/` não existe)
- Custo baixo: ~80 linhas

**Cobertura mínima do spec:**
1. `queue_as :medium` (assert via `Kanban::WebhookJob.queue_name`)
2. `retry_on` configurado para `CustomExceptions::Webhook::RetriableError` com `attempts: 5`
3. Chama `Webhooks::Trigger.execute` com args corretos (url, payload, :kanban_webhook, kwargs) — via mock
4. Quando `Webhooks::Trigger` levanta `RetriableError`, job re-enqueua (assert_performed_jobs)
5. Quando retries esgotam, log warn é chamado com delivery_id presente
6. `delivery_id` é propagado intacto nos args do job em re-enqueue

**Padrão a seguir:** `spec/jobs/webhook_job_spec.rb` (canonical) — replicar estrutura.

**Não cobrir aqui:**
- HMAC signature (Phase 2)
- Persistência em DB (Phase 3)

</decisions>

<deferred>
- **Fila Sidekiq `:webhooks` dedicada** — adiar para backlog v2; reavaliar se métricas pós-lançamento mostrarem que `:medium` está saturado por webhooks de canais e Kanban competindo.
- **Idempotency cliente-side helper** — gem/snippet pronto de receptor para dedup baseado em `X-Chatwoot-Delivery`. Não é código nosso, mas potencial doc/SDK em landing comercial. Não bloqueante.
- **Métricas/Prometheus** — contadores de `webhook.kanban.success`, `.retry`, `.exhausted` por board. Útil para SLA observável, mas é Phase 4 conceitual ou v1.1.
</deferred>

<canonical_refs_summary>
Downstream agents (researcher, planner, executor) — leia nessa ordem:
1. `.planning/REQUIREMENTS.md` (HARD-01, HARD-03, HARD-06 atualizados)
2. `.planning/ROADMAP.md` (Phase 1 details, success criteria atualizados)
3. `app/jobs/webhook_job.rb` (pattern a copiar)
4. `lib/webhooks/trigger.rb` (consumido, não modificado)
5. `app/services/kanban/column_actions_service.rb` (caller a atualizar)
6. `app/jobs/kanban/webhook_job.rb` (job a reescrever como wrapper)
7. Este CONTEXT.md (decisões locked)
</canonical_refs_summary>

<implementation_summary>
**Arquivos esperados para modificar:**
- `app/jobs/kanban/webhook_job.rb` — reescrita: queue_as :medium + retry_on + discard_on + delegate to Webhooks::Trigger
- `app/services/kanban/column_actions_service.rb` — passar `delivery_id: SecureRandom.uuid` no perform_later
- `spec/jobs/kanban/webhook_job_spec.rb` — novo arquivo (~80 linhas)

**Arquivos NÃO modificar:**
- `lib/webhooks/trigger.rb` (consumir)
- `app/jobs/webhook_job.rb` (referência)
- `config/sidekiq.yml` (fila :medium já existe)
- `enterprise/` (não há mirror — `app/jobs/kanban/` é fork-custom)

**Vault Obsidian:** após o execute-phase commit, atualizar `chatwoot/kanban.md` e `chatwoot/planning.md` (rule no CLAUDE.md do projeto).

**Estimativa de plans:** 1-2 plans coarse (1 plan para job+caller+spec, ou 2 plans: backend-implementation + spec). Planner decide.
</implementation_summary>

---
*Phase 1 context captured: 2026-05-11*
