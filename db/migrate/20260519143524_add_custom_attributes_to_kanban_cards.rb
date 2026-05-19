class AddCustomAttributesToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :custom_attributes, :jsonb, default: {}, null: false
    add_index :kanban_cards, :custom_attributes, using: :gin, name: 'index_kanban_cards_on_custom_attributes'
  end
end
