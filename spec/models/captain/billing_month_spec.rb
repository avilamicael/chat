require 'rails_helper'

RSpec.describe Captain::BillingMonth do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'requires period to be present' do
      record = described_class.new(period: nil)
      expect(record).not_to be_valid
      expect(record.errors[:period]).to be_present
    end

    it 'accepts a period in YYYY-MM format' do
      expect(described_class.new(period: '2026-05')).to be_valid
    end

    it 'rejects a malformed period (single-digit month)' do
      record = described_class.new(period: '2026-1')
      expect(record).not_to be_valid
      expect(record.errors[:period]).to be_present
    end

    it 'rejects a non-date period string' do
      record = described_class.new(period: 'abc')
      expect(record).not_to be_valid
      expect(record.errors[:period]).to be_present
    end

    it 'enforces period uniqueness scoped by account_id (per account)' do
      described_class.create!(account_id: account.id, period: '2026-05')
      dup = described_class.new(account_id: account.id, period: '2026-05')
      expect(dup).not_to be_valid
      expect(dup.errors[:period]).to be_present
    end

    it 'enforces period uniqueness for the global (account_id NULL) row' do
      described_class.create!(account_id: nil, period: '2026-05')
      dup = described_class.new(account_id: nil, period: '2026-05')
      expect(dup).not_to be_valid
      expect(dup.errors[:period]).to be_present
    end

    it 'rejects a non-numeric unidades_inclusas (WR-05)' do
      record = described_class.new(period: '2026-05', unidades_inclusas: 'abc')
      expect(record).not_to be_valid
      expect(record.errors[:unidades_inclusas]).to be_present
    end

    it 'rejects a fractional unidades_inclusas (WR-05)' do
      record = described_class.new(period: '2026-05', unidades_inclusas: 1000.9)
      expect(record).not_to be_valid
      expect(record.errors[:unidades_inclusas]).to be_present
    end

    it 'rejects a negative money input (WR-05)' do
      record = described_class.new(period: '2026-05', mensalidade_micros: -1)
      expect(record).not_to be_valid
      expect(record.errors[:mensalidade_micros]).to be_present
    end
  end

  describe 'scope global_defaults' do
    it 'returns only rows with account_id NULL' do
      global = described_class.create!(account_id: nil, period: '2026-05')
      described_class.create!(account_id: account.id, period: '2026-05')

      expect(described_class.global_defaults).to contain_exactly(global)
    end
  end

  describe '.for_account_and_period' do
    it 'returns the account row when it exists' do
      account_row = described_class.create!(account_id: account.id, period: '2026-05')
      described_class.create!(account_id: nil, period: '2026-05')

      expect(described_class.for_account_and_period(account.id, '2026-05')).to eq(account_row)
    end

    it 'falls back to the global (account_id NULL) row when no account row exists' do
      global = described_class.create!(account_id: nil, period: '2026-05')

      expect(described_class.for_account_and_period(account.id, '2026-05')).to eq(global)
    end

    it 'returns nil when neither an account row nor a global row exists' do
      expect(described_class.for_account_and_period(account.id, '2026-05')).to be_nil
    end
  end

  describe '#effective_taxa_paga' do
    it 'returns taxa_paga directly when it is present' do
      record = described_class.new(period: '2026-05', taxa_paga: 5.72)
      expect(record.effective_taxa_paga(total_usd_micros: 100_000_000)).to eq(5.72)
    end

    it 'derives the effective rate from total_brl_pago_micros / total_usd_micros when taxa_paga is absent (D-01a)' do
      # R$540 paid / US$100 used = 5.4 exact
      record = described_class.new(period: '2026-05', total_brl_pago_micros: 540_000_000)
      expect(record.effective_taxa_paga(total_usd_micros: 100_000_000)).to eq(5.4)
    end

    it 'returns nil when neither taxa_paga nor total_brl_pago_micros is informed (consumer falls back to 5,4 — D-06)' do
      record = described_class.new(period: '2026-05')
      expect(record.effective_taxa_paga(total_usd_micros: 100_000_000)).to be_nil
    end

    it 'returns nil when total_usd_micros is zero (avoids division by zero — T-07B-04)' do
      record = described_class.new(period: '2026-05', total_brl_pago_micros: 540_000_000)
      expect(record.effective_taxa_paga(total_usd_micros: 0)).to be_nil
    end
  end
end
