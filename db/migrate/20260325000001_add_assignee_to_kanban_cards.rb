class AddAssigneeToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :assignee_id, :bigint
    add_foreign_key :kanban_cards, :users, column: :assignee_id
    add_index :kanban_cards, :assignee_id
  end
end
