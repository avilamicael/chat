# == Schema Information
#
# Table name: captain_usage_events
#
#  id              :bigint           not null, primary key
#  cost_micros     :bigint           default(0), not null
#  feature         :string           not null
#  input_tokens    :integer          default(0), not null
#  model           :string           not null
#  output_tokens   :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  assistant_id    :bigint
#  conversation_id :bigint
#
# Indexes
#
#  index_captain_usage_events_on_account_id_and_created_at  (account_id,created_at)
#
class Captain::UsageEvent < ApplicationRecord
  self.table_name = 'captain_usage_events'

  belongs_to :account, class_name: '::Account'
  belongs_to :assistant, class_name: 'Captain::Assistant', optional: true
  belongs_to :conversation, class_name: '::Conversation', optional: true

  validates :feature, presence: true
  validates :model, presence: true
end
