class AddTeamIdsToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :team_ids, :integer, array: true, default: []

    reversible do |dir|
      dir.up do
        execute "UPDATE kanban_cards SET team_ids = ARRAY[team_id]::integer[] WHERE team_id IS NOT NULL"
      end
    end
  end
end
