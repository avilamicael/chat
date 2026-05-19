# Phase 3 KAN-09: calcula count + tempo médio de dwell dos cards atualmente parados na coluna
# e dispatcha broadcast KANBAN_COLUMN_METRICS_UPDATED para o frontend re-renderizar o header.
#
# Filosofia: termômetro do momento (não histórico). AVG(NOW - last_moved_at) sobre cards
# ativos da coluna. Cards que saíram não entram no cálculo.
class Kanban::ColumnMetricsService
  def initialize(column)
    @column = column
  end

  def metrics
    # has_many :kanban_cards default order é :position; precisamos remover via reorder('')
    # antes da agregação para evitar PG::GroupingError no SELECT AVG(...).
    rel = @column.kanban_cards.reorder('').where(archived_at: nil)
    count = rel.count
    avg = rel.where.not(last_moved_at: nil)
             .pick(Arel.sql('AVG(EXTRACT(EPOCH FROM (NOW() - last_moved_at)))'))
    { count: count, avg_dwell_seconds: avg&.to_i }
  end

  def dispatch_update
    data = metrics.merge(
      board_id: @column.kanban_board_id,
      column_id: @column.id,
      account_id: @column.kanban_board.account_id
    )
    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_COLUMN_METRICS_UPDATED,
      Time.zone.now,
      **data
    )
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @column.kanban_board.account).capture_exception
  end
end
