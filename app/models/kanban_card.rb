# == Schema Information
#
# Table name: kanban_cards
#
#  id                           :bigint           not null, primary key
#  archived_at                  :datetime
#  assignee_ids                 :integer          default([]), is an Array
#  auto_assignment_fell_through :boolean          default(FALSE), not null
#  custom_attributes            :jsonb            not null
#  description                  :text
#  due_date                     :datetime
#  last_moved_at                :datetime
#  lock_version                 :integer          default(0), not null
#  outcome                      :string
#  outcome_reason               :text
#  position                     :float            default(0.0), not null
#  priority                     :integer
#  reminder_at                  :datetime
#  task_status                  :string           default("open")
#  team_ids                     :integer          default([]), is an Array
#  title                        :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  assignee_id                  :bigint
#  conversation_id              :bigint
#  created_by_id                :bigint
#  kanban_board_id              :bigint           not null
#  kanban_column_id             :bigint           not null
#  team_id                      :bigint
#
# Indexes
#
#  idx_kanban_card_board_conversation                   (kanban_board_id,conversation_id) WHERE (conversation_id IS NOT NULL)
#  index_kanban_cards_on_account_id                     (account_id)
#  index_kanban_cards_on_archived_at                    (archived_at)
#  index_kanban_cards_on_assignee_id                    (assignee_id)
#  index_kanban_cards_on_conversation_id                (conversation_id)
#  index_kanban_cards_on_created_by_id                  (created_by_id)
#  index_kanban_cards_on_custom_attributes              (custom_attributes) USING gin
#  index_kanban_cards_on_kanban_board_id                (kanban_board_id)
#  index_kanban_cards_on_kanban_column_id               (kanban_column_id)
#  index_kanban_cards_on_kanban_column_id_and_position  (kanban_column_id,position)
#  index_kanban_cards_on_last_moved_at                  (last_moved_at)
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
  include PgSearch::Model

  audited only: %i[kanban_column_id assignee_id assignee_ids priority task_status outcome title]

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

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  pg_search_scope(
    :text_search,
    against: {
      title: 'A',
      description: 'B'
    },
    using: {
      tsearch: {
        prefix: true,
        normalization: 2
      }
    },
    ranked_by: ':tsearch'
  )

  validates :position, presence: true
  validate :title_or_conversation_required

  before_validation :set_denormalized_fields
  before_save :sync_primary_assignee
  before_save :sync_primary_team

  # Phase 3 KAN-09: archive/unarchive muda count da coluna → broadcast metrics.
  # Coberto por CardMoveService quando archive vem via move para won/lost; este callback
  # cobre archive standalone (ex: admin clica "archive" no UI direto, sem mover coluna).
  after_update_commit :dispatch_metrics_on_archive_change, if: :saved_change_to_archived_at?

  def archive!(outcome_value, reason = nil)
    update!(archived_at: Time.current, outcome: outcome_value, outcome_reason: reason)
  end

  # Phase 3 (KAN-07): KanbanCard pode ser primary_actor de notification_type='kanban_card_unassignable'.
  # Notification#push_event_data chama push_event_data no actor — exposiamos id + title minimos.
  def push_event_data
    { id: id, title: title }
  end

  def assignees
    User.where(id: assignee_ids || [])
  end

  def teams_list
    Team.where(id: team_ids || [])
  end

  private

  def dispatch_metrics_on_archive_change
    return unless kanban_column

    Kanban::ColumnMetricsService.new(kanban_column).dispatch_update
  end

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
