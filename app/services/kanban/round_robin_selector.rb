class Kanban::RoundRobinSelector
  pattr_initialize [:column!]

  # called on column delete or auto_assignment toggle
  def clear_queue
    ::Redis::Alfred.delete(round_robin_key)
  end

  def add_agent_to_queue(user_id)
    ::Redis::Alfred.lpush(round_robin_key, user_id)
  end

  def remove_agent_from_queue(user_id)
    ::Redis::Alfred.lrem(round_robin_key, user_id)
  end

  # team_member_ids: array of user ids that should populate the queue
  def reset_queue(team_member_ids:)
    clear_queue
    team_member_ids.each { |id| add_agent_to_queue(id) }
  end

  # allowed_agent_ids (string array): the filtered set this caller wants to rotate over.
  # Caller computes the filter (online / max_cards / team membership); selector just picks the
  # next agent atomically using pop+push semantics on Redis::Alfred.
  def available_agent(allowed_agent_ids:)
    team_ids = team_member_ids
    reset_queue(team_member_ids: team_ids) unless validate_queue?(team_ids)
    user_id = get_member_from_allowed_agent_ids(allowed_agent_ids)
    User.find_by(id: user_id) if user_id.present?
  end

  private

  def get_member_from_allowed_agent_ids(allowed_agent_ids)
    return nil if allowed_agent_ids.blank?

    user_id = queue.intersection(allowed_agent_ids).pop
    pop_push_to_queue(user_id)
    user_id
  end

  def pop_push_to_queue(user_id)
    return if user_id.blank?

    remove_agent_from_queue(user_id)
    add_agent_to_queue(user_id)
  end

  def validate_queue?(team_ids)
    team_ids.map(&:to_i).sort == queue.map(&:to_i).sort
  end

  def queue
    ::Redis::Alfred.lrange(round_robin_key)
  end

  # KanbanBoard nao possui associacao com Team (schema atual). Fallback: agentes da conta.
  # Se futura migracao adicionar team_id ao board, ajustar este helper para usar team.members.
  def team_member_ids
    column.kanban_board.account.users.joins(:account_users).where(account_users: { role: :agent }).pluck(:id)
  end

  def round_robin_key
    format(::Redis::Alfred::KANBAN_ROUND_ROBIN_AGENTS, column_id: column.id)
  end
end
