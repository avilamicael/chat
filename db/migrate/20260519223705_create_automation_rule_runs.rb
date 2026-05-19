class CreateAutomationRuleRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :automation_rule_runs do |t|
      t.references :automation_rule, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: true
      t.string :event_name, null: false
      t.string :trigger_event_id, limit: 36
      t.datetime :triggered_at, null: false
      t.datetime :finished_at
      t.integer :status, null: false, default: 5 # 5 = started (enum)
      t.integer :total_actions, default: 0
      t.integer :succeeded_actions, default: 0
      t.jsonb :actions_log, default: [], null: false
      t.text :error_summary
      t.timestamps
    end

    add_index :automation_rule_runs, [:automation_rule_id, :created_at],
              order: { created_at: :desc }, name: 'idx_runs_by_rule_desc'
    add_index :automation_rule_runs, [:account_id, :created_at],
              order: { created_at: :desc }, name: 'idx_runs_by_account_failures',
              where: 'status <> 0'
  end
end
