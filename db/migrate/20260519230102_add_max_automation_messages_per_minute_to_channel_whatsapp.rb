class AddMaxAutomationMessagesPerMinuteToChannelWhatsapp < ActiveRecord::Migration[7.1]
  def change
    # IMPORTANTE: tabela é singular 'channel_whatsapp' (verified schema.rb:863)
    add_column :channel_whatsapp, :max_automation_messages_per_minute, :integer, null: true
  end
end
