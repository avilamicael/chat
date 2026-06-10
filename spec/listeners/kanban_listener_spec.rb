require 'rails_helper'

describe KanbanListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:board) { create(:kanban_board, :default, account: account) }
  let!(:intake_column) do
    create(:kanban_column, kanban_board: board, account: account, position: 0)
  end
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def event_for(message)
    Events::Base.new('message_created', Time.zone.now, { message: message })
  end

  def active_card_count
    KanbanCard.active.where(conversation_id: conversation.id).count
  end

  describe '#message_created' do
    it 'V5: creates a card on-demand for an outgoing non-private message when no active card exists' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 message_type: :outgoing, private: false)

      expect do
        listener.message_created(event_for(message))
      end.to change { active_card_count }.from(0).to(1)
    end

    it 'V6: does not create a card for a private message' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 message_type: :outgoing, private: true)

      expect do
        listener.message_created(event_for(message))
      end.not_to(change { active_card_count })
    end

    it 'V6: does not create a card for an activity message' do
      message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 message_type: :activity)

      expect do
        listener.message_created(event_for(message))
      end.not_to(change { active_card_count })
    end

    it 'V10: does not create a new card but broadcasts an update when an active card exists' do
      create(:kanban_card, kanban_board: board, kanban_column: intake_column,
                           account: account, conversation_id: conversation.id)
      message = create(:message, account: account, inbox: inbox, conversation: conversation,
                                 message_type: :incoming)

      allow(ActionCableBroadcastJob).to receive(:perform_later)

      expect do
        listener.message_created(event_for(message))
      end.not_to(change { active_card_count })

      expect(ActionCableBroadcastJob).to have_received(:perform_later).with(
        anything, 'kanban.card_updated', anything
      )
    end
  end
end
