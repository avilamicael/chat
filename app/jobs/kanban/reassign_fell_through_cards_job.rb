class Kanban::ReassignFellThroughCardsJob < ApplicationJob
  queue_as :default

  # Re-scans Kanban cards that fell through (auto_assignment_fell_through=true) in columns
  # with auto_assignment_reassign_on_return=true, in accounts where the user is an agent.
  # Triggers AutoAssignmentService for each candidate with trigger: :agent_returned.
  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil?

    candidate_cards(user).find_each do |card|
      column = card.kanban_column
      next unless column&.auto_assignment_enabled && column.auto_assignment_reassign_on_return

      Kanban::AutoAssignmentService.new(card: card, column: column, trigger: :agent_returned).perform
    end
  end

  private

  def candidate_cards(user)
    # KanbanBoard nao tem team_id (schema atual). Scope: contas onde user eh agente.
    account_ids = user.account_users.where(role: :agent).pluck(:account_id)
    return KanbanCard.none if account_ids.empty?

    KanbanCard
      .joins(:kanban_column)
      .where(auto_assignment_fell_through: true, archived_at: nil, account_id: account_ids)
      .where(kanban_columns: { auto_assignment_enabled: true, auto_assignment_reassign_on_return: true })
  end
end
