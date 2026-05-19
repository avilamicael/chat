class AddAutoAssignmentFellThroughToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :auto_assignment_fell_through, :boolean, default: false, null: false
  end
end
