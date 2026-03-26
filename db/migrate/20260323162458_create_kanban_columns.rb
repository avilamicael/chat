class CreateKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_columns do |t|
      t.references :kanban_board, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :color, default: '#6B7280'
      t.jsonb :enter_actions, null: false, default: []
      t.jsonb :exit_actions, null: false, default: []

      t.timestamps
    end

    add_index :kanban_columns, [:kanban_board_id, :position]
  end
end
