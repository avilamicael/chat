# Kanban — Funis, Visão Geral e Melhorias de UX

Documento de acompanhamento do desenvolvimento do módulo Kanban.

---

## Fase 1 — Sidebar + Visão Geral + Templates

| # | Item | Status |
|---|------|--------|
| 1 | Sidebar: sub-items dinâmicos "Visão Geral" + "Funis" | ✅ Concluído |
| 2 | Overview (Index.vue): layout 2 colunas + botão "Adicionar Funil" | ✅ Concluído |
| 3 | Modal de criação de funil com seleção de template | ✅ Concluído |
| 4 | Backend: `BoardTemplateService` (colunas pré-definidas por template) | ✅ Concluído |
| 5 | i18n: chaves para overview, templates, sidebar | ✅ Concluído |

### Templates disponíveis
- **Funil Vazio** — board sem colunas
- **Sales Funnel** — New Lead → Qualifying → Proposal Sent → Negotiation → Lost → Won
- **Support Funnel** — New → In Progress → Waiting for Customer → Resolved
- **Outros** — Em breve (desabilitado)

---

## Fase 1.5 — Redesign Visual (baseado em screenshots)

| # | Item | Status |
|---|------|--------|
| 1 | `CreateFunnelModal.vue`: fluxo invertido (template primeiro, depois nome) | ✅ Concluído |
| 2 | `CreateFunnelModal.vue`: ícone para "Empty Funnel" (`i-lucide-layout-kanban`) | ✅ Concluído |
| 3 | `CreateFunnelModal.vue`: renomear "Sales Pipeline" → "Sales Funnel" | ✅ Concluído |
| 4 | `board_template_service.rb`: adicionar key `sales_funnel` (6 colunas) + alias `sales_pipeline` | ✅ Concluído |
| 5 | `_kanban_card.json.jbuilder`: expor `channel` (channel_type da inbox) | ✅ Concluído |
| 6 | `_kanban_board.json.jbuilder`: expor `cards_total` | ✅ Concluído |
| 7 | `kanban_boards_controller.rb`: `includes(:kanban_columns, :kanban_cards)` para evitar N+1 | ✅ Concluído |
| 8 | `KanbanCard.vue`: redesign — canal badge colorido + avatar + tempo aberto | ✅ Concluído |
| 9 | `KanbanColumn.vue`: header com background colorido (`column.color`) + ícones brancos | ✅ Concluído |
| 10 | `KanbanBoard.vue`: header com filtros (status, agente, inbox) + badge de total | ✅ Concluído |
| 11 | `Index.vue`: full-width, remover painel esquerdo interno, funnel cards com stage pills | ✅ Concluído |
| 12 | `kanban.json`: novas chaves (SALES_FUNNEL, ALL_AGENTS, ALL_INBOXES, ADD_TASK, NO_NAME) | ✅ Concluído |

### Componentes visuais do redesign
- **Funnel cards (Overview)**: nome + badge `cards_total` + settings icon + stage pills coloridas (`● Nome Count`)
- **Board header**: ← voltar + nome + count + toggle open/pending + dropdown agente + dropdown inbox + settings + add task
- **Column header**: background = `column.color`, texto e ícones brancos
- **Card**: contact name + channel badge (dot colorido + label) + assignee avatar + separator + tempo aberto

---

## Fase 2 — Cards Standalone + Card Detail

| # | Item | Status |
|---|------|--------|
| 6 | Cards sem conversa vinculada (tarefas standalone) | ✅ Concluído |
| 7 | Modal de detalhes do card (criador, assignee, conversa, status) | ✅ Concluído |
| 8 | `CreateTaskModal.vue` — criação de tarefas com ComboBox (coluna/prioridade/agente) | ✅ Concluído |
| 9 | `TaskDetailModal.vue` — edição inline de todos os campos | ✅ Concluído |
| 10 | `KanbanCard.vue` — suporte a tasks standalone + prioridade + due date | ✅ Concluído |
| 11 | Filtros de agente e inbox via `ComboBox` no board | ✅ Concluído |
| 12 | Botão "+" da coluna abre `CreateTaskModal` pré-selecionado | ✅ Concluído |
| 13 | `KanbanBoardSettings.vue` — agents/inboxes via ComboBox | ✅ Concluído |
| 14 | `AddCardModal.vue` — coluna via ComboBox | ✅ Concluído |
| 15 | Join table `kanban_card_conversations` (many-to-many) | ✅ Concluído |

### Modelo de Card (Fase 2)
- `title` — para cards sem conversa
- `description`, `priority` (enum: low/medium/high/urgent), `task_status`, `due_date`, `reminder_at`
- `created_by_id` — agente que criou
- `conversation_id` — opcional (nulo = standalone)
- Join table `kanban_card_conversations` — vínculo many-to-many com conversas
- Validação: ou `conversation_id` ou `title` obrigatório

### Arquivos criados/modificados na Fase 2
- `db/migrate/20260324000001_add_task_fields_to_kanban_cards.rb`
- `db/migrate/20260324000002_create_kanban_card_conversations.rb`
- `app/models/kanban_card_conversation.rb` — **NOVO**
- `app/models/kanban_card.rb` — enum priority, optional conversation, linked_conversations
- `app/services/kanban/card_creation_service.rb` — conversation opcional
- `app/controllers/api/v1/accounts/kanban_boards/cards_controller.rb` — action `update`
- `app/policies/kanban_card_policy.rb` — `update?`
- `config/routes.rb` — `:update` em cards
- `app/views/api/v1/accounts/kanban_boards/cards/_kanban_card.json.jbuilder` — novos campos
- `app/views/api/v1/accounts/kanban_boards/cards/show.json.jbuilder` — **NOVO**
- `app/javascript/dashboard/api/kanban.js` — `updateCard`
- `app/javascript/dashboard/store/modules/kanban/index.js` — UPDATE_CARD, addCard, updateCard
- `app/javascript/dashboard/i18n/locale/en/kanban.json` — seção TASK (30 chaves)
- `app/javascript/dashboard/routes/dashboard/kanban/components/CreateTaskModal.vue` — **NOVO**
- `app/javascript/dashboard/routes/dashboard/kanban/components/TaskDetailModal.vue` — **NOVO**
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue` — redesign
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue` — emit add-card
- `app/javascript/dashboard/routes/dashboard/kanban/KanbanBoard.vue` — ComboBox + modais
- `app/javascript/dashboard/routes/dashboard/kanban/KanbanBoardSettings.vue` — ComboBox
- `app/javascript/dashboard/routes/dashboard/kanban/components/AddCardModal.vue` — ComboBox

---

## Fase 3 — Ações de Coluna + Filtros Avançados

| # | Item | Status |
|---|------|--------|
| 8 | UI para configurar webhooks de entrada/saída de coluna | 📋 Planejado |
| 9 | Visibilidade do board: filtrar por agente, time, caixa de entrada | 📋 Planejado |

### Ações de Coluna (backend já implementado)
- `send_webhook_event` — chama endpoint externo quando card entra/sai
- `send_message` — envia mensagem para a conversa vinculada

### Visibilidade (campo `visibility_settings` JSONB no board)
```json
{
  "restricted_to_team_ids": [],
  "restricted_to_inbox_ids": [],
  "restricted_to_agent_ids": [],
  "show_only_assigned": false
}
```

---

## Arquivos Modificados / Criados

### Fase 1
- `app/javascript/dashboard/components-next/sidebar/Sidebar.vue` — sub-items kanban dinâmicos
- `app/javascript/dashboard/routes/dashboard/kanban/Index.vue` — overview full-width com funnel cards
- `app/javascript/dashboard/i18n/locale/en/kanban.json` — novas chaves
- `app/controllers/api/v1/accounts/kanban_boards_controller.rb` — aceitar `template`, includes N+1 fix
- `app/services/kanban/board_template_service.rb` — **NOVO**
- `app/javascript/dashboard/routes/dashboard/kanban/components/CreateFunnelModal.vue` — **NOVO**
- `app/javascript/dashboard/routes/dashboard/kanban/KanbanBoard.vue` — header com filtros
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue` — header colorido
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue` — redesign visual
- `app/views/api/v1/accounts/kanban_boards/_kanban_board.json.jbuilder` — cards_total
- `app/views/api/v1/accounts/kanban_boards/cards/_kanban_card.json.jbuilder` — channel type
- `app/javascript/dashboard/store/modules/kanban/index.js` — passar template no createBoard

---

## Notas / Decisões de Arquitetura

- **Boards = Funis** na UI. O modelo no banco continua como `kanban_boards` (sem renomear).
- Cards atualmente exigem `conversation_id`. Fase 2 torna opcional para suportar tarefas avulsas.
- Column actions (webhooks) já funcionam no backend via `enter_actions`/`exit_actions` JSONB. UI de configuração é Fase 3.
- Limites de funis por plano: gerenciado pelo billing/feature flags (futuro).
