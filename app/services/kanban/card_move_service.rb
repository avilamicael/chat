class Kanban::CardMoveService
  attr_reader :wip_active_count

  def initialize(card, params, user = nil)
    @card = card
    @target_column_id = params[:column_id].to_i
    @new_position = params[:position].to_f
    @outcome_reason = params[:outcome_reason]
    @user = user
    @source_column = card.kanban_column
    @trigger_event_id = SecureRandom.uuid
    @wip_exceeded = false
    @wip_active_count = nil
  end

  def perform # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
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

      # Denormaliza última movimentação (D-14) — bypass audit consistente com pattern Phase 0
      # (last_execution_*). Frontend (Plan C) consome last_moved_at_ms para computar aging.
      @card.update_columns(last_moved_at: Time.current) if column_changed # rubocop:disable Rails/SkipsModelValidations

      # WIP soft (D-01/D-02): conta após UPDATE dentro da transaction.
      # Advisory_lock acima já garante serialização sem race.
      check_wip!(column_changed)

      # Phase 3 (KAN-07): auto-assignment dispara em column_changed=true. Service tem rescue
      # StandardError interno → falha nao da rollback da transaction.
      run_auto_assignment(column_changed)

      dispatch_card_moved(column_changed)
    end

    @card
  end

  def wip_exceeded?
    @wip_exceeded == true
  end

  private

  def run_auto_assignment(column_changed)
    return unless column_changed

    Kanban::AutoAssignmentService.new(card: @card, column: @target_column, trigger: :card_moved).perform
  end

  def check_wip!(column_changed)
    return unless column_changed
    return if @target_column.wip_limit.blank? # D-05 NULL = sem limite

    active_count = @target_column.kanban_cards.active.count
    return if active_count <= @target_column.wip_limit

    @wip_exceeded = true
    @wip_active_count = active_count

    Rails.configuration.dispatcher.dispatch(
      Events::Types::KANBAN_WIP_EXCEEDED,
      Time.zone.now,
      board: @card.kanban_board,
      column: @target_column,
      active_count: active_count,
      wip_limit: @target_column.wip_limit,
      triggered_by: @user
    )
  end

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
