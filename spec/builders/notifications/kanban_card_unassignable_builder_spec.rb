require 'rails_helper'

describe Notifications::KanbanCardUnassignableBuilder do
  let!(:account) { create(:account) }
  let!(:board) { create(:kanban_board, account: account) }
  let!(:column) { create(:kanban_column, kanban_board: board, account: account, name: 'Backlog') }
  let!(:card) { create(:kanban_card, kanban_board: board, kanban_column: column, account: account) }

  before do
    create(:user, account: account, role: :administrator)
    create(:user, account: account, role: :administrator)
  end

  describe '#perform' do
    it 'creates one notification per admin with correct meta' do
      expect do
        described_class.new(card: card, column: column).perform
      end.to change(Notification, :count).by(account.administrators.count)

      notification = Notification.last
      expect(notification.notification_type).to eq('kanban_card_unassignable')
      expect(notification.primary_actor).to eq(card)
      expect(notification.secondary_actor).to eq(column)
      expect(notification.meta['column_name']).to eq('Backlog')
    end
  end
end
