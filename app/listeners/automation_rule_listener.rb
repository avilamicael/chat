class AutomationRuleListener < BaseListener
  def conversation_updated(event)
    process_conversation_event(event, 'conversation_updated')
  end

  def conversation_created(event)
    process_conversation_event(event, 'conversation_created')
  end

  def conversation_opened(event)
    process_conversation_event(event, 'conversation_opened')
  end

  def conversation_resolved(event)
    process_conversation_event(event, 'conversation_resolved')
  end

  def message_created(event)
    message = event.data[:message]

    return if ignore_message_created_event?(event)

    account = message.try(:account)
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?('message_created', account)
    return if Current.automation_depth.to_i > 5

    rules = current_account_rules('message_created', account)

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, message.conversation,
                                                                        { message: message, changed_attributes: changed_attributes }).perform
      ::AutomationRules::ActionService.new(rule, account, message.conversation).perform if conditions_match.present?
    end
  end

  def kanban_card_moved(event)
    process_kanban_event(event, 'kanban_card_moved')
  end

  def kanban_card_added(event)
    process_kanban_event(event, 'kanban_card_added')
  end

  def kanban_card_removed(event)
    process_kanban_event(event, 'kanban_card_removed')
  end

  private

  def process_conversation_event(event, event_name)
    return if performed_by_automation?(event)
    return if skip_for_auto_reply?(event, event_name)

    conversation = event.data[:conversation]
    account = conversation.account
    changed_attributes = event.data[:changed_attributes]

    return unless rule_present?(event_name, account)
    return if Current.automation_depth.to_i > 5

    rules = current_account_rules(event_name, account)

    rules.each do |rule|
      conditions_match = ::AutomationRules::ConditionsFilterService.new(rule, conversation, { changed_attributes: changed_attributes }).perform
      AutomationRules::ActionService.new(rule, account, conversation).perform if conditions_match.present?
    end
  end

  def skip_for_auto_reply?(event, event_name)
    auto_reply_skip_events = %w[conversation_created conversation_opened]
    auto_reply_skip_events.include?(event_name) && ignore_auto_reply_event?(event)
  end

  def process_kanban_event(event, event_name)
    # D-A3: reorder mesma coluna (column_changed=false) nao conta como move semantico.
    return if event_name == 'kanban_card_moved' && !event.data[:column_changed]

    card = event.data[:card]
    return unless card

    account = card.kanban_board.account
    return unless rule_present?(event_name, account)

    return abort_loop_and_disable!(event_name, account) if Current.automation_depth.to_i > 5

    options = event.data.slice(:source_column_id, :target_column_id, :column_changed, :performed_by, :trigger_event_id)
    current_account_rules(event_name, account).each do |rule|
      apply_kanban_rule(rule, card, account, options)
    end
  end

  def apply_kanban_rule(rule, card, account, options)
    # Kanban::ConditionsFilterService eh entregue no Plan B desta fase. Enquanto nao mergeou, evita NameError.
    return unless defined?(::Kanban::ConditionsFilterService)

    conditions_match = ::Kanban::ConditionsFilterService.new(rule, card, conversation: card.conversation, options: options).perform
    return if conditions_match.blank?

    ::AutomationRules::ActionService.new(rule, account, card.conversation, card: card).perform
  end

  def abort_loop_and_disable!(event_name, account)
    # TODO(Plan C): expandir helper para invocar NotificationBuilder (automation_rule_loop_aborted)
    # + cadeia de rule_ids visitados. Stub atual loga + flips active=false para impedir cascata.
    current_account_rules(event_name, account).each do |rule|
      Rails.logger.warn(
        "[automation_loop_aborted] rule_id=#{rule.id} account_id=#{account.id} event=#{event_name} depth=#{Current.automation_depth}"
      )
      rule.update_columns( # rubocop:disable Rails/SkipsModelValidations
        active: false,
        last_execution_status: 'error',
        last_execution_error: "[loop_aborted] depth=#{Current.automation_depth}",
        last_executed_at: Time.current
      )
      Rails.cache.delete("automation_rules:#{account.id}:#{event_name}")
    end
    nil
  end

  def rule_present?(event_name, account)
    return false if account.blank?

    current_account_rules(event_name, account).any?
  end

  def current_account_rules(event_name, account)
    Rails.cache.fetch("automation_rules:#{account.id}:#{event_name}", expires_in: 60.seconds, race_condition_ttl: 5) do
      AutomationRule.where(event_name: event_name, account_id: account.id, active: true).to_a
    end
  end

  def performed_by_automation?(event)
    event.data[:performed_by].present? && event.data[:performed_by].instance_of?(AutomationRule)
  end

  def ignore_auto_reply_event?(event)
    conversation = event.data[:conversation]
    conversation.additional_attributes['auto_reply'].present?
  end

  def ignore_message_created_event?(event)
    message = event.data[:message]
    performed_by_automation?(event) || message.activity? || message.auto_reply_email?
  end
end
