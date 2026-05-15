class Kanban::CardMoveService
  def initialize(card, params, user = nil)
    @card = card
    @target_column_id = params[:column_id].to_i
    @new_position = params[:position].to_f
    @outcome_reason = params[:outcome_reason]
    @user = user
    @source_column = card.kanban_column
    @trigger_event_id = SecureRandom.uuid
  end

  def perform
    ActiveRecord::Base.transaction do
      # DEBT-05: advisory lock per card.id — serializa movimentação concorrente.
      # Namespace global — atualmente único user de advisory locks no Chatwoot.
      # Se outro service vier a usar advisory locks, refatorar para variant pg_advisory_xact_lock(int4, int4).
      ActiveRecord::Base.connection.execute(
        "SELECT pg_advisory_xact_lock(#{@card.id.to_i})"
      )

      @target_column = @card.kanban_board.kanban_columns.find(@target_column_id)
      column_changed = @source_column.id != @target_column.id

      @card.without_auditing do
        @card.update!(kanban_column_id: @target_column.id, position: @new_position)
      end

      if column_changed
        record_move_audit
        @card.archive!(@target_column.column_type, @outcome_reason) if @target_column.column_won? || @target_column.column_lost?
        sync_conversation_status if @target_column.conversation_status.present?
      end

      dispatch_card_moved(column_changed)
    end

    @card
  end

  private

  def sync_conversation_status
    conversation = @card.conversation
    return unless conversation

    conversation.public_send(:"#{@target_column.conversation_status}!")
  rescue StandardError => e
    Rails.logger.error "[Kanban::CardMoveService] Failed to sync conversation status: #{e.message}"
  end

  def record_move_audit
    Audited.audit_class.create!(
      auditable_type: 'KanbanCard',
      auditable_id: @card.id,
      action: 'update',
      audited_changes: {
        'kanban_column_id' => [@source_column.id, @target_column.id],
        'kanban_column_name' => [@source_column.name, @target_column.name]
      },
      user: @user
    )
  rescue StandardError => e
    Rails.logger.error "[Kanban::CardMoveService] Failed to record move audit: #{e.message}"
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
      performed_by: @user,
      trigger_event_id: @trigger_event_id
    )
  end
end
