class AutomationRuleRun < ApplicationRecord
  belongs_to :automation_rule
  belongs_to :account

  enum status: { ok: 0, error: 1, partial: 2, skipped: 3, aborted: 4, started: 5 }

  FAILED_ACTION_STATUSES = %w[error blocked_24h].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where.not(status: :ok) }
  scope :for_rule, ->(rule_id) { where(automation_rule_id: rule_id) }

  def push_action_log(index, action_name, **attrs)
    self.actions_log ||= []
    actions_log[index] = {
      'action_index' => index,
      'type' => action_name.to_s,
      'recorded_at' => Time.current.iso8601,
      **attrs.deep_stringify_keys
    }
    save!
  end

  def mark_last_action_status(status_value, **attrs)
    return if actions_log.blank?

    idx = actions_log.length - 1
    actions_log[idx] = (actions_log[idx] || {}).merge(
      'status' => status_value.to_s,
      **attrs.deep_stringify_keys
    )
    save!
  end

  # Calcula status agregado a partir de actions_log:
  # - todas as actions com status='ok'  → :ok
  # - todas as actions com status erro  → :error
  # - mistura                            → :partial
  def finalize!
    succeeded = actions_log.count { |e| e['status'] == 'ok' }
    failed = actions_log.count { |e| FAILED_ACTION_STATUSES.include?(e['status']) }
    new_status = if failed.zero? && succeeded == total_actions
                   :ok
                 elsif succeeded.zero? && failed.positive?
                   :error
                 else
                   :partial
                 end
    update!(status: new_status, succeeded_actions: succeeded, finished_at: Time.current)
  end
end
