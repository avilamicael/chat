class CreateKanbanCards < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_cards do |t|
      t.references :kanban_column, null: false, foreign_key: true, index: true
      t.references :kanban_board, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.float :position, null: false, default: 0.0

      t.timestamps
    end

    add_index :kanban_cards, [:kanban_board_id, :conversation_id], unique: true
    add_index :kanban_cards, [:kanban_column_id, :position]
  end
end
