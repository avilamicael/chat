module Kanban
  class ColumnActionsService
    def initialize(card, column, actions_type)
      @card = card
      @column = column
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
      {
        event: 'kanban.card_column_changed',
        card_id: @card.id,
        board_id: @column.kanban_board_id,
        column_id: @column.id,
        column_name: @column.name,
        conversation_id: @card.conversation_id,
        timestamp: Time.zone.now.iso8601
      }
    end
  end
end
