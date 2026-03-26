class Api::V1::Accounts::KanbanBoards::CardsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(KanbanCard) }
  before_action :set_board
  before_action :set_card, only: [:destroy, :move, :update]

  def index
    @cards = @board.kanban_cards.includes(
      :kanban_card_conversations,
      :assignee,
      conversation: [:assignee, :inbox, :contact]
    )
    @cards = @cards.where(kanban_column_id: params[:column_id]) if params[:column_id].present?
  end

  def create
    column = @board.kanban_columns.find(params.dig(:kanban_card, :column_id))

    if params.dig(:kanban_card, :conversation_id).present?
      conversation = Current.account.conversations.find(params.dig(:kanban_card, :conversation_id))
      @card = Kanban::CardCreationService.new(
        @board, column,
        conversation: conversation,
        created_by_id: current_user.id
      ).perform
    else
      @card = Kanban::CardCreationService.new(
        @board, column,
        created_by_id: current_user.id,
        **task_create_params
      ).perform
    end

    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_ADDED,
      Time.zone.now,
      card: @card,
      board: @board
    )
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    source_column_id = @card.kanban_column_id
    @card.update!(task_update_params)

    if @card.kanban_column_id != source_column_id
      Rails.configuration.dispatcher.dispatch(
        Events::Types::KANBAN_CARD_MOVED,
        Time.zone.now,
        card: @card,
        board: @board,
        source_column_id: source_column_id,
        target_column_id: @card.kanban_column_id,
        column_changed: true
      )
    end

    render :show
  end

  def destroy
    @card.destroy!
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_REMOVED,
      Time.zone.now,
      card: @card,
      board: @board
    )
    head :ok
  end

  def move
    @card = Kanban::CardMoveService.new(@card, move_params, current_user).perform
  end

  private

  def set_board
    @board = Current.account.kanban_boards.find(params[:kanban_board_id])
  end

  def set_card
    @card = @board.kanban_cards.includes(conversation: [:assignee, :inbox, :contact]).find(params[:id])
  end

  def task_create_params
    params.require(:kanban_card).permit(:title, :description, :priority, :task_status, :due_date, :reminder_at, assignee_ids: [], team_ids: [])
          .to_h.symbolize_keys
  end

  def task_update_params
    params.require(:kanban_card).permit(:title, :description, :priority, :task_status, :due_date, :reminder_at, :kanban_column_id, assignee_ids: [], team_ids: [])
  end

  def move_params
    params.require(:kanban_card).permit(:column_id, :position)
  end
end
