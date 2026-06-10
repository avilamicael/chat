FactoryBot.define do
  factory :kanban_board do
    sequence(:name) { |n| "Board #{n}" }
    description { 'Test funnel' }
    account

    trait :default do
      is_default { true }
    end
  end

  factory :kanban_column do
    sequence(:name) { |n| "Column #{n}" }
    position { 0 }
    color { '#6B7280' }
    kanban_board
    account { kanban_board&.account }
  end

  factory :kanban_card do
    sequence(:title) { |n| "Card #{n}" }
    position { 0.0 }
    kanban_board
    kanban_column { association :kanban_column, kanban_board: kanban_board }
    account { kanban_board&.account }

    trait :archived do
      archived_at { Time.current }
      outcome { 'won' }
    end
  end
end
