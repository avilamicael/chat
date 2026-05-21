class SuperAdmin::CaptainUsageController < SuperAdmin::ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
    @rows = build_rows(current_month_aggregates)
    assign_totals(@rows)
  end

  private

  def current_month_aggregates
    Captain::UsageEvent
      .where(created_at: Time.current.beginning_of_month..Time.current)
      .group(:account_id)
      .pluck(
        :account_id,
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(input_tokens), 0)'),
        Arel.sql('COALESCE(SUM(output_tokens), 0)'),
        Arel.sql('COALESCE(SUM(cost_micros), 0)')
      )
  end

  def build_rows(aggregates)
    account_names = Account.where(id: aggregates.map(&:first)).pluck(:id, :name).to_h

    rows = aggregates.map do |account_id, responses_count, input_tokens, output_tokens, cost_micros|
      {
        account_id: account_id,
        account_name: account_names[account_id] || "Account ##{account_id}",
        responses_count: responses_count,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cost_micros: cost_micros,
        cost_brl: cost_micros / 1_000_000.0
      }
    end

    rows.sort_by { |row| -row[:cost_micros] }
  end

  def assign_totals(rows)
    @total_responses_count = rows.sum { |row| row[:responses_count] }
    @total_input_tokens = rows.sum { |row| row[:input_tokens] }
    @total_output_tokens = rows.sum { |row| row[:output_tokens] }
    @total_cost_micros = rows.sum { |row| row[:cost_micros] }
    @total_cost_brl = @total_cost_micros / 1_000_000.0
  end
end
