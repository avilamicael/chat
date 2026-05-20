class RenameCaptainUsageCostCentsToCostMicros < ActiveRecord::Migration[7.1]
  def up
    rename_column :captain_usage_events, :cost_cents, :cost_micros
    change_column :captain_usage_events, :cost_micros, :bigint, null: false, default: 0
  end

  def down
    change_column :captain_usage_events, :cost_micros, :integer, null: false, default: 0
    rename_column :captain_usage_events, :cost_micros, :cost_cents
  end
end
