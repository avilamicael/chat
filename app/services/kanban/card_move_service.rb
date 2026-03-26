class Kanban::CardMoveService
  def initialize(card, params, user = nil)
    @card = card
    @target_column_id = params[:column_id].to_i
    @new_position = params[:position].to_f
    @user = user
    @source_column = card.kanban_column
  end

  def perform
    @target_column = @card.kanban_board.kanban_columns.find(@target_column_id)
    column_changed = @source_column.id != @target_column.id

    @card.update!(
      kanban_column_id: @target_column.id,
      position: @new_position
    )

    if column_changed
      run_column_actions(@source_column.exit_actions)
      run_column_actions(@target_column.enter_actions)
    end

    dispatch_card_moved(column_changed)

    @card
  end

  private

  def run_column_actions(actions)
    return if actions.blank?

    Kanban::ColumnActionService.new(@card.conversation, actions, @card.account).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @card.account).capture_exception
  end

  def dispatch_card_moved(column_changed)
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_MOVED,
      Time.zone.now,
      card: @card,
      board: @card.kanban_board,
      source_column_id: @source_column.id,
      target_column_id: @target_column.id,
      column_changed: column_changed,
      performed_by: @user
    )
  end
end
