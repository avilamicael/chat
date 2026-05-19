require 'rails_helper'

RSpec.describe Messages::Whatsapp24hGate do
  let(:account) { create(:account) }

  describe '.allowed?' do
    context 'when channel is Channel::Whatsapp' do
      let(:channel) { create(:channel_whatsapp, account: account, provider: 'baileys', sync_templates: false, validate_provider_config: false) }
      let(:inbox) { channel.inbox }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      it 'blocks when last_incoming_at > 24h ago' do
        create(:message, conversation: conversation, account: account, inbox: inbox,
                         message_type: :incoming, created_at: 25.hours.ago)
        expect(described_class.allowed?(conversation: conversation, action_params: {})).to eq(:blocked)
      end

      it 'allows when override toggle outside_24h_window_allowed is true' do
        create(:message, conversation: conversation, account: account, inbox: inbox,
                         message_type: :incoming, created_at: 25.hours.ago)
        expect(described_class.allowed?(conversation: conversation,
                                        action_params: { 'outside_24h_window_allowed' => true })).to eq(:allowed)
      end
    end

    context 'when channel is not Channel::Whatsapp' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      it 'returns :allowed for Email/Telegram/Web/Api regardless of last_incoming_at' do
        allow(inbox).to receive(:whatsapp?).and_return(false)
        allow(conversation).to receive(:inbox).and_return(inbox)
        expect(described_class.allowed?(conversation: conversation, action_params: {})).to eq(:allowed)
      end
    end

    context 'when channel is Twilio WhatsApp (out of scope Phase 3)' do
      let(:inbox) { create(:inbox, account: account) }
      let(:conversation) { create(:conversation, account: account, inbox: inbox) }

      it 'returns :allowed (Phase 3 only covers Channel::Whatsapp, not TwilioSms WA)' do
        allow(inbox).to receive(:whatsapp?).and_return(false)
        allow(inbox).to receive(:twilio_whatsapp?).and_return(true)
        allow(conversation).to receive(:inbox).and_return(inbox)
        expect(described_class.allowed?(conversation: conversation, action_params: {})).to eq(:allowed)
      end
    end
  end
end
