# == Schema Information
#
# Table name: kanban_card_action_executions
#
#  id               :bigint           not null, primary key
#  direction        :string           not null
#  executed_at      :datetime
#  last_error       :text
#  status           :string           default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  action_id        :string(64)       not null
#  card_id          :bigint           not null
#  column_id        :bigint           not null
#  trigger_event_id :string(36)       not null
#
# Indexes
#
#  idx_card_action_executions_column_executed  (column_id,executed_at)
#  idx_unique_card_action_execution            (card_id,action_id,trigger_event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (card_id => kanban_cards.id) ON DELETE => cascade
#  fk_rails_...  (column_id => kanban_columns.id) ON DELETE => cascade
#
class KanbanCardActionExecution < ApplicationRecord
  belongs_to :card, class_name: 'KanbanCard'
  belongs_to :column, class_name: 'KanbanColumn'

  # DEBT-02: status tracks idempotent execution state per (card, action, trigger_event)
  enum status: { pending: 'pending', ok: 'ok', error: 'error' }, _prefix: :status
  enum direction: { enter_actions: 'enter_actions', exit_actions: 'exit_actions' }, _prefix: :direction
end
