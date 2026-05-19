json.id kanban_column.id
json.name kanban_column.name
json.position kanban_column.position
json.color kanban_column.color
json.enter_actions kanban_column.enter_actions
json.exit_actions kanban_column.exit_actions
json.column_type kanban_column.column_type
json.conversation_status kanban_column.conversation_status
json.kanban_board_id kanban_column.kanban_board_id
json.account_id kanban_column.account_id
json.wip_limit kanban_column.wip_limit
json.aging_warn_days kanban_column.aging_warn_days
json.aging_danger_days kanban_column.aging_danger_days

# Phase 3 KAN-07: auto-assignment settings (colunas adicionadas pelo Plan A)
json.auto_assignment_enabled kanban_column.auto_assignment_enabled
json.auto_assignment_online_only kanban_column.auto_assignment_online_only
json.auto_assignment_override kanban_column.auto_assignment_override
json.auto_assignment_reassign_on_return kanban_column.auto_assignment_reassign_on_return
json.auto_assignment_max_cards_per_agent kanban_column.auto_assignment_max_cards_per_agent
json.last_assigned_agent_id kanban_column.last_assigned_agent_id

# Phase 3 KAN-09: metrics (count + tempo médio dos cards atualmente parados)
metrics = Kanban::ColumnMetricsService.new(kanban_column).metrics
json.card_count metrics[:count]
json.avg_dwell_seconds metrics[:avg_dwell_seconds]

# DEPRECATED: cards_count (array.length) mantido temporariamente para backward compat
# (KanbanBoardSettings.vue + Index.vue consomem). Remover quando frontend migrar para card_count.
json.cards_count metrics[:count]
