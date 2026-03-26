class AddTaskFieldsToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    # Tornar conversation_id opcional
    change_column_null :kanban_cards, :conversation_id, true

    # Remover unique index que assume 1 conversa por board
    remove_index :kanban_cards, name: 'index_kanban_cards_on_kanban_board_id_and_conversation_id'

    # Campos de tarefa
    add_column :kanban_cards, :title, :string
    add_column :kanban_cards, :description, :text
    add_column :kanban_cards, :due_date, :datetime
    add_column :kanban_cards, :reminder_at, :datetime
    add_column :kanban_cards, :priority, :integer
    add_column :kanban_cards, :task_status, :string, default: 'open'
    add_column :kanban_cards, :created_by_id, :bigint

    add_foreign_key :kanban_cards, :users, column: :created_by_id
    add_index :kanban_cards, :created_by_id
  end
end
