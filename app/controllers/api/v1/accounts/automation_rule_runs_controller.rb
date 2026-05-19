# AUT-08 (D-E5): tela global cross-regra de historico de execucoes.
# Filtros: rule_id, status, from, to, before (paginacao keyset).
class Api::V1::Accounts::AutomationRuleRunsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @runs = filtered_scope.limit(page_limit)
  end

  def show
    @run = Current.account.automation_rule_runs.find(params[:id])
  end

  private

  def filtered_scope
    apply_id_filters(apply_date_filters(Current.account.automation_rule_runs.recent))
  end

  def apply_id_filters(scope)
    scope = scope.where(automation_rule_id: params[:rule_id]) if params[:rule_id].present?
    scope = scope.where(status: AutomationRuleRun.statuses[params[:status]]) if valid_status_filter?
    scope = scope.where('id < ?', params[:before].to_i) if params[:before].present?
    scope
  end

  def apply_date_filters(scope)
    scope = scope.where('created_at >= ?', Time.zone.parse(params[:from])) if params[:from].present?
    scope = scope.where('created_at < ?', Time.zone.parse(params[:to])) if params[:to].present?
    scope
  end

  def valid_status_filter?
    params[:status].present? && AutomationRuleRun.statuses.key?(params[:status])
  end

  def page_limit
    params[:limit].present? ? params[:limit].to_i.clamp(1, 100) : 20
  end
end
