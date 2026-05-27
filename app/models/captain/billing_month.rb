class Captain::BillingMonth < ApplicationRecord
  self.table_name = 'captain_billing_months'

  belongs_to :account, class_name: '::Account', optional: true # NULL = global default row

  validates :period, presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :period, uniqueness: { scope: :account_id }

  scope :global_defaults, -> { where(account_id: nil) }
  scope :for_period, ->(period) { where(period: period) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  # Billing config for an account in a period, falling back to the global default (account_id NULL).
  def self.for_account_and_period(account_id, period)
    find_by(account_id: account_id, period: period) ||
      find_by(account_id: nil, period: period)
  end

  # Effective rate paid: explicit taxa_paga, else derived from total BRL paid / total USD used (D-01a),
  # else nil so the consumer falls back to USD_BRL_RATE/5,4 (D-06). Guards division by zero (T-07B-04).
  def effective_taxa_paga(total_usd_micros:)
    return taxa_paga if taxa_paga.present?
    return nil unless total_brl_pago_micros.present? && total_usd_micros.to_i.positive?

    total_brl_pago_micros.to_f / total_usd_micros
  end
end
