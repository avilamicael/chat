module Kanban
  class ColumnActionsService
    def initialize(card, column, actions_type)
      @card = card
      @column = column
      @actions_type = actions_type
      @actions = (column.public_send(actions_type) || []).select { |a| a.is_a?(Hash) }
      @account = column.account
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
      case action['action_name']
      when 'auto_assign_agent'
        auto_assign_agent
      when 'auto_assign_conversation'
        auto_assign_conversation
      when 'auto_resolve'
        auto_resolve
      when 'send_webhook'
        Kanban::WebhookJob.perform_later(action['url'], webhook_payload) if action['url'].present?
      when 'assign_agent'
        assign_agent(action['agent_id'])
      when 'assign_team'
        assign_team(action['team_id'])
      end
    end

    def auto_assign_agent
      return if @card.assignee_id.present?

      agent = find_available_agent
      return unless agent

      @card.update!(assignee_id: agent.id)
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

      @card.update!(assignee_id: agent.id)
    end

    def assign_team(team_id)
      return if team_id.blank? || @card.conversation_id.blank?

      team = @account.teams.find_by(id: team_id.to_i)
      return unless team

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
