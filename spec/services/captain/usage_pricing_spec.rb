require 'rails_helper'

RSpec.describe Captain::UsagePricing do
  def billing(attrs)
    Captain::BillingMonth.new({ period: '2026-04' }.merge(attrs))
  end

  def row_for(feature_entries:, billing: nil, fallback_rate: 5.4)
    described_class.new(
      account_id: 1, account_name: 'Acme',
      feature_entries: feature_entries, billing: billing, fallback_rate: fallback_rate
    ).row
  end

  describe 'two BRL bases and suggested base (SPEC req 4)' do
    let(:entries) { [['task', 1, 10_000_000]] } # US$ 10

    it 'flags the current-rate base as suggested when it is higher' do
      row = row_for(feature_entries: entries, billing: billing(taxa_paga: 5.00, taxa_atual: 5.80))
      expect(row[:base_paga]).to be_within(0.001).of(50.0)
      expect(row[:base_atual]).to be_within(0.001).of(58.0)
      expect(row[:custo_base]).to be_within(0.001).of(58.0)
      expect(row[:base_sugerida]).to eq(:atual)
    end

    it 'flags the paid-rate base as suggested when it is higher' do
      row = row_for(feature_entries: entries, billing: billing(taxa_paga: 5.80, taxa_atual: 5.00))
      expect(row[:base_sugerida]).to eq(:paga)
      expect(row[:custo_base]).to be_within(0.001).of(58.0)
    end

    it 'uses the 5.4 fallback for both bases when there is no billing (D-06)' do
      row = row_for(feature_entries: entries, billing: nil)
      expect(row[:base_paga]).to be_within(0.001).of(54.0)
      expect(row[:base_atual]).to be_within(0.001).of(54.0)
    end
  end

  describe 'sale price and margin (SPEC req 6)' do
    it 'computes preco_venda = mensalidade + excedente x max(0, uso - X)' do
      entries = [['task', 1200, 0]]
      row = row_for(
        feature_entries: entries,
        billing: billing(taxa_paga: 5.4, taxa_atual: 5.4,
                         mensalidade_micros: 200_000_000, unidades_inclusas: 1000, preco_excedente_micros: 200_000)
      )
      expect(row[:uso]).to eq(1200)
      expect(row[:preco_venda]).to be_within(0.001).of(240.0)
      expect(row[:margem]).to be_within(0.001).of(240.0 - row[:custo_base])
    end

    it 'applies zero overage when uso is below X' do
      entries = [['task', 500, 0]]
      row = row_for(
        feature_entries: entries,
        billing: billing(mensalidade_micros: 200_000_000, unidades_inclusas: 1000, preco_excedente_micros: 200_000)
      )
      expect(row[:uso]).to eq(500)
      expect(row[:preco_venda]).to be_within(0.001).of(200.0)
    end
  end

  describe 'composition by feature bucket' do
    it 'separates text, audio and ocr counts' do
      entries = [['task', 1, 0], ['agent', 1, 0], ['audio_transcription', 1, 0], ['ocr', 1, 0], ['vision', 1, 0]]
      row = row_for(feature_entries: entries)
      expect(row[:text_count]).to eq(2)
      expect(row[:audio_count]).to eq(1)
      expect(row[:ocr_count]).to eq(2)
    end
  end
end
