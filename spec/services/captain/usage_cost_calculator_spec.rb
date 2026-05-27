require 'rails_helper'

RSpec.describe Captain::UsageCostCalculator do
  describe '.cost_usd_micros' do
    it 'prices token usage in USD micros (1 USD = 1_000_000 micros)' do
      # gpt-4o-mini input price is 0.15 USD / 1M tokens => 1M input tokens == 0.15 USD == 150_000 micros
      cost = described_class.cost_usd_micros(model: 'gpt-4o-mini', input_tokens: 1_000_000, output_tokens: 0)

      expect(cost).to eq(150_000)
    end

    it 'is independent of the USD_BRL_RATE (USD is immutable to exchange rate)' do
      InstallationConfig.where(name: 'USD_BRL_RATE').first_or_create!(value: '5.4')
      baseline = described_class.cost_usd_micros(model: 'gpt-4o-mini', input_tokens: 1_000_000, output_tokens: 0)

      InstallationConfig.where(name: 'USD_BRL_RATE').first_or_create!(value: '10.0').update!(value: '10.0')
      after_rate_change = described_class.cost_usd_micros(model: 'gpt-4o-mini', input_tokens: 1_000_000, output_tokens: 0)

      expect(after_rate_change).to eq(baseline)
    end
  end

  describe '.audio_cost_usd_micros' do
    it 'prices audio per minute using the default Whisper price' do
      # default 0.006 USD/min => 60s == 0.006 USD == 6_000 micros
      expect(described_class.audio_cost_usd_micros(seconds: 60)).to eq(6_000)
    end

    it 'respects CAPTAIN_AUDIO_PRICE_USD_PER_MIN from InstallationConfig' do
      InstallationConfig.where(name: 'CAPTAIN_AUDIO_PRICE_USD_PER_MIN').first_or_create!(value: '0.01').update!(value: '0.01')

      # 0.01 USD/min => 60s == 0.01 USD == 10_000 micros
      expect(described_class.audio_cost_usd_micros(seconds: 60)).to eq(10_000)
    end
  end

  describe '.brl_micros_from_usd' do
    it 'derives BRL micros from USD micros using the given rate' do
      expect(described_class.brl_micros_from_usd(cost_usd_micros: 150_000, rate: 5.0)).to eq(750_000)
    end

    it 'falls back to usd_brl_rate when no rate is given' do
      InstallationConfig.where(name: 'USD_BRL_RATE').first_or_create!(value: '5.4').update!(value: '5.4')

      expect(described_class.brl_micros_from_usd(cost_usd_micros: 150_000)).to eq((150_000 * 5.4).round)
    end
  end
end
