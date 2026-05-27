require 'rails_helper'

RSpec.describe Captain::UsageRecorder do
  let(:account) { create(:account) }

  describe '.record' do
    it 'records an OCR event with both USD and BRL cost using the token pipeline (SPEC req 3)' do
      expect do
        described_class.record(account: account, feature: 'ocr', model: 'gpt-4o-mini', input_tokens: 1000, output_tokens: 500)
      end.to change(Captain::UsageEvent, :count).by(1)

      event = Captain::UsageEvent.last
      expect(event.feature).to eq('ocr')
      expect(event.cost_usd_micros).to be > 0
      expect(event.cost_micros).to be > 0
    end

    it 'records an audio_transcription event priced per minute, persisting units (SPEC req 1)' do
      expect do
        described_class.record(account: account, feature: 'audio_transcription', model: 'whisper-1',
                               input_tokens: 0, output_tokens: 0, units: 120)
      end.to change(Captain::UsageEvent, :count).by(1)

      event = Captain::UsageEvent.last
      expect(event.units).to eq(120)
      expect(event.cost_usd_micros).to be > 0
    end

    it 'still records a legacy event without units: (no caller breakage)' do
      expect do
        described_class.record(account: account, feature: 'task', model: 'gpt-4o-mini', input_tokens: 1000, output_tokens: 500)
      end.to change(Captain::UsageEvent, :count).by(1)

      expect(Captain::UsageEvent.last.units).to be_nil
    end
  end
end
