class Captain::UsageRecorder
  # rubocop:disable Metrics/ParameterLists
  def self.record(account:, feature:, model:, input_tokens:, output_tokens:, assistant: nil, conversation: nil)
    # rubocop:enable Metrics/ParameterLists
    return if account.nil?

    cost_cents = Captain::UsageCostCalculator.cost_cents(model: model, input_tokens: input_tokens, output_tokens: output_tokens)

    Captain::UsageEvent.create!(
      account: account,
      assistant: assistant,
      conversation: conversation,
      feature: feature,
      model: model,
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      cost_cents: cost_cents
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    Rails.logger.warn "Failed to record Captain usage event: #{e.message}"
    nil
  end
end
