class Captain::UsageEvent < ApplicationRecord
  self.table_name = 'captain_usage_events'

  belongs_to :account, class_name: '::Account'
  belongs_to :assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :conversation, class_name: '::Conversation', optional: true

  validates :feature, presence: true
  validates :model, presence: true
end
