# == Schema Information
#
# Table name: kanban_columns
#
#  id              :bigint           not null, primary key
#  color           :string           default("#6B7280")
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

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :set_account_from_board

  private

  def set_account_from_board
    self.account_id ||= kanban_board&.account_id
  end
end

KanbanColumn.prepend_mod_with('KanbanColumn')
