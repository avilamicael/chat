class Api::V1::Accounts::KanbanBoardsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_board, only: [:update, :destroy]

  def index
    @boards = Current.account.kanban_boards.includes(kanban_columns: :kanban_cards)
  end

  def show
    @board = Current.account.kanban_boards.includes(:kanban_columns).find(params[:id])
  end

  def create
    @board = Current.account.kanban_boards.create!(board_params)
    Kanban::BoardTemplateService.new(board: @board, template: params[:template].to_s, locale: I18n.locale.to_s).perform
    @board.kanban_columns.reload
  end

  def update
    @board.update!(board_params)
    Rails.configuration.dispatcher.dispatch(Events::Types::KANBAN_BOARD_UPDATED, Time.zone.now, board: @board)
  end

  def destroy
    @board.destroy!
    head :ok
  end

  def conversation_card
    conversation = Current.account.conversations.find_by(id: params[:conversation_id])
    return render json: { payload: nil } unless conversation

    card = KanbanCard
      .joins(kanban_column: :kanban_board)
      .where(kanban_boards: { account_id: Current.account.id })
      .where(conversation_id: conversation.id)
      .includes(kanban_column: :kanban_board)
      .first

    if card
      board = card.kanban_column.kanban_board
      columns = board.kanban_columns.order(:position).map { |c| { id: c.id, name: c.name } }
      render json: { payload: {
        card_id: card.id,
        board_id: board.id,
        board_name: board.name,
        column_id: card.kanban_column_id,
        column_name: card.kanban_column.name,
        columns: columns
      }}
    else
      render json: { payload: nil }
    end
  end

  private

  def set_board
    @board = Current.account.kanban_boards.find(params[:id])
  end

  def board_params
    params.require(:kanban_board).permit(
      :name, :description, :is_default,
      filters: [:intake_column_id, { agent_ids: [], inbox_ids: [], team_ids: [] }]
    )
  end
end
