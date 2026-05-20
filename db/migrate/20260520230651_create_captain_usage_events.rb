class CreateCaptainUsageEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_usage_events do |t|
      t.bigint :account_id, null: false
      t.bigint :assistant_id
      t.bigint :conversation_id
      t.string :feature, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.integer :cost_cents, null: false, default: 0

      t.timestamps
    end

    add_index :captain_usage_events, [:account_id, :created_at]
  end
end
