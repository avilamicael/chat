class AddAutoAssignmentSettingsToKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_columns, :auto_assignment_enabled, :boolean, default: false, null: false
    add_column :kanban_columns, :auto_assignment_online_only, :boolean, default: false, null: false
    add_column :kanban_columns, :auto_assignment_override, :boolean, default: false, null: false
    add_column :kanban_columns, :auto_assignment_reassign_on_return, :boolean, default: false, null: false
    add_column :kanban_columns, :auto_assignment_max_cards_per_agent, :integer # NULL = sem limite (D-A1)
    add_column :kanban_columns, :last_assigned_agent_id, :integer # observability (D-A6 Pivô 2: fonte da verdade é Redis)
  end
end
