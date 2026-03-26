# == Schema Information
#
# Table name: kanban_boards
#
#  id          :bigint           not null, primary key
#  description :text
#  filters     :jsonb            not null
#  is_default  :boolean          default(FALSE), not null
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_kanban_boards_on_account_id                 (account_id)
#  index_kanban_boards_on_account_id_and_is_default  (account_id,is_default)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class KanbanBoard < ApplicationRecord
  belongs_to :account
  has_many :kanban_columns, -> { order(:position) }, dependent: :destroy, inverse_of: :kanban_board
  has_many :kanban_cards, dependent: :destroy

  validates :name, presence: true
  validates :account_id, presence: true

  scope :default_board, -> { where(is_default: true) }

  validate :no_overlapping_default_inbox, if: :is_default?
  before_save :ensure_single_default, if: :is_default_changed?

  private

  def no_overlapping_default_inbox
    inbox_ids = (filters&.dig('inbox_ids') || filters&.dig(:inbox_ids) || []).map(&:to_i).reject(&:zero?)
    return if inbox_ids.empty?

    conflict = account.kanban_boards.where(is_default: true).where.not(id: id || 0).any? do |b|
      (b.filters&.dig('inbox_ids') || b.filters&.dig(:inbox_ids) || []).map(&:to_i).intersect?(inbox_ids)
    end

    errors.add(:base, 'Another default funnel already includes one of the selected inboxes') if conflict
  end

  def ensure_single_default
    return unless is_default

    account.kanban_boards.where(is_default: true).where.not(id: id).update_all(is_default: false)
  end
end

KanbanBoard.prepend_mod_with('KanbanBoard')
