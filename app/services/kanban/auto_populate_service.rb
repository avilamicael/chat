class Kanban::AutoPopulateService
  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def perform
    default_board = @account.kanban_boards.default_board.first
    return unless default_board
    return if already_on_board?(default_board)
    return unless matches_board_filters?(default_board)

    first_column = find_target_column(default_board)
    return unless first_column

    card = Kanban::CardCreationService.new(default_board, first_column, conversation: @conversation).perform

    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_ADDED,
      Time.zone.now,
      card: card,
      board: default_board
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  private

  def find_target_column(board)
    intake_id = board.filters&.dig('intake_column_id')
    if intake_id.present?
      col = board.kanban_columns.find_by(id: intake_id)
      return col if col
    end
    board.kanban_columns.order(:position).find do |col|
      col.enter_actions.any? { |a| a.is_a?(Hash) && a['action_name'] == 'auto_create_task' }
    end || board.kanban_columns.order(:position).first
  end

  def already_on_board?(board)
    board.kanban_cards.exists?(conversation_id: @conversation.id)
  end

  def matches_board_filters?(board)
    filters = board.filters.with_indifferent_access
    return true if filters.blank?

    inbox_match = filters[:inbox_ids].blank? || filters[:inbox_ids].map(&:to_i).include?(@conversation.inbox_id)
    team_match = filters[:team_ids].blank? || filters[:team_ids].map(&:to_i).include?(@conversation.team_id)

    inbox_match && team_match
  end
end
