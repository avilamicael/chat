# == Schema Information
#
# Table name: kanban_columns
#
#  id              :bigint           not null, primary key
#  color           :string           default("#6B7280")
#  column_type     :string           default("normal"), not null
#  enter_actions   :jsonb            not null
#  exit_actions    :jsonb            not null
#  name            :string           not null
#  position        :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  kanban_board_id :bigint           not null
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

  enum column_type: { normal: 'normal', won: 'won', lost: 'lost' }, _prefix: :column

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_account_from_board
  after_save :ensure_single_intake_column, if: :has_auto_create_task?

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
