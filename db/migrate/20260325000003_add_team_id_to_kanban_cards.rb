class AddTeamIdToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :team_id, :bigint
    add_index :kanban_cards, :team_id
    add_foreign_key :kanban_cards, :teams, column: :team_id
  end
end
