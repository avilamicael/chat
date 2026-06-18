class Kanban::AutoPopulateService
  def initialize(conversation)
    @conversation = conversation
    @account = conversation.account
  end

  def perform
    default_board = @account.kanban_boards.default_board.first
    return unless default_board
    return unless matches_board_filters?(default_board)

    create_card_with_lock(default_board)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  private

  # Serializa criacao por conversation_id (namespace 2; namespace 1 reservado a
  # CardMoveService por card.id) + re-check do dedup ativo SOB o lock para impedir
  # double-create em 2 eventos async concorrentes no mesmo reopen.
  def create_card_with_lock(board)
    card = nil

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_xact_lock(2, #{@conversation.id.to_i})")
      next if already_on_board?(board)

      first_column = find_target_column(board)
      next unless first_column

      card = Kanban::CardCreationService.new(board, first_column, conversation: @conversation).perform
    end

    return unless card

    # Dispatch SO depois do commit: o KanbanListener#kanban_card_added roda async
    # (Sidekiq) e faz KanbanCard.find — se disparado dentro da transacao, o worker
    # pode rodar antes do commit, find levanta RecordNotFound e o broadcast
    # `kanban.card_added` nunca chega na tela (card so aparece apos refresh).
    # INVARIANTE: este service NAO pode ser chamado dentro de uma transacao externa
    # (a `transaction do` acima viraria savepoint e o dispatch ocorreria pre-commit,
    # reintroduzindo a corrida). Hoje so e chamado de listeners async sem transacao.
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_CARD_ADDED,
      Time.zone.now,
      card: card,
      board: board
    )
  end

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
    board.kanban_cards.active.exists?(conversation_id: @conversation.id)
  end

  def matches_board_filters?(board)
    filters = board.filters.with_indifferent_access
    return true if filters.blank?

    inbox_match = filters[:inbox_ids].blank? || filters[:inbox_ids].map(&:to_i).include?(@conversation.inbox_id)
    team_match = filters[:team_ids].blank? || filters[:team_ids].map(&:to_i).include?(@conversation.team_id)

    inbox_match && team_match
  end
end
