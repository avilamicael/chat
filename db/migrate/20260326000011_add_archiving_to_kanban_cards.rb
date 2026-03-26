class AddArchivingToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :archived_at, :datetime
    add_column :kanban_cards, :outcome, :string
    add_index :kanban_cards, :archived_at
  end
end
