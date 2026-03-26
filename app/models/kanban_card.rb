# == Schema Information
#
# Table name: kanban_cards
#
#  id               :bigint           not null, primary key
#  assignee_ids     :integer          default([]), is an Array
#  description      :text
#  due_date         :datetime
#  position         :float            default(0.0), not null
#  priority         :integer
#  reminder_at      :datetime
#  task_status      :string           default("open")
#  team_ids         :integer          default([]), is an Array
#  title            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  assignee_id      :bigint
#  conversation_id  :bigint
#  created_by_id    :bigint
#  kanban_board_id  :bigint           not null
#  kanban_column_id :bigint           not null
#  team_id          :bigint
#
# Indexes
#
#  idx_unique_kanban_card_board_conversation            (kanban_board_id,conversation_id) UNIQUE WHERE (conversation_id IS NOT NULL)
#  index_kanban_cards_on_account_id                     (account_id)
#  index_kanban_cards_on_assignee_id                    (assignee_id)
#  index_kanban_cards_on_conversation_id                (conversation_id)
#  index_kanban_cards_on_created_by_id                  (created_by_id)
#  index_kanban_cards_on_kanban_board_id                (kanban_board_id)
#  index_kanban_cards_on_kanban_column_id               (kanban_column_id)
#  index_kanban_cards_on_kanban_column_id_and_position  (kanban_column_id,position)
#  index_kanban_cards_on_team_id                        (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => nullify
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (kanban_column_id => kanban_columns.id)
#  fk_rails_...  (team_id => teams.id)
#
class KanbanCard < ApplicationRecord
  belongs_to :kanban_column
  belongs_to :kanban_board
  belongs_to :account
  belongs_to :conversation, optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true

  has_many :kanban_card_conversations, dependent: :destroy
  has_many :linked_conversations, through: :kanban_card_conversations, source: :conversation

  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }

  validates :position, presence: true
  validates :conversation_id, uniqueness: { scope: :kanban_board_id }, allow_nil: true
  validate :title_or_conversation_required

  before_validation :set_denormalized_fields
  before_save :sync_primary_assignee
  before_save :sync_primary_team

  def assignees
    User.where(id: assignee_ids || [])
  end

  def teams_list
    Team.where(id: team_ids || [])
  end

  private

  def sync_primary_assignee
    self.assignee_id = (assignee_ids || []).first
  end

  def sync_primary_team
    self.team_id = (team_ids || []).first
  end

  def title_or_conversation_required
    return if title.present? || conversation_id.present?

    errors.add(:base, 'title or conversation is required')
  end

  def set_denormalized_fields
    self.account_id ||= kanban_board&.account_id
    self.kanban_board_id ||= kanban_column&.kanban_board_id
  end
end

KanbanCard.prepend_mod_with('KanbanCard')
