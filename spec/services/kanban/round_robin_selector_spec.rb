require 'rails_helper'

describe Kanban::RoundRobinSelector do
  subject(:selector) { described_class.new(column: column) }

  let!(:account) { create(:account) }
  let!(:user_one) { create(:user, account: account, role: :agent) }
  let!(:user_two) { create(:user, account: account, role: :agent) }
  let!(:user_three) { create(:user, account: account, role: :agent) }
  let!(:board) { create(:kanban_board, account: account) }
  let!(:column) { create(:kanban_column, kanban_board: board, account: account) }

  before do
    Redis::Alfred.delete(format(Redis::Alfred::KANBAN_ROUND_ROBIN_AGENTS, column_id: column.id))
  end

  after do
    Redis::Alfred.delete(format(Redis::Alfred::KANBAN_ROUND_ROBIN_AGENTS, column_id: column.id))
  end

  describe '#available_agent' do
    it 'rebuilds queue from team members on first call' do
      allowed = [user_one.id, user_two.id, user_three.id].map(&:to_s)
      result = selector.available_agent(allowed_agent_ids: allowed)
      expect(result).to be_a(User)
      expect(allowed).to include(result.id.to_s)
      expect(selector.send(:queue)).not_to be_empty
    end

    it 'atomic rotation under concurrent calls returns distinct agents' do
      allowed = [user_one.id, user_two.id].map(&:to_s)
      # Seed queue
      selector.send(:reset_queue, team_member_ids: allowed.map(&:to_i))

      results = []
      mutex = Mutex.new
      threads = Array.new(2) do
        Thread.new do
          agent = described_class.new(column: column).available_agent(allowed_agent_ids: allowed)
          mutex.synchronize { results << agent.id } if agent
        end
      end
      threads.each(&:join)

      expect(results.uniq.size).to eq(2)
    end

    it 'reset_queue replaces members when team composition changes' do
      selector.send(:reset_queue, team_member_ids: [user_one.id, user_two.id])
      expect(selector.send(:queue).map(&:to_i)).to contain_exactly(user_one.id, user_two.id)

      selector.send(:reset_queue, team_member_ids: [user_three.id])
      expect(selector.send(:queue).map(&:to_i)).to contain_exactly(user_three.id)
    end
  end
end
