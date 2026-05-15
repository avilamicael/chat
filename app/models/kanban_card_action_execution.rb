class KanbanCardActionExecution < ApplicationRecord
  belongs_to :card, class_name: 'KanbanCard'
  belongs_to :column, class_name: 'KanbanColumn'

  # DEBT-02: status tracks idempotent execution state per (card, action, trigger_event)
  enum status: { pending: 'pending', ok: 'ok', error: 'error' }, _prefix: :status
  enum direction: { enter_actions: 'enter_actions', exit_actions: 'exit_actions' }, _prefix: :direction
end
