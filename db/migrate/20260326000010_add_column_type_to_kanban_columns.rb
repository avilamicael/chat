class AddColumnTypeToKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_columns, :column_type, :string, default: 'normal', null: false
    add_index :kanban_columns, :column_type
  end
end
