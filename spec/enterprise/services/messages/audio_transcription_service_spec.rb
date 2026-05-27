require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }

  before do
    # Create required installation configs
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_API_KEY') { |config| config.value = 'test-api-key' }
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_MODEL') { |config| config.value = 'gpt-4o-mini' }

    # Mock usage limits for transcription to be available
    allow(account).to receive(:usage_limits).and_return({ captain: { responses: { current_available: 100 } } })
  end

  describe '#perform' do
    let(:service) { described_class.new(attachment) }

    context 'when captain_integration feature is not enabled' do
      before do
        account.disable_features!('captain_integration')
      end

      it 'returns transcription limit exceeded' do
        expect(service.perform).to eq({ error: 'Transcription limit exceeded' })
      end
    end

    context 'when transcription is successful' do
      before do
        # Mock can_transcribe? to return true and transcribe_audio method
        allow(service).to receive(:can_transcribe?).and_return(true)
        allow(service).to receive(:transcribe_audio).and_return('Hello world transcription')
      end

      it 'returns successful transcription' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Hello world transcription' })
      end
    end

    context 'when audio transcriptions are disabled' do
      before do
        account.update!(audio_transcriptions: false)
      end

      it 'returns error for transcription limit exceeded' do
        result = service.perform
        expect(result).to eq({ error: 'Transcription limit exceeded' })
      end
    end

    context 'when attachment already has transcribed text' do
      before do
        attachment.update!(meta: { transcribed_text: 'Existing transcription' })
        allow(service).to receive(:can_transcribe?).and_return(true)
      end

      it 'returns existing transcription without calling API' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Existing transcription' })
      end
    end
  end

  describe '#fetch_audio_file' do
    let(:service) { described_class.new(attachment) }

    before do
      attachment.file.attach(
        io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
        filename: 'speech',
        content_type: 'audio/mpeg'
      )
    end

    it 'adds extension from content type when filename has no extension' do
      temp_file_path = service.send(:fetch_audio_file)

      expect(File.extname(temp_file_path)).to eq('.mpeg')
    ensure
      FileUtils.rm_f(temp_file_path) if temp_file_path.present?
    end
  end

  describe '#update_transcription cost recording' do
    let(:service) { described_class.new(attachment) }

    before do
      allow(message).to receive(:reload).and_return(message)
      allow(message).to receive(:send_update_event)
      allow(message.account).to receive(:increment_response_usage)
      allow(ChatwootApp).to receive(:advanced_search_allowed?).and_return(false)
    end

    context 'when attachment meta carries duration_seconds' do
      before do
        attachment.update!(meta: { 'duration_seconds' => 120 })
      end

      it 'records exactly one audio_transcription usage event with units from meta' do
        expect do
          service.send(:update_transcription, 'transcribed text')
        end.to change(Captain::UsageEvent, :count).by(1)

        event = Captain::UsageEvent.last
        expect(event.feature).to eq('audio_transcription')
        expect(event.model).to eq(described_class::WHISPER_MODEL)
        expect(event.units).to eq(120)
        expect(event.cost_usd_micros).to be > 0
      end

      it 'still increments the response usage counter' do
        expect(message.account).to receive(:increment_response_usage)

        service.send(:update_transcription, 'transcribed text')
      end
    end

    context 'when duration_seconds is absent but the temp file is readable (ffprobe fallback)' do
      before do
        attachment.update!(meta: {})
        service.instance_variable_set(:@last_temp_path, '/tmp/audio-fallback.ogg')
        movie = instance_double(FFMPEG::Movie, duration: 60.0)
        allow(FFMPEG::Movie).to receive(:new).with('/tmp/audio-fallback.ogg').and_return(movie)
      end

      it 'records the usage event with units read from the file' do
        expect do
          service.send(:update_transcription, 'transcribed text')
        end.to change(Captain::UsageEvent, :count).by(1)

        expect(Captain::UsageEvent.last.units).to eq(60)
      end
    end

    context 'when duration cannot be determined (no meta and no fallback)' do
      before do
        attachment.update!(meta: {})
      end

      it 'does not create a usage event and does not raise' do
        expect do
          service.send(:update_transcription, 'transcribed text')
        end.not_to change(Captain::UsageEvent, :count)
      end
    end
  end
end
