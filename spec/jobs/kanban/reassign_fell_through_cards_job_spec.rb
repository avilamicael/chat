require 'rails_helper'

RSpec.describe Kanban::ReassignFellThroughCardsJob, type: :job do
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account, role: :agent) }
  let!(:board) { create(:kanban_board, account: account) }
  let!(:column) do
    create(:kanban_column, kanban_board: board, account: account,
                           auto_assignment_enabled: true,
                           auto_assignment_reassign_on_return: true)
  end

  describe '#perform' do
    it 'invokes AutoAssignmentService for fell-through cards in reassign-enabled columns' do
      card = create(:kanban_card, kanban_column: column, kanban_board: board, account: account,
                                  auto_assignment_fell_through: true)

      expect(Kanban::AutoAssignmentService).to receive(:new)
        .with(card: card, column: column, trigger: :agent_returned)
        .and_return(instance_double(Kanban::AutoAssignmentService, perform: true))

      described_class.new.perform(user.id)
    end

    it 'is noop when user has no agent role in any account' do
      userless = create(:user) # sem account_users
      expect(Kanban::AutoAssignmentService).not_to receive(:new)
      described_class.new.perform(userless.id)
    end
  end
end
