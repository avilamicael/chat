# Helper de tradução entre display name (UI) e class name (coluna inboxes.channel_type).
# Backend armazena 'Channel::Whatsapp'/'Channel::Email'/etc; UI usa nomes amigáveis.
# Phase 2 — D-B4 do CONTEXT.
module Channel::TypeNormalizer
  MAPPING = {
    'whatsapp' => 'Channel::Whatsapp',
    'email' => 'Channel::Email',
    'api' => 'Channel::Api',
    'telegram' => 'Channel::Telegram',
    'facebook' => 'Channel::FacebookPage',
    'instagram' => 'Channel::Instagram',
    'line' => 'Channel::Line',
    'sms' => 'Channel::Sms',
    'twilio_sms' => 'Channel::TwilioSms',
    'twitter' => 'Channel::TwitterProfile',
    'web_widget' => 'Channel::WebWidget',
    'tiktok' => 'Channel::Tiktok'
  }.freeze

  INVERTED_MAPPING = MAPPING.invert.freeze

  def self.normalize(display_name)
    MAPPING[display_name.to_s]
  end

  def self.denormalize(class_name)
    INVERTED_MAPPING[class_name.to_s]
  end
end
