class Kanban::CardCreationService
  def initialize(board, column, conversation: nil, **task_attrs)
    @board = board
    @column = column
    @conversation = conversation
    @task_attrs = task_attrs
  end

  def perform
    card = @board.kanban_cards.create!(
      kanban_column: @column,
      conversation: @conversation,
      account: @board.account,
      position: next_position,
      **permitted_task_attrs
    )

    if @conversation
      card.kanban_card_conversations.create!(conversation: @conversation)
    end

    card
  end

  private

  def permitted_task_attrs
    attrs = @task_attrs.slice(:title, :description, :priority, :task_status, :due_date, :reminder_at, :created_by_id)
    if @conversation && attrs[:title].blank?
      attrs[:title] = @conversation.contact.name
    end
    attrs
  end

  def next_position
    (@column.kanban_cards.maximum(:position) || 0.0) + 1.0
  end
end
