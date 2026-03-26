# == Schema Information
#
# Table name: kanban_card_conversations
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  kanban_card_id  :bigint           not null
#
# Indexes
#
#  idx_unique_kanban_card_conversation                 (kanban_card_id,conversation_id) UNIQUE
#  index_kanban_card_conversations_on_conversation_id  (conversation_id)
#  index_kanban_card_conversations_on_kanban_card_id   (kanban_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (kanban_card_id => kanban_cards.id)
#
class KanbanCardConversation < ApplicationRecord
  belongs_to :kanban_card
  belongs_to :conversation

  validates :conversation_id, uniqueness: { scope: :kanban_card_id }
end
