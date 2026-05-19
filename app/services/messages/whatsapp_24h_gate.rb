# Phase 3 AUT-09 — Stateless boundary check para janela 24h em WhatsApp (Baileys).
# Bloqueia envio automatizado em Channel::Whatsapp quando última mensagem incoming foi > 24h atrás
# (proteção contra ban via heurística da Meta). Override per-action via outside_24h_window_allowed.
# No-op para canais não-whatsapp (Email/Telegram/Web/Api) e Twilio WhatsApp (fora de scope Phase 3).
class Messages::Whatsapp24hGate
  # Returns :allowed or :blocked
  def self.allowed?(conversation:, action_params:)
    return :allowed if conversation.nil?
    return :allowed unless conversation.inbox.whatsapp?
    return :allowed if override_enabled?(action_params)

    last_in = last_incoming_at(conversation)
    return :allowed if last_in.present? && last_in > 24.hours.ago

    :blocked
  end

  # Pivô 4 do RESEARCH: query on-demand. Index existente
  # (index_messages_on_conversation_account_type_created) cobre em <2ms.
  def self.last_incoming_at(conversation)
    conversation.messages
                .where(account_id: conversation.account_id, message_type: :incoming)
                .order(created_at: :desc)
                .limit(1)
                .pick(:created_at)
  end

  def self.override_enabled?(action_params)
    # action_params pode ser Array (formato legado AutomationRule.actions[i].action_params = ["msg"])
    # ou Hash (formato novo com toggle). Só Hash carrega o flag.
    return false unless action_params.is_a?(Hash)

    value = action_params['outside_24h_window_allowed'] || action_params[:outside_24h_window_allowed]
    value == true || value == 'true'
  end
end
