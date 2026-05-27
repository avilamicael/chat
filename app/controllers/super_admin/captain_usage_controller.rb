class SuperAdmin::CaptainUsageController < SuperAdmin::ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
    @period = sanitized_period(params[:month])
    @billing_by_account = Captain::BillingMonth.for_period(@period).index_by(&:account_id)
    @rows = build_rows(period_aggregates(@period))
    assign_totals(@rows)
  end

  # POST — inline edit of exchange rates and sale-price params (D-03). account_id absent => global default.
  def update_billing
    period = params[:period]
    account_id = params[:account_id].presence
    # Accepted limitation (WR-04): concurrent POSTs for the same (account_id, period) can hit the
    # partial unique index and 500. Single-super-admin tool — no defensive retry per MVP rule.
    billing = Captain::BillingMonth.find_or_initialize_by(account_id: account_id, period: period)
    billing.assign_attributes(billing_params)

    # rubocop:disable Rails/I18nLocaleTexts -- Super Admin flash strings are PT-BR hardcoded (local convention)
    if non_negative?(billing) && billing.save
      redirect_to super_admin_captain_usage_index_path(month: period), notice: 'Parâmetros de cobrança salvos com sucesso.'
    else
      messages = billing.errors.full_messages.presence || ['Valores inválidos: números não podem ser negativos.']
      redirect_to super_admin_captain_usage_index_path(month: period), alert: messages.join(', ')
    end
    # rubocop:enable Rails/I18nLocaleTexts
  end

  private

  def sanitized_period(month)
    return Date.current.strftime('%Y-%m') if month.blank?

    Date.strptime(month, '%Y-%m').strftime('%Y-%m')
  rescue ArgumentError
    Date.current.strftime('%Y-%m')
  end

  def period_aggregates(period)
    date = Date.strptime(period, '%Y-%m')
    range = date.all_month
    Captain::UsageEvent
      .where(created_at: range)
      .group(:account_id, :feature)
      .pluck(
        :account_id,
        :feature,
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(cost_usd_micros), 0)')
      )
  end

  def build_rows(aggregates)
    account_ids = aggregates.map(&:first).uniq
    @account_names = Account.where(id: account_ids).pluck(:id, :name).to_h
    @fallback_rate = Captain::UsageCostCalculator.usd_brl_rate

    # D-01a: the OpenAI invoice covers the WHOLE installation, so the derived paid rate is
    # total_BRL_pago / total_USD_do_mês (month-wide USD across all accounts), resolved ONCE here
    # rather than per account (which would divide the month total by each account's slice).
    month_total_usd_micros = aggregates.sum { |_id, _feature, _count, usd| usd.to_i }
    global_billing = @billing_by_account[nil]
    @global_derived_paga = global_billing&.effective_taxa_paga(total_usd_micros: month_total_usd_micros)

    rows = aggregates.group_by(&:first).map { |account_id, entries| pricing_row(account_id, entries) }
    rows.sort_by { |row| -row[:custo_base] }
  end

  def pricing_row(account_id, entries)
    feature_entries = entries.map { |_id, feature, count, usd| [feature, count, usd] }
    Captain::UsagePricing.new(
      account_id: account_id,
      account_name: @account_names[account_id] || "Account ##{account_id}",
      feature_entries: feature_entries,
      billing: effective_billing_params(account_id),
      taxa_paga: resolved_taxa_paga(account_id),
      fallback_rate: @fallback_rate
    ).row
  end

  # Resolved paid rate precedence (D-01a/D-01b): per-account override's own explicit rate,
  # else the global month-wide derived rate, else the global row's own direct rate. nil => PORO falls back to 5,4 (D-06).
  def resolved_taxa_paga(account_id)
    override = @billing_by_account[account_id]
    return override.taxa_paga if override&.taxa_paga.present?

    @global_derived_paga || @billing_by_account[nil]&.taxa_paga
  end

  # WR-03: sale-price params fall back FIELD-BY-FIELD to the global default when a per-account
  # override leaves them NULL (so setting only a rate does not silently zero the monthly fee).
  def effective_billing_params(account_id)
    override = @billing_by_account[account_id]
    global = @billing_by_account[nil]
    return global if override.nil?
    return override if global.nil?

    Captain::BillingMonth.new(
      period: override.period,
      account_id: override.account_id,
      taxa_atual: override.taxa_atual || global.taxa_atual,
      mensalidade_micros: override.mensalidade_micros || global.mensalidade_micros,
      unidades_inclusas: override.unidades_inclusas || global.unidades_inclusas,
      preco_excedente_micros: override.preco_excedente_micros || global.preco_excedente_micros
    )
  end

  def assign_totals(rows)
    @total_uso = rows.sum { |row| row[:uso] }
    @total_cost_usd = rows.sum { |row| row[:cost_usd] }
    @total_custo_base = rows.sum { |row| row[:custo_base] }
    @total_preco_venda = rows.sum { |row| row[:preco_venda] }
    @total_margem = rows.sum { |row| row[:margem] }
  end

  def non_negative?(billing)
    numeric = [billing.taxa_paga, billing.taxa_atual, billing.total_brl_pago_micros,
               billing.mensalidade_micros, billing.unidades_inclusas, billing.preco_excedente_micros]
    numeric.compact.all? { |value| value.to_f >= 0 }
  end

  def billing_params
    params.require(:billing).permit(
      :taxa_paga, :taxa_atual, :total_brl_pago_micros,
      :mensalidade_micros, :unidades_inclusas, :preco_excedente_micros
    )
  end
end
