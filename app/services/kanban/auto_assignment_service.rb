class Kanban::AutoAssignmentService
  def initialize(card:, column:, trigger:)
    @card = card
    @column = column
    @trigger = trigger # :card_added | :card_moved | :agent_returned
  end

  def perform
    return unless @column.auto_assignment_enabled
    return if skip_for_existing_assignee?

    agent = pick_next_eligible_agent
    if agent
      assign_to(agent)
    else
      handle_fallback
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @column.kanban_board.account).capture_exception
  end

  private

  def skip_for_existing_assignee?
    return false if @column.auto_assignment_override

    @card.assignee_ids.present?
  end

  def pick_next_eligible_agent
    allowed_ids = eligible_agent_ids
    return nil if allowed_ids.blank?

    ::Kanban::RoundRobinSelector.new(column: @column).available_agent(allowed_agent_ids: allowed_ids.map(&:to_s))
  end

  def eligible_agent_ids
    ids = team_member_ids
    ids &= online_user_ids if @column.auto_assignment_online_only
    ids = ids.reject { |id| overloaded?(id) } if @column.auto_assignment_max_cards_per_agent.present?
    ids
  end

  def team_member_ids
    # KanbanBoard nao possui team_id; fallback: todos os agentes da conta.
    @column.kanban_board.account.users.joins(:account_users).where(account_users: { role: :agent }).pluck(:id)
  end

  def online_user_ids
    tracker = OnlineStatusTracker.get_available_users(@column.kanban_board.account_id) || {}
    tracker.select { |_id, status| status == 'online' }.keys.map(&:to_i)
  end

  def overloaded?(user_id)
    max = @column.auto_assignment_max_cards_per_agent
    current = @column.kanban_cards
                     .where(archived_at: nil)
                     .where('assignee_ids @> ARRAY[?]::integer[]', user_id)
                     .count
    current >= max
  end

  def assign_to(agent)
    @card.update!(assignee_ids: [agent.id])
    @card.update_columns(auto_assignment_fell_through: false) if @card.auto_assignment_fell_through # rubocop:disable Rails/SkipsModelValidations
    @column.update_columns(last_assigned_agent_id: agent.id) # rubocop:disable Rails/SkipsModelValidations
  end

  def handle_fallback
    @card.update_columns(auto_assignment_fell_through: true) # rubocop:disable Rails/SkipsModelValidations
    Notifications::KanbanCardUnassignableBuilder.new(card: @card, column: @column).perform
  end
end
