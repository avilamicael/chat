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
  DEFAULT_AUDIO_PRICE_USD_PER_MIN = 0.006 # Whisper $0.006/min — confirmed 2026

  # Returns cost in micros of BRL (1 R$ = 1_000_000 micros) using integer precision,
  # avoiding the rounding-to-zero that happens when sub-cent responses are stored as cents.
  def self.cost_micros(model:, input_tokens:, output_tokens:)
    price = prices[model] || prices[DEFAULT_MODEL_KEY]
    usd = ((input_tokens.to_i / 1_000_000.0) * price[:input]) + ((output_tokens.to_i / 1_000_000.0) * price[:output])
    (usd * usd_brl_rate * 1_000_000).round
  end

  # Returns cost in micros of USD (1 USD = 1_000_000 micros), independent of the exchange rate.
  # USD is the authoritative, exchange-immutable value persisted per event; BRL is derived at display time.
  def self.cost_usd_micros(model:, input_tokens:, output_tokens:)
    price = prices[model] || prices[DEFAULT_MODEL_KEY]
    usd = ((input_tokens.to_i / 1_000_000.0) * price[:input]) + ((output_tokens.to_i / 1_000_000.0) * price[:output])
    (usd * 1_000_000).round
  end

  # Returns cost in micros of USD for audio transcription, billed per minute (Whisper).
  def self.audio_cost_usd_micros(seconds:)
    ((seconds.to_f / 60.0) * audio_price_usd_per_min * 1_000_000).round
  end

  # Derives BRL micros from USD micros at call time using the given rate (or the configured fallback).
  def self.brl_micros_from_usd(cost_usd_micros:, rate: nil)
    (cost_usd_micros * (rate || usd_brl_rate)).round
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

  def self.audio_price_usd_per_min
    InstallationConfig.find_by(name: 'CAPTAIN_AUDIO_PRICE_USD_PER_MIN')&.value.to_f.nonzero? || DEFAULT_AUDIO_PRICE_USD_PER_MIN
  end
end
