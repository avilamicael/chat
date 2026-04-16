class Api::V1::Accounts::KanbanBoards::CardsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(KanbanCard) }
  before_action :set_board
  before_action :set_card, only: [:destroy, :move, :update, :activities, :link_conversation, :unlink_conversation]
  around_action :audit_as_current_user, only: [:create, :update, :move, :destroy, :link_conversation, :unlink_conversation]

  def index
    @cards = @board.kanban_cards.active.includes(
      :kanban_card_conversations,
      :assignee,
      conversation: [:assignee, :inbox, :contact]
    )
    @cards = @cards.where(kanban_column_id: params[:column_id]) if params[:column_id].present?
  end

  def archived
    @cards = @board.kanban_cards
                   .archived
                   .includes(:kanban_card_conversations, :assignee, conversation: [:assignee, :inbox, :contact])
                   .order(archived_at: :desc)
    @cards = @cards.where(outcome: params[:outcome]) if params[:outcome].present?
    page = (params[:page] || 1).to_i
    @cards = @cards.offset((page - 1) * 50).limit(50)
    render :index
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
    reload_card_with_associations

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

  def activities
    @activities = Audited.audit_class
                         .where(auditable_type: 'KanbanCard', auditable_id: @card.id)
                         .includes(:user)
                         .order(created_at: :desc)
                         .limit(50)
  end

  def link_conversation
    conversation = Current.account.conversations.find(params.require(:conversation_id))

    if @card.conversation_id.blank?
      @card.update!(conversation_id: conversation.id)
    else
      @card.kanban_card_conversations.find_or_create_by!(conversation_id: conversation.id)
    end

    reload_card_with_associations
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def unlink_conversation
    conversation_id = params.require(:conversation_id).to_i

    if @card.conversation_id == conversation_id
      @card.update!(conversation_id: nil)
    else
      @card.kanban_card_conversations.where(conversation_id: conversation_id).destroy_all
    end

    reload_card_with_associations
    render :show
  end

  private

  def reload_card_with_associations
    @card = @board.kanban_cards
                  .includes(
                    conversation: [:assignee, :inbox, :contact],
                    kanban_card_conversations: { conversation: [:inbox, :contact] }
                  )
                  .find(@card.id)
  end


  def audit_as_current_user(&block)
    Audited.audit_class.as_user(current_user, &block)
  end

  def set_board
    @board = Current.account.kanban_boards.find(params[:kanban_board_id])
  end

  def set_card
    @card = @board.kanban_cards
                  .includes(
                    conversation: [:assignee, :inbox, :contact],
                    kanban_card_conversations: { conversation: [:inbox, :contact] }
                  )
                  .find(params[:id])
  end

  def task_create_params
    params.require(:kanban_card).permit(:title, :description, :priority, :task_status, :due_date, :reminder_at, assignee_ids: [], team_ids: [])
          .to_h.symbolize_keys
  end

  def task_update_params
    permitted = params.require(:kanban_card).permit(
      :title, :description, :priority, :task_status, :due_date, :reminder_at,
      :kanban_column_id, :conversation_id, assignee_ids: [], team_ids: []
    )
    if permitted.key?(:conversation_id) && permitted[:conversation_id].present?
      Current.account.conversations.find(permitted[:conversation_id])
    end
    permitted
  end

  def move_params
    params.require(:kanban_card).permit(:column_id, :position, :outcome_reason)
  end
end
