# Phase 3 AUT-10 — Reagenda envio de mensagem da automação quando o throttle (ThrottleService)
# estourou no minuto atual. Não perde execução: mantém run_id e re-executa a tentativa real
# quando o bucket Redis libera. Se o gate 24h expirar entre tentativas, marca como blocked_24h.
class AutomationRules::SendMessageRescheduledJob < ApplicationJob
  queue_as :default

  def perform(rule_id, message_array, conversation_id, run_id = nil)
    rule = AutomationRule.find_by(id: rule_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if rule.nil? || conversation.nil?

    run = AutomationRuleRun.find_by(id: run_id) if run_id
    args = [rule_id, message_array, conversation_id, run_id]
    return if reschedule_if_still_throttled(conversation, args)
    return if block_if_window_expired(run, conversation)

    deliver_message(rule, conversation, message_array, run)
  rescue StandardError => e
    handle_error(e, conversation, run)
  end

  private

  def reschedule_if_still_throttled(conversation, args)
    acquire_result = AutomationRules::ThrottleService.new(inbox: conversation.inbox).acquire
    return false unless acquire_result.is_a?(Integer)

    self.class.set(wait: acquire_result.seconds).perform_later(*args)
    true
  end

  def block_if_window_expired(run, conversation)
    # NOTA: action_params do override original NÃO é preservado aqui (limitação v1).
    return false unless Messages::Whatsapp24hGate.allowed?(conversation: conversation, action_params: {}) == :blocked

    run&.mark_last_action_status('blocked_24h', error: 'WhatsApp 24h window expired (after reschedule)')
    true
  end

  def deliver_message(rule, conversation, message_array, run)
    params = { content: message_array[0], private: false, content_attributes: { automation_rule_id: rule.id } }
    Messages::MessageBuilder.new(nil, conversation, params).perform
    run&.mark_last_action_status('ok', sent_at: Time.current.iso8601)
  end

  def handle_error(exception, conversation, run)
    ChatwootExceptionTracker.new(exception, account: conversation&.account).capture_exception
    run&.mark_last_action_status('error', error: exception.message[0, 200])
  end
end
