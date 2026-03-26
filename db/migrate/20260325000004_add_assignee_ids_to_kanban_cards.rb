class AddAssigneeIdsToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :assignee_ids, :integer, array: true, default: []

    reversible do |dir|
      dir.up do
        execute "UPDATE kanban_cards SET assignee_ids = ARRAY[assignee_id]::integer[] WHERE assignee_id IS NOT NULL"
      end
    end
  end
end
