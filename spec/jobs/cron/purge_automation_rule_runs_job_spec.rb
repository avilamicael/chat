require 'rails_helper'

RSpec.describe Cron::PurgeAutomationRuleRunsJob do
  let(:account) { create(:account) }
  let(:rule) { create(:automation_rule, account: account) }

  it 'deletes runs older than RETENTION_DAYS (30) and keeps newer rows' do
    old_run = create(:automation_rule_run, automation_rule: rule, account: account, created_at: 45.days.ago)
    recent_run = create(:automation_rule_run, automation_rule: rule, account: account, created_at: 29.days.ago)
    today_run = create(:automation_rule_run, automation_rule: rule, account: account)

    described_class.new.perform

    expect(AutomationRuleRun.exists?(old_run.id)).to be false
    expect(AutomationRuleRun.exists?(recent_run.id)).to be true
    expect(AutomationRuleRun.exists?(today_run.id)).to be true
  end
end
