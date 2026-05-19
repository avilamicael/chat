# AUT-07: simula execucao de uma AutomationRule sem persistir efeitos.
# Resolve conditions (via ConditionsFilterService apropriado por event_name),
# resolve Liquid no action_params, e retorna preview estruturado.
#
# CRITICOS:
# - NAO incrementa Current.automation_depth (nao persiste = nao conta no anti-loop)
# - NAO cria AutomationRuleRun
# - NAO chama Messages::MessageBuilder / WebhookJob / qualquer side effect
# - Tenant isolation (T-03C-05): build_context escopa lookups via @rule.account
#
# Saida:
#   { matched: true|false, conditions_evaluation: {...}, actions_preview: [...] }
class AutomationRules::DryRunService
  def initialize(rule:, event_payload:)
    @rule = rule
    @event_payload = event_payload.is_a?(Hash) ? event_payload.with_indifferent_access : {}.with_indifferent_access
  end

  def perform
    context = build_context
    return error_result('Unable to load context for the provided payload.') if context.nil?

    conditions_result = evaluate_conditions(context)
    return { matched: false, conditions_evaluation: conditions_result, actions_preview: [] } unless conditions_result[:matched]

    { matched: true, conditions_evaluation: conditions_result, actions_preview: preview_actions(context) }
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @rule.account).capture_exception
    error_result(e.message[0, 200])
  end

  private

  # T-03C-05 mitigation: todos os lookups passam por @rule.account (tenant scope).
  # Cards de outras accounts retornam nil → error_result.
  def build_context
    case @rule.event_name
    when 'message_created'
      build_message_context
    when 'kanban_card_moved', 'kanban_card_added', 'kanban_card_removed'
      build_kanban_context
    when /^conversation_/
      build_conversation_context
    end
  end

  def build_message_context
    conversation = @rule.account.conversations.find_by(id: @event_payload[:conversation_id])
    return nil if conversation.nil?

    message = conversation.messages.find_by(id: @event_payload[:message_id])
    return nil if message.nil?

    { conversation: conversation, message: message, card: nil }
  end

  def build_kanban_context
    card = KanbanCard.joins(:kanban_board).find_by(id: @event_payload[:card_id],
                                                   kanban_boards: { account_id: @rule.account_id })
    return nil if card.nil?

    { conversation: card.conversation, message: nil, card: card }
  end

  def build_conversation_context
    conversation = @rule.account.conversations.find_by(id: @event_payload[:conversation_id])
    return nil if conversation.nil?

    { conversation: conversation, message: nil, card: nil }
  end

  def evaluate_conditions(context)
    matched = if kanban_event?
                kanban_options = @event_payload.slice(:source_column_id, :target_column_id, :column_changed).to_h.symbolize_keys
                ::Kanban::ConditionsFilterService.new(@rule, context[:card],
                                                      conversation: context[:conversation],
                                                      options: kanban_options).perform
              elsif @rule.event_name == 'message_created'
                ::AutomationRules::ConditionsFilterService.new(@rule, context[:conversation], { message: context[:message] }).perform
              else
                ::AutomationRules::ConditionsFilterService.new(@rule, context[:conversation], {}).perform
              end

    { matched: matched.present?, passed: @rule.conditions, failed: [] }
  end

  def preview_actions(context)
    @rule.actions.map.with_index do |raw, idx|
      action = raw.with_indifferent_access
      build_action_preview(idx, action, context)
    end
  end

  def build_action_preview(idx, action, context)
    preview = { action_index: idx, action_name: action[:action_name] }
    case action[:action_name]
    when 'send_webhook_event'
      preview[:resolved_params] = resolve_webhook(action[:action_params], context)
    when 'send_message'
      preview[:resolved_content] = resolve_send_message(action[:action_params], context)
      preview[:would_block_24h] = check_24h_block(context)
    else
      preview[:resolved_params] = action[:action_params]
    end
    preview
  end

  def resolve_send_message(action_params, context)
    template = action_params.is_a?(Array) ? action_params[0] : action_params.to_s
    resolve_liquid(template, context)
  end

  def kanban_event?
    @rule.event_name.start_with?('kanban_card_')
  end

  def resolve_webhook(params, context)
    return { url: nil, method: nil, body_resolved: '' } unless params.is_a?(Hash) || params.respond_to?(:with_indifferent_access)

    hash = params.respond_to?(:with_indifferent_access) ? params.with_indifferent_access : {}
    {
      url: hash[:url],
      method: hash[:method],
      body_resolved: resolve_liquid(hash[:body].to_s, context)
    }
  end

  def resolve_liquid(template_str, context)
    return template_str if template_str.blank?

    Liquid::Template.parse(template_str).render(liquid_assigns(context))
  rescue StandardError => e
    "[Liquid error: #{e.message[0, 100]}]"
  end

  def liquid_assigns(context)
    {
      'card' => card_assigns(context[:card]),
      'conversation' => conversation_assigns(context[:conversation]),
      'contact' => contact_assigns(context[:conversation]),
      'column' => column_assigns(context[:card])
    }
  end

  def card_assigns(card)
    card&.attributes&.slice('id', 'title', 'description')
  end

  def conversation_assigns(conversation)
    conversation&.attributes&.slice('id', 'status')
  end

  def contact_assigns(conversation)
    conversation&.contact&.attributes&.slice('id', 'name', 'email')
  end

  def column_assigns(card)
    card&.kanban_column&.attributes&.slice('id', 'name')
  end

  # Preview-only: informa se a action seria bloqueada pelo gate 24h (Plan D).
  # Plan D introduz Messages::Whatsapp24hGate; aqui apenas detecta heuristicamente
  # para o admin ver no painel de dry-run.
  def check_24h_block(context)
    inbox = context[:conversation]&.inbox
    return false unless inbox.respond_to?(:whatsapp?) && inbox.whatsapp?

    last_in = context[:conversation].messages.where(message_type: :incoming).order(created_at: :desc).limit(1).pick(:created_at)
    last_in.nil? || last_in < 24.hours.ago
  end

  def error_result(msg)
    { matched: false, conditions_evaluation: { error: msg }, actions_preview: [] }
  end
end
