class CascadeDeleteKanbanCardActionExecutions < ActiveRecord::Migration[7.1]
  def up
    remove_foreign_key :kanban_card_action_executions, column: :card_id
    remove_foreign_key :kanban_card_action_executions, column: :column_id
    add_foreign_key :kanban_card_action_executions, :kanban_cards, column: :card_id, on_delete: :cascade
    add_foreign_key :kanban_card_action_executions, :kanban_columns, column: :column_id, on_delete: :cascade
  end

  def down
    remove_foreign_key :kanban_card_action_executions, column: :card_id
    remove_foreign_key :kanban_card_action_executions, column: :column_id
    add_foreign_key :kanban_card_action_executions, :kanban_cards, column: :card_id
    add_foreign_key :kanban_card_action_executions, :kanban_columns, column: :column_id
  end
end
