class AutomationLoopAbortedNotificationBuilder
  pattr_initialize [:rule!, :account!, { chain: [] }]

  def perform
    account.administrators.find_each do |admin|
      admin.notifications.create!(
        notification_type: 'automation_rule_loop_aborted',
        account: account,
        primary_actor: rule,
        meta: { chain: chain }
      )
    end
  end
end
