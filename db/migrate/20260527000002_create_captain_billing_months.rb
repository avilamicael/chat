class CreateCaptainBillingMonths < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_billing_months do |t|
      t.bigint  :account_id                          # NULL = global default row for the period (D-03)
      t.string  :period, null: false                 # 'YYYY-MM' frozen month (D-05)
      t.decimal :taxa_paga,  precision: 10, scale: 4  # effective rate paid (or derived from total BRL/USD)
      t.decimal :taxa_atual, precision: 10, scale: 4  # current rate typed by super admin (D-02)
      t.bigint  :total_brl_pago_micros               # optional: D-01a total BRL paid on OpenAI invoice
      t.bigint  :mensalidade_micros                  # fixed monthly fee in BRL micros
      t.integer :unidades_inclusas                   # X (included units before overage)
      t.bigint  :preco_excedente_micros              # overage price per unit in BRL micros
      t.timestamps
    end

    # One row per (account_id, period). Postgres treats each NULL account_id as distinct,
    # so this composite does NOT prevent duplicate global rows for a period.
    add_index :captain_billing_months, [:account_id, :period],
              unique: true, name: 'idx_captain_billing_months_account_period'

    # Partial unique index forces at most ONE global row (account_id NULL) per period,
    # closing the concurrent-duplicate gap left by the composite index above (T-07B-05).
    add_index :captain_billing_months, [:period],
              unique: true, where: 'account_id IS NULL', name: 'idx_captain_billing_months_global_period'
  end
end
