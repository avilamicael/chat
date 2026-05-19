class AutomationRules::ActionService < ActionService
  def initialize(rule, account, conversation, card: nil, run: nil)
    super(conversation)
    @rule = rule
    @account = account
    @card = card
    @run = run                       # Plan C — opcional, populado pelo listener wrap
    @current_action_params = nil     # Plan D — consumido pelo gate 24h dentro de send_message
    @current_action_index = nil      # Plan D — usado por finalize_current_action
    @current_action_finalized = false # Plan D — sinaliza ao loop pular o push 'ok' default
    Current.executed_by = rule
  end

  def perform # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/CyclomaticComplexity
    push_automation_frame
    any_error = nil
    any_error_message = nil

    @rule.actions.each_with_index do |action, idx|
      @conversation&.reload
      action = action.with_indifferent_access
      @current_action_params = action[:action_params]
      @current_action_index = idx
      @current_action_finalized = false
      started_at = Time.current
      begin
        send(action[:action_name], action[:action_params])
        next if @current_action_finalized

        @run&.push_action_log(idx, action[:action_name], status: 'ok',
                                                         duration_ms: ((Time.current - started_at) * 1000).to_i)
      rescue StandardError => e
        any_error = e
        any_error_message = e.message[0, 500]
        @run&.push_action_log(idx, action[:action_name], status: 'error',
                                                         error: e.message[0, 200],
                                                         duration_ms: ((Time.current - started_at) * 1000).to_i)
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
        if @rule.abort_on_fail
          mark_remaining_as_not_executed(idx + 1)
          any_error_message = "Aborted after action #{idx} (abort_on_fail=true)"
          break
        end
      end
    end

    record_execution_result(any_error, any_error_message)
  ensure
    pop_automation_frame
  end

  private

  def mark_remaining_as_not_executed(start_idx)
    return unless @run

    (start_idx...@rule.actions.length).each do |i|
      action = @rule.actions[i].with_indifferent_access
      @run.push_action_log(i, action[:action_name], status: 'not_executed', reason: 'previous action failed')
    end
  end

  def push_automation_frame
    Current.automation_depth = Current.automation_depth.to_i + 1
    Current.automation_chain = (Current.automation_chain || []) + [@rule.id]
  end

  def pop_automation_frame
    Current.automation_depth = Current.automation_depth.to_i - 1
    Current.automation_chain = Current.automation_chain.is_a?(Array) ? Current.automation_chain[0...-1] : nil
    Current.reset if Current.automation_depth.to_i <= 0
  end

  def record_execution_result(any_error, any_error_message)
    if any_error
      @rule.update_columns( # rubocop:disable Rails/SkipsModelValidations
        last_execution_status: 'error',
        last_execution_error: any_error_message,
        last_executed_at: Time.current
      )
    else
      @rule.update_columns( # rubocop:disable Rails/SkipsModelValidations
        last_execution_status: 'ok',
        last_execution_error: nil,
        last_executed_at: Time.current
      )
    end
  end

  def send_attachment(blob_ids)
    return if @conversation.nil?
    return if conversation_a_tweet?

    return unless @rule.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  def send_webhook_event(webhook_url)
    return if @conversation.nil?

    payload = @conversation.webhook_data.merge(event: "automation_event.#{@rule.event_name}")
    WebhookJob.perform_later(webhook_url[0], payload)
  end

  def send_message(message)
    return if @conversation.nil?
    return if conversation_a_tweet?
    return if blocked_by_whatsapp_24h_gate?
    return if queued_by_whatsapp_throttle?(message)

    params = { content: message[0], private: false, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation, params).perform
  end

  # Phase 3 D-F2 — 24h window gate (Channel::Whatsapp only; outras canais passam reto).
  def blocked_by_whatsapp_24h_gate?
    return false unless Messages::Whatsapp24hGate.allowed?(conversation: @conversation,
                                                           action_params: @current_action_params) == :blocked

    finalize_current_action('send_message', status: 'blocked_24h', error: 'WhatsApp 24h window expired')
    true
  end

  # Phase 3 D-G3 — throttle per inbox (Channel::Whatsapp only); overflow reagenda via Sidekiq.
  def queued_by_whatsapp_throttle?(message)
    acquire = AutomationRules::ThrottleService.new(inbox: @conversation.inbox).acquire
    return false unless acquire.is_a?(Integer)

    AutomationRules::SendMessageRescheduledJob
      .set(wait: acquire.seconds)
      .perform_later(@rule.id, message, @conversation.id, @run&.id)
    finalize_current_action('send_message', status: 'queued', rescheduled_to: acquire.seconds.from_now.iso8601)
    true
  end

  # Marca o action_log do índice atual + sinaliza ao loop perform para pular o push default 'ok'.
  def finalize_current_action(action_name, **attrs)
    @run&.push_action_log(@current_action_index, action_name, **attrs)
    @current_action_finalized = true
  end

  def add_private_note(message)
    return if @conversation.nil?
    return if conversation_a_tweet?

    params = { content: message[0], private: true, content_attributes: { automation_rule_id: @rule.id } }
    Messages::MessageBuilder.new(nil, @conversation.reload, params).perform
  end

  def send_email_to_team(params)
    return if @conversation.nil?

    teams = Team.where(id: params[0][:team_ids])

    teams.each do |team|
      break unless @account.within_email_rate_limit?

      TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      @account.increment_email_sent_count
    end
  end

  def scheduled_message_attachment_blob(blob_id)
    return if blob_id.blank?

    attachment = @rule.files.find { |file| file.blob_id == blob_id.to_i }
    attachment&.blob
  end
end
