FactoryBot.define do
  factory :automation_rule_run do
    association :automation_rule
    association :account
    event_name { 'kanban_card_moved' }
    triggered_at { Time.current }
    status { :started }
    total_actions { 0 }
    succeeded_actions { 0 }
    actions_log { [] }
  end
end
