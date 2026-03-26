class Api::V1::Accounts::KanbanBoards::ColumnsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(KanbanColumn) }
  before_action :set_board
  before_action :set_column, only: [:update, :destroy]

  def index
    @columns = @board.kanban_columns.includes(:kanban_cards).order(:position)
  end

  def create
    @column = @board.kanban_columns.create!(column_params)
  end

  def update
    @column.update!(column_params)
  end

  def destroy
    @column.destroy!
    head :ok
  end

  def reorder
    params[:columns].each do |col|
      @board.kanban_columns.find(col[:id]).update!(position: col[:position])
    end
    @columns = @board.kanban_columns.order(:position)
    render :index
  end

  private

  def set_board
    @board = Current.account.kanban_boards.find(params[:kanban_board_id])
  end

  def set_column
    @column = @board.kanban_columns.find(params[:id])
  end

  def column_params
    params.require(:kanban_column).permit(
      :name, :position, :color, :column_type,
      enter_actions: [:action_name, :url, :agent_id, :team_id],
      exit_actions: [:action_name, :url]
    )
  end
end
