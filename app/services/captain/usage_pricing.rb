# Computes, for a single account in a given month, the cost composition (text/audio/ocr),
# the two BRL bases (paid rate vs current rate, the higher being the suggested charging base — SPEC req 4),
# and the sale price + margin (SPEC req 6). Pure calculation seam — no DB access, fully unit-testable.
class Captain::UsagePricing
  TEXT_FEATURES = %w[task agent copilot assistant].freeze
  AUDIO_FEATURES = %w[audio_transcription].freeze
  OCR_FEATURES = %w[ocr vision].freeze

  # feature_entries: array of [feature, count, cost_usd_micros]
  # billing: Captain::BillingMonth or nil; fallback_rate: USD_BRL_RATE (D-06)
  def initialize(account_id:, account_name:, feature_entries:, billing:, fallback_rate:)
    @account_id = account_id
    @account_name = account_name
    @feature_entries = feature_entries
    @billing = billing
    @fallback_rate = fallback_rate
  end

  def row
    counts = feature_counts
    uso = counts.values.sum
    bases = compute_bases
    pricing = compute_pricing(uso, bases[:custo_base])

    {
      account_id: @account_id,
      account_name: @account_name,
      text_count: counts[:text], audio_count: counts[:audio], ocr_count: counts[:ocr],
      uso: uso,
      cost_usd_micros: cost_usd_micros,
      cost_usd: cost_usd_micros / 1_000_000.0
    }.merge(bases).merge(pricing)
  end

  private

  def cost_usd_micros
    @cost_usd_micros ||= @feature_entries.sum { |_feature, _count, usd| usd.to_i }
  end

  def feature_counts
    counts = { text: 0, audio: 0, ocr: 0 }
    @feature_entries.each do |feature, count, _usd|
      bucket = feature_bucket(feature)
      counts[bucket] += count.to_i if bucket
    end
    counts
  end

  def feature_bucket(feature)
    return :text if TEXT_FEATURES.include?(feature)
    return :audio if AUDIO_FEATURES.include?(feature)
    return :ocr if OCR_FEATURES.include?(feature)

    nil
  end

  def compute_bases
    taxa_paga = @billing&.effective_taxa_paga(total_usd_micros: cost_usd_micros) || @fallback_rate
    taxa_atual = @billing&.taxa_atual || @fallback_rate

    base_paga = brl(cost_usd_micros, taxa_paga)
    base_atual = brl(cost_usd_micros, taxa_atual)

    { base_paga: base_paga, base_atual: base_atual, custo_base: [base_paga, base_atual].max,
      base_sugerida: base_paga >= base_atual ? :paga : :atual }
  end

  def brl(usd_micros, rate)
    Captain::UsageCostCalculator.brl_micros_from_usd(cost_usd_micros: usd_micros, rate: rate) / 1_000_000.0
  end

  def compute_pricing(uso, custo_base)
    mensalidade = (@billing&.mensalidade_micros || 0) / 1_000_000.0
    excedente_unit = (@billing&.preco_excedente_micros || 0) / 1_000_000.0
    inclusas = @billing&.unidades_inclusas || 0
    overage = [0, uso - inclusas].max
    preco_venda = mensalidade + (excedente_unit * overage)

    { preco_venda: preco_venda, margem: preco_venda - custo_base }
  end
end
