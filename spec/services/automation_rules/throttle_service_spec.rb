require 'rails_helper'

RSpec.describe AutomationRules::ThrottleService do
  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'baileys', sync_templates: false,
                              validate_provider_config: false)
  end
  let(:inbox) { channel.inbox }

  before do
    # flush bucket key entre exemplos (sliding window 1 min)
    bucket = Time.current.strftime('%Y%m%d%H%M')
    key = format(Redis::Alfred::AUTOMATION_THROTTLE_BUCKET, inbox_id: inbox.id, bucket: bucket)
    Redis::Alfred.delete(key)
  end

  describe '#acquire' do
    it 'returns :acquired when max_automation_messages_per_minute is NULL' do
      expect(described_class.new(inbox: inbox).acquire).to eq(:acquired)
    end

    it 'returns :acquired up to limit then Integer (seconds to retry) on overflow' do
      channel.update!(max_automation_messages_per_minute: 2)
      results = Array.new(3) { described_class.new(inbox: inbox).acquire }
      expect(results[0]).to eq(:acquired)
      expect(results[1]).to eq(:acquired)
      expect(results[2]).to be_a(Integer)
      expect(results[2]).to be_between(1, 60)
    end

    it 'rolls bucket key on minute change (limit=1 still allows new minute)' do
      channel.update!(max_automation_messages_per_minute: 1)
      travel_to(Time.zone.parse('2026-05-19 10:30:00'))
      expect(described_class.new(inbox: inbox).acquire).to eq(:acquired)
      travel_to(Time.zone.parse('2026-05-19 10:31:00'))
      expect(described_class.new(inbox: inbox).acquire).to eq(:acquired)
      travel_back
    end

    it 'returns :acquired for non-whatsapp inbox even with limit set' do
      non_wa_inbox = create(:inbox, account: account)
      allow(non_wa_inbox).to receive(:whatsapp?).and_return(false)
      expect(described_class.new(inbox: non_wa_inbox).acquire).to eq(:acquired)
    end

    it 'sets TTL on first increment (memory leak prevention)' do
      channel.update!(max_automation_messages_per_minute: 5)
      described_class.new(inbox: inbox).acquire
      bucket = Time.current.strftime('%Y%m%d%H%M')
      key = format(Redis::Alfred::AUTOMATION_THROTTLE_BUCKET, inbox_id: inbox.id, bucket: bucket)
      ttl = $alfred.with { |conn| conn.ttl(key) } # rubocop:disable Style/GlobalVars
      expect(ttl).to be > 0
      expect(ttl).to be <= 90
    end
  end
end
