class AddExecutionStatusToKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_columns, :last_execution_status, :string  # nullable; NULL = nunca executado
    add_column :kanban_columns, :last_execution_error, :text
    add_column :kanban_columns, :last_executed_at, :datetime
  end
end
