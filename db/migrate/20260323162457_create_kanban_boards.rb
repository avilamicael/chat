class CreateKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_boards do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.boolean :is_default, null: false, default: false
      t.jsonb :filters, null: false, default: {}

      t.timestamps
    end

    add_index :kanban_boards, [:account_id, :is_default]
  end
end
