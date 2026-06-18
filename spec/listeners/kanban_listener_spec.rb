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

  describe '#conversation_status_changed' do
    let!(:open_column) do
      create(:kanban_column, kanban_board: board, account: account, position: 1, conversation_status: 'open')
    end
    let!(:won_column) do
      create(:kanban_column, kanban_board: board, account: account, position: 2,
                             conversation_status: 'resolved', column_type: 'won')
    end

    def status_event
      Events::Base.new('conversation_status_changed', Time.zone.now, { conversation: conversation })
    end

    it 'V11: does not move an archived (finalized) card when the conversation status changes (no resolve loop)' do
      conversation.update!(status: :open)
      archived_card = create(:kanban_card, :archived, kanban_board: board, kanban_column: won_column,
                                                      account: account, conversation_id: conversation.id)

      expect do
        listener.conversation_status_changed(status_event)
      end.not_to(change { archived_card.reload.kanban_column_id })

      expect(archived_card.reload.kanban_column_id).to eq(won_column.id)
    end

    it 'V12: still syncs the ACTIVE card to the column matching the new status' do
      conversation.update!(status: :open)
      active_card = create(:kanban_card, kanban_board: board, kanban_column: won_column,
                                         account: account, conversation_id: conversation.id)

      listener.conversation_status_changed(status_event)

      expect(active_card.reload.kanban_column_id).to eq(open_column.id)
    end

    it 'V13 (regression): recreates a card on manual reopen when going to open and no active card exists' do
      conversation.update!(status: :open)
      archived = create(:kanban_card, :archived, kanban_board: board, kanban_column: won_column,
                                                 account: account, conversation_id: conversation.id)

      expect do
        listener.conversation_status_changed(status_event)
      end.to change { active_card_count }.from(0).to(1)

      new_card = KanbanCard.active.find_by(conversation_id: conversation.id)
      expect(new_card.id).not_to eq(archived.id)
      expect(new_card.kanban_column_id).to eq(intake_column.id)
    end

    it 'V14 (regression): does not recreate a card when status changes to a non-open status' do
      conversation.update!(status: :resolved)
      create(:kanban_card, :archived, kanban_board: board, kanban_column: won_column,
                                      account: account, conversation_id: conversation.id)

      expect do
        listener.conversation_status_changed(status_event)
      end.not_to(change { active_card_count })
    end
  end
end
