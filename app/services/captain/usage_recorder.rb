class Captain::UsageRecorder
  # rubocop:disable Metrics/ParameterLists
  def self.record(account:, feature:, model:, input_tokens:, output_tokens:, assistant: nil, conversation: nil)
    # rubocop:enable Metrics/ParameterLists
    return if account.nil?

    cost_micros = Captain::UsageCostCalculator.cost_micros(model: model, input_tokens: input_tokens, output_tokens: output_tokens)

    Captain::UsageEvent.create!(
      account: account,
      assistant: assistant,
      conversation: conversation,
      feature: feature,
      model: model,
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      cost_micros: cost_micros
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    Rails.logger.warn "Failed to record Captain usage event: #{e.message}"
    nil
  end
end
