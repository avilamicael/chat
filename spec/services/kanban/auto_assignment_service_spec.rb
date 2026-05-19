require 'rails_helper'

describe Kanban::AutoAssignmentService do
  let!(:account) { create(:account) }
  let!(:agent_one) { create(:user, account: account, role: :agent) }
  let!(:agent_two) { create(:user, account: account, role: :agent) }
  let!(:board) { create(:kanban_board, account: account) }
  let!(:column) do
    create(:kanban_column, kanban_board: board, account: account,
                           auto_assignment_enabled: true)
  end
  let!(:card) { create(:kanban_card, kanban_board: board, kanban_column: column, account: account) }

  before do
    create(:user, account: account, role: :administrator)
    Redis::Alfred.delete(format(Redis::Alfred::KANBAN_ROUND_ROBIN_AGENTS, column_id: column.id))
  end

  after do
    Redis::Alfred.delete(format(Redis::Alfred::KANBAN_ROUND_ROBIN_AGENTS, column_id: column.id))
  end

  describe '#perform' do
    it 'assigns next agent when column has auto_assignment_enabled and team has members' do
      described_class.new(card: card, column: column, trigger: :card_added).perform
      expect(card.reload.assignee_ids).to be_present
      expect(card.assignee_ids.first).to be_in([agent_one.id, agent_two.id])
    end

    it 'skips assignment when card has assignee_id and override=false (default)' do
      card.update!(assignee_ids: [agent_one.id])
      column.update!(auto_assignment_override: false)

      described_class.new(card: card, column: column, trigger: :card_added).perform
      expect(card.reload.assignee_ids).to eq([agent_one.id])
    end

    it 'filters offline agents when online_only=true' do
      column.update!(auto_assignment_online_only: true)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        { agent_one.id.to_s => 'online', agent_two.id.to_s => 'offline' }
      )

      described_class.new(card: card, column: column, trigger: :card_added).perform
      expect(card.reload.assignee_ids).to eq([agent_one.id])
    end

    it 'skips overloaded agent when max_cards_per_agent reached' do
      column.update!(auto_assignment_max_cards_per_agent: 1)
      # agent_one tem 1 card; é considered overloaded (>= max)
      create(:kanban_card, kanban_board: board, kanban_column: column, account: account, assignee_ids: [agent_one.id])

      described_class.new(card: card, column: column, trigger: :card_added).perform
      expect(card.reload.assignee_ids).to eq([agent_two.id])
    end

    it 'handle_fallback notifies admins and marks card when no eligible agent' do
      # Sem agentes online + flag online_only ligada → todos filtrados
      column.update!(auto_assignment_online_only: true)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        { agent_one.id.to_s => 'offline', agent_two.id.to_s => 'offline' }
      )

      expect do
        described_class.new(card: card, column: column, trigger: :card_added).perform
      end.to change(Notification, :count).by(account.administrators.count)

      expect(card.reload.auto_assignment_fell_through).to be(true)
      expect(card.assignee_ids).to be_empty
    end
  end
end
