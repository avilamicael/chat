class Captain::UsageCostCalculator
  # USD price per 1M tokens (approx, PLANO.md §4.3; gpt-4.1* are reasonable estimates pending final review).
  MODEL_PRICES_USD_PER_MILLION = {
    'gpt-4o-mini' => { input: 0.15, output: 0.60 },
    'gpt-4o' => { input: 2.50, output: 10.0 },
    'gpt-4.1-mini' => { input: 0.40, output: 1.60 },
    'gpt-4.1' => { input: 2.0, output: 8.0 }
  }.freeze

  DEFAULT_MODEL_KEY = 'gpt-4o-mini'.freeze
  DEFAULT_USD_BRL_RATE = 5.4

  def self.cost_cents(model:, input_tokens:, output_tokens:)
    price = prices[model] || prices[DEFAULT_MODEL_KEY]
    usd = ((input_tokens.to_i / 1_000_000.0) * price[:input]) + ((output_tokens.to_i / 1_000_000.0) * price[:output])
    (usd * usd_brl_rate * 100).round
  end

  def self.prices
    override = parse_price_override(InstallationConfig.find_by(name: 'CAPTAIN_MODEL_PRICES')&.value)
    override.presence || MODEL_PRICES_USD_PER_MILLION
  end

  def self.parse_price_override(raw)
    return nil if raw.blank?

    JSON.parse(raw).transform_values(&:symbolize_keys)
  rescue JSON::ParserError
    nil
  end

  def self.usd_brl_rate
    InstallationConfig.find_by(name: 'USD_BRL_RATE')&.value.to_f.nonzero? || DEFAULT_USD_BRL_RATE
  end
end
