class KanbanListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    return unless conversation

    Kanban::AutoPopulateService.new(conversation).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
  end

  def conversation_status_changed(event)
    conversation = event.data[:conversation]
    return unless conversation

    cards = KanbanCard.where(conversation_id: conversation.id)
    return if cards.empty?

    status_map = { 'open' => 'open', 'resolved' => 'resolved', 'pending' => 'pending', 'snoozed' => 'snoozed' }
    new_status = status_map[conversation.status]
    return unless new_status

    cards.each do |card|
      board = card.kanban_board
      status_changed = card.task_status != new_status

      if status_changed
        card.update_columns(task_status: new_status, updated_at: Time.zone.now)
      end

      target_column = board.kanban_columns.find_by(conversation_status: new_status)
      if target_column && target_column.id != card.kanban_column_id
        max_position = board.kanban_cards.where(kanban_column_id: target_column.id).maximum(:position) || 0
        Kanban::CardMoveService.new(card, { column_id: target_column.id, position: max_position + 1 }).perform
        next
      end

      next unless status_changed

      broadcast(board.account, [account_token(board.account)], 'kanban.card_updated', {
        card: card_payload(card),
        board_id: board.id
      })
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation&.account).capture_exception
  end

  def message_created(event)
    message = event.data[:message]
    return unless message&.incoming? || (message&.outgoing? && !message.private?)

    conversation = message.conversation
    return unless conversation

    cards = KanbanCard.where(conversation_id: conversation.id)
    return if cards.empty?

    cards.each do |card|
      board = card.kanban_board
      card = KanbanCard.includes(conversation: [:contact, :inbox, :assignee], assignee: []).find(card.id)
      broadcast(board.account, [account_token(board.account)], 'kanban.card_updated', {
        card: card_payload(card),
        board_id: board.id
      })
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message&.account).capture_exception
  end

  def kanban_card_added(event)
    card = event.data[:card]
    board = event.data[:board]
    return unless card && board

    if card.kanban_column
      Kanban::ColumnActionsService.new(card, card.kanban_column, :enter_actions).perform
    end

    card = KanbanCard.includes(conversation: [:contact, :inbox, :assignee], assignee: []).find(card.id)

    broadcast(board.account, [account_token(board.account)], 'kanban.card_added', {
      card: card_payload(card),
      board_id: board.id
    })
  end

  def kanban_card_moved(event)
    card = event.data[:card]
    board = event.data[:board]
    return unless card && board

    if event.data[:column_changed] && event.data[:source_column_id]
      source_column = board.kanban_columns.find_by(id: event.data[:source_column_id])
      Kanban::ColumnActionsService.new(card, source_column, :exit_actions).perform if source_column
    end

    if event.data[:column_changed] && card.kanban_column
      Kanban::ColumnActionsService.new(card, card.kanban_column, :enter_actions).perform
    end

    card = KanbanCard.includes(conversation: [:contact, :inbox, :assignee], assignee: []).find(card.id)

    broadcast(board.account, [account_token(board.account)], 'kanban.card_moved', {
      card: card_payload(card),
      board_id: board.id,
      source_column_id: event.data[:source_column_id],
      target_column_id: event.data[:target_column_id],
      column_changed: event.data[:column_changed]
    })
  end

  def kanban_card_removed(event)
    card = event.data[:card]
    board = event.data[:board]
    return unless card && board

    broadcast(board.account, [account_token(board.account)], 'kanban.card_removed', {
      card_id: card.id,
      board_id: board.id
    })
  end

  def kanban_board_updated(event)
    board = event.data[:board]
    return unless board

    broadcast(board.account, [account_token(board.account)], 'kanban.board_updated', {
      board_id: board.id
    })
  end

  private

  def account_token(account)
    "account_#{account.id}"
  end

  def card_payload(card)
    payload = {
      id: card.id,
      position: card.position,
      kanban_column_id: card.kanban_column_id,
      kanban_board_id: card.kanban_board_id,
      conversation_id: card.conversation_id,
      title: card.title,
      description: card.description,
      priority: card.priority,
      task_status: card.task_status,
      due_date: card.due_date,
      assignee_id: card.assignee_id,
      assignee_ids: card.respond_to?(:assignee_ids) ? (card.assignee_ids || []) : [],
      team_id: card.respond_to?(:team_id) ? card.team_id : nil,
      team_ids: card.respond_to?(:team_ids) ? (card.team_ids || []) : [],
      created_at: card.created_at
    }

    if card.association(:assignee).loaded? && card.assignee
      payload[:assignee] = { id: card.assignee.id, name: card.assignee.name, thumbnail: card.assignee.avatar_url }
    end

    conv = card.association(:conversation).loaded? ? card.conversation : nil
    if conv
      payload[:conversation] = {
        id: conv.id,
        display_id: conv.display_id,
        status: conv.status,
        created_at: conv.created_at,
        channel: conv.inbox&.channel_type,
        waiting_since: conv.waiting_since,
        meta: {
          sender: conv.contact ? { id: conv.contact.id, name: conv.contact.name, thumbnail: conv.contact.avatar_url } : nil,
          assignee: conv.assignee ? { id: conv.assignee.id, name: conv.assignee.name, thumbnail: conv.assignee.avatar_url } : nil
        }
      }
    end

    payload
  end

  def broadcast(account, tokens, event_name, data)
    return if tokens.blank?

    payload = data.merge(account_id: account.id)
    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, payload)
  end
end
