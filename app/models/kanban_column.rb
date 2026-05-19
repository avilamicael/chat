# == Schema Information
#
# Table name: kanban_columns
#
#  id                                  :bigint           not null, primary key
#  aging_danger_days                   :integer
#  aging_warn_days                     :integer
#  auto_assignment_enabled             :boolean          default(FALSE), not null
#  auto_assignment_max_cards_per_agent :integer
#  auto_assignment_online_only         :boolean          default(FALSE), not null
#  auto_assignment_override            :boolean          default(FALSE), not null
#  auto_assignment_reassign_on_return  :boolean          default(FALSE), not null
#  color                               :string           default("#6B7280")
#  column_type                         :string           default("normal"), not null
#  conversation_status                 :string
#  enter_actions                       :jsonb            not null
#  exit_actions                        :jsonb            not null
#  last_executed_at                    :datetime
#  last_execution_error                :text
#  last_execution_status               :string
#  name                                :string           not null
#  position                            :integer          default(0), not null
#  webhook_secret                      :string           not null
#  wip_limit                           :integer
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  account_id                          :bigint           not null
#  kanban_board_id                     :bigint           not null
#  last_assigned_agent_id              :integer
#
# Indexes
#
#  index_kanban_columns_on_account_id                    (account_id)
#  index_kanban_columns_on_column_type                   (column_type)
#  index_kanban_columns_on_kanban_board_id               (kanban_board_id)
#  index_kanban_columns_on_kanban_board_id_and_position  (kanban_board_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#
class KanbanColumn < ApplicationRecord
  belongs_to :kanban_board
  belongs_to :account
  has_many :kanban_cards, -> { order(:position) }, dependent: :destroy, inverse_of: :kanban_column

  # DEBT-03 / D9: secret per-column for HMAC webhook signing. Will be encrypted in Phase 5 (EXT-01).
  has_secure_token :webhook_secret

  enum column_type: { normal: 'normal', won: 'won', lost: 'lost' }, _prefix: :column
  enum last_execution_status: { ok: 'ok', error: 'error', pending: 'pending' }, _prefix: :execution

  CONVERSATION_STATUSES = %w[open pending resolved snoozed].freeze

  validates :name, presence: true
  validates :conversation_status, inclusion: { in: CONVERSATION_STATUSES }, allow_nil: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_account_from_board
  after_save :ensure_single_intake_column, if: :has_auto_create_task?

  # Phase 3 (KAN-07): KanbanColumn pode ser secondary_actor de notification_type='kanban_card_unassignable'.
  def push_event_data
    { id: id, name: name }
  end

  private

  def has_auto_create_task?
    enter_actions.any? { |a| a.is_a?(Hash) && a['action_name'] == 'auto_create_task' }
  end

  def ensure_single_intake_column
    kanban_board.kanban_columns.where.not(id: id).each do |col|
      next unless col.enter_actions.any? { |a| a.is_a?(Hash) && a['action_name'] == 'auto_create_task' }

      col.update_columns(enter_actions: col.enter_actions.reject { |a| a['action_name'] == 'auto_create_task' })
    end
  end

  def set_account_from_board
    self.account_id ||= kanban_board&.account_id
  end
end

KanbanColumn.prepend_mod_with('KanbanColumn')
