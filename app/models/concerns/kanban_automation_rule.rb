module KanbanAutomationRule
  def conditions_attributes
    super + %w[target_column_id source_column_id kanban_board_id task_status]
  end
  # Phase 2: actions_attributes não muda — dual context cobre via card: kwarg em ActionService (Plan A).
end
