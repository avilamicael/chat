class Notifications::KanbanCardUnassignableBuilder
  pattr_initialize [:card!, :column!]

  def perform
    account = card.kanban_board.account
    account.administrators.find_each do |admin|
      admin.notifications.create!(
        notification_type: 'kanban_card_unassignable',
        account: account,
        primary_actor: card,
        secondary_actor: column,
        meta: { column_name: column.name }
      )
    end
  end
end
