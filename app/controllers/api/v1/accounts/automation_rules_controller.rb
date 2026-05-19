class Api::V1::Accounts::AutomationRulesController < Api::V1::Accounts::BaseController
  include AttachmentConcern

  before_action :check_authorization
  before_action :fetch_automation_rule, only: [:show, :update, :destroy, :clone, :dry_run, :runs]

  def index
    @automation_rules = Current.account.automation_rules
  end

  def show; end

  def create
    blobs, actions, error = validate_and_prepare_attachments(params[:actions])
    return render_could_not_create_error(error) if error

    @automation_rule = Current.account.automation_rules.new(automation_rules_permit)
    @automation_rule.actions = actions
    @automation_rule.conditions = params[:conditions]

    return render_could_not_create_error(@automation_rule.errors.messages) unless @automation_rule.valid?

    @automation_rule.save!
    blobs.each { |blob| @automation_rule.files.attach(blob) }
  end

  def update
    blobs, actions, error = validate_and_prepare_attachments(params[:actions], @automation_rule)
    return render_could_not_create_error(error) if error

    ActiveRecord::Base.transaction do
      @automation_rule.assign_attributes(automation_rules_permit)
      @automation_rule.actions = actions if params[:actions]
      @automation_rule.conditions = params[:conditions] if params[:conditions]
      @automation_rule.save!
      blobs.each { |blob| @automation_rule.files.attach(blob) }
    rescue StandardError => e
      Rails.logger.error e
      render_could_not_create_error(@automation_rule.errors.messages)
    end
  end

  def destroy
    @automation_rule.destroy!
    head :ok
  end

  def clone
    automation_rule = Current.account.automation_rules.find_by(id: params[:automation_rule_id])
    new_rule = automation_rule.dup
    new_rule.save!
    @automation_rule = new_rule
  end

  # AUT-07: dry-run sem persistir efeitos. Aceita event_payload arbitrario do admin
  # (card_id, message_id, conversation_id, column_changed, etc) e retorna preview.
  def dry_run
    event_payload = params.require(:event_payload).permit(:card_id, :message_id, :conversation_id,
                                                          :column_id, :target_column_id,
                                                          :source_column_id, :column_changed).to_h
    @result = AutomationRules::DryRunService.new(rule: @automation_rule, event_payload: event_payload).perform
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  end

  # AUT-08: lista paginada keyset de execucoes desta regra.
  def runs
    scope = @automation_rule.automation_rule_runs.recent
    scope = scope.where('id < ?', params[:before].to_i) if params[:before].present?
    @runs = scope.limit(params[:limit].present? ? params[:limit].to_i.clamp(1, 100) : 20)
  end

  private

  def automation_rules_permit
    params.permit(
      :name, :description, :event_name, :active, :abort_on_fail,
      conditions: [:attribute_key, :filter_operator, :query_operator, :custom_attribute_type, { values: [] }],
      actions: [:action_name, { action_params: [] }]
    )
  end

  def fetch_automation_rule
    @automation_rule = Current.account.automation_rules.find_by(id: params[:id])
  end
end
