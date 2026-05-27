class AddCostUsdMicrosAndUnitsToCaptainUsageEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_usage_events, :cost_usd_micros, :bigint # nullable: old events have no USD
    add_column :captain_usage_events, :units, :integer # nullable: seconds for audio; nil for token-based
  end
end
