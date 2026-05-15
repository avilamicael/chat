module Kanban
  class ColumnActionsService
    def initialize(card, column, actions_type, trigger_event_id: nil)
      @card = card
      @column = column
      @actions_type = actions_type
      @actions = (column.public_send(actions_type) || []).select { |a| a.is_a?(Hash) }
      @account = column.account
      @trigger_event_id = trigger_event_id || SecureRandom.uuid
    end

    def perform
      @actions.each do |action|
        execute_action(action)
      rescue StandardError => e
        Rails.logger.error "[Kanban::ColumnActionsService] #{action['action_name']} failed: #{e.message}"
      end
    end

    private

    def execute_action(action)
      action_id = action_signature(action)
      execution = KanbanCardActionExecution.create!(
        card_id: @card.id, column_id: @column.id,
        action_id: action_id, trigger_event_id: @trigger_event_id,
        direction: @actions_type.to_s, status: :pending
      )

      case action['action_name']
      when 'auto_assign_agent'
        auto_assign_agent
      when 'auto_assign_conversation'
        auto_assign_conversation
      when 'auto_resolve'
        auto_resolve
      when 'send_webhook'
        return if action['url'].blank?

        WebhookJob.perform_later(
          action['url'],
          webhook_payload,
          :account_webhook,
          secret: @column.webhook_secret,
          delivery_id: @trigger_event_id
        )
      when 'assign_agent'
        assign_agent(action['agent_id'])
      when 'assign_team'
        assign_team(action['team_id'])
      end

      execution.update!(status: :ok, executed_at: Time.current)
      @column.update_columns(
        last_execution_status: 'ok',
        last_execution_error: nil,
        last_executed_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.info "[Kanban::ColumnActionsService] dedupe: action #{action_id} trigger #{@trigger_event_id}"
    rescue StandardError => e
      execution&.update(status: :error, last_error: e.message[0, 500])
      @column.update_columns(
        last_execution_status: 'error',
        last_execution_error: e.message[0, 500],
        last_executed_at: Time.current
      )
      raise
    end

    def action_signature(action)
      payload = { name: action['action_name'], params: action.except('action_name') }
      Digest::SHA256.hexdigest(payload.to_json)[0, 32]
    end

    def auto_assign_agent
      return if @card.assignee_ids.present?

      agent = find_available_agent
      return unless agent

      @card.update!(assignee_ids: [agent.id])
    end

    def auto_assign_conversation
      return unless @card.conversation_id && @card.assignee_id

      conv = @card.conversation
      return unless conv&.assignee_id.nil?

      conv.update!(assignee_id: @card.assignee_id)
    end

    def auto_resolve
      return unless @card.conversation_id

      conv = @card.conversation
      return unless conv&.open?

      conv.update!(status: 'resolved')
    end

    def assign_agent(agent_id)
      return if agent_id.blank?

      agent = @account.users.find_by(id: agent_id.to_i)
      return unless agent

      @card.update!(assignee_ids: [agent.id])
    end

    def assign_team(team_id)
      return if team_id.blank?

      team = @account.teams.find_by(id: team_id.to_i)
      return unless team

      @card.update!(team_ids: [team.id])
      @card.conversation&.update!(team_id: team.id)
    end

    def find_available_agent
      board_id = @column.kanban_board_id
      @account.users
              .where(availability_status: :online)
              .joins(
                "LEFT JOIN kanban_cards ON kanban_cards.assignee_id = users.id " \
                "AND kanban_cards.kanban_board_id = #{board_id.to_i}"
              )
              .group('users.id')
              .order(Arel.sql('COUNT(kanban_cards.id) ASC'))
              .first
    end

    def webhook_payload
      conv = @card.conversation
      contact = conv&.contact
      assignee = @card.assignee

      {
        event: @actions_type == :enter_actions ? 'kanban.card_entered_column' : 'kanban.card_left_column',
        account_id: @account.id,
        board: {
          id: @column.kanban_board_id,
          name: @card.kanban_board.name
        },
        column: {
          id: @column.id,
          name: @column.name,
          position: @column.position
        },
        card: {
          id: @card.id,
          title: @card.title,
          description: @card.description,
          priority: @card.priority,
          task_status: @card.task_status,
          due_date: @card.due_date&.iso8601,
          reminder_at: @card.reminder_at&.iso8601,
          outcome: @card.outcome,
          outcome_reason: @card.outcome_reason,
          assignees: @card.assignees.map { |u| { id: u.id, name: u.name, email: u.email } },
          teams: @card.teams_list.map { |t| { id: t.id, name: t.name } }
        },
        conversation: conv && {
          id: conv.id,
          status: conv.status,
          inbox_id: conv.inbox_id
        },
        contact: contact && {
          id: contact.id,
          name: contact.name,
          email: contact.email,
          phone_number: contact.phone_number
        },
        assignee: assignee && {
          id: assignee.id,
          name: assignee.name,
          email: assignee.email
        },
        timestamp: Time.zone.now.iso8601
      }.compact
    end
  end
end
