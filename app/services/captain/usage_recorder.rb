class Captain::UsageRecorder
  # Single write point for Captain AI usage cost events.
  # feature: 'audio_transcription' (Whisper) is priced per minute via the units: (seconds) argument.
  # feature: 'ocr'/'vision' (gpt-4o-mini vision) is the integration point for the future OCR service —
  # the OCR pipeline is NOT built here; it just reuses the token-based cost path (SPEC req 3).
  # rubocop:disable Metrics/ParameterLists
  def self.record(account:, feature:, model:, input_tokens:, output_tokens:, units: nil, assistant: nil, conversation: nil)
    # rubocop:enable Metrics/ParameterLists
    return if account.nil?

    cost_usd_micros = usd_micros_for(feature: feature, model: model, input_tokens: input_tokens, output_tokens: output_tokens, units: units)
    cost_micros = Captain::UsageCostCalculator.brl_micros_from_usd(cost_usd_micros: cost_usd_micros)

    Captain::UsageEvent.create!(
      account: account,
      assistant: assistant,
      conversation: conversation,
      feature: feature,
      model: model,
      input_tokens: input_tokens.to_i,
      output_tokens: output_tokens.to_i,
      cost_micros: cost_micros,
      cost_usd_micros: cost_usd_micros,
      units: units
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
    Rails.logger.warn "Failed to record Captain usage event: #{e.message}"
    nil
  end

  def self.usd_micros_for(feature:, model:, input_tokens:, output_tokens:, units:)
    if feature == 'audio_transcription' && units.present?
      Captain::UsageCostCalculator.audio_cost_usd_micros(seconds: units)
    else
      Captain::UsageCostCalculator.cost_usd_micros(model: model, input_tokens: input_tokens, output_tokens: output_tokens)
    end
  end
end
