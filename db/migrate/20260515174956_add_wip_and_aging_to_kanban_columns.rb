class AddWipAndAgingToKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_columns, :wip_limit, :integer         # NULL = sem limite (D-05)
    add_column :kanban_columns, :aging_warn_days, :integer   # NULL = sem aging (D-13)
    add_column :kanban_columns, :aging_danger_days, :integer # NULL = sem aging (D-13)
  end
end
