module Enterprise::Captain::ReplySuggestionService
  def make_api_call(model:, messages:, tools: [])
    return super unless use_search_tool?

    super(model: model, messages: messages, tools: [build_search_tool])
  end

  private

  def use_search_tool?
    return false unless ChatwootApp.chatwoot_cloud? || ChatwootApp.self_hosted_enterprise?

    assistant = conversation&.inbox&.captain_assistant
    responses = assistant.present? ? assistant.responses.approved : account.captain_assistant_responses.approved
    responses.exists?
  end

  def prompt_variables
    return super unless use_search_tool?

    super.merge('has_search_tool' => true)
  end

  def build_search_tool
    assistant = conversation&.inbox&.captain_assistant
    Captain::Tools::SearchReplyDocumentationService.new(account: account, assistant: assistant)
  end
end
