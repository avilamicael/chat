class Kanban::ColumnActionService < ActionService
  def initialize(conversation, actions, account)
    super(conversation)
    @actions = actions || []
    @account = account
  end

  def perform
    @actions.each do |action|
      action = action.with_indifferent_access
      next if action[:action_name].blank?

      begin
        send(action[:action_name], action[:action_params])
      rescue NoMethodError
        Rails.logger.warn "KanbanColumnAction: unknown action '#{action[:action_name]}'"
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  end

  private

  def send_message(params)
    content = params.is_a?(Array) ? params[0] : params
    return if content.blank?

    message_params = { content: content.to_s, private: false, message_type: :outgoing }
    Messages::MessageBuilder.new(nil, @conversation, message_params).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  def send_webhook_event(webhook_url)
    url = webhook_url.is_a?(Array) ? webhook_url[0] : webhook_url
    return if url.blank?

    payload = @conversation.webhook_data.merge(event: 'kanban.column_action')
    WebhookJob.perform_later(url, payload)
  end
end
