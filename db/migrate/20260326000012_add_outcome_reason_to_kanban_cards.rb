class AddOutcomeReasonToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :outcome_reason, :text
  end
end
