require 'rails_helper'

describe Kanban::AutoPopulateService do
  let!(:account) { create(:account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:board) { create(:kanban_board, :default, account: account) }
  let!(:intake_column) do
    create(:kanban_column, kanban_board: board, account: account, position: 0)
  end
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }

  def active_card_count
    KanbanCard.active.where(conversation_id: conversation.id).count
  end

  describe '#perform' do
    it 'V1: creates one active card on the intake column and dispatches KANBAN_CARD_ADDED' do
      allow(Rails.configuration.dispatcher).to receive(:dispatch).and_call_original

      expect do
        described_class.new(conversation).perform
      end.to change { active_card_count }.from(0).to(1)

      card = KanbanCard.active.find_by(conversation_id: conversation.id)
      expect(card.kanban_column_id).to eq(intake_column.id)
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        Events::Types::KANBAN_CARD_ADDED, anything, hash_including(card: card, board: board)
      )
    end

    it 'V2: does not create a new card when an active card already exists (dedup)' do
      create(:kanban_card, kanban_board: board, kanban_column: intake_column,
                           account: account, conversation_id: conversation.id)

      expect do
        described_class.new(conversation).perform
      end.not_to(change { active_card_count })

      expect(active_card_count).to eq(1)
    end

    it 'V3: creates a new active card on reopen when only an archived (won) card exists' do
      archived = create(:kanban_card, :archived, kanban_board: board, kanban_column: intake_column,
                                                 account: account, conversation_id: conversation.id)

      expect do
        described_class.new(conversation).perform
      end.to change { active_card_count }.from(0).to(1)

      expect(archived.reload.archived_at).not_to be_nil
      new_card = KanbanCard.active.find_by(conversation_id: conversation.id)
      expect(new_card.id).not_to eq(archived.id)
      expect(new_card.kanban_column_id).to eq(intake_column.id)
    end

    it 'V4: behaves like V3 when archived card outcome is lost' do
      archived = create(:kanban_card, :archived, outcome: 'lost', kanban_board: board,
                                                 kanban_column: intake_column, account: account,
                                                 conversation_id: conversation.id)

      expect do
        described_class.new(conversation).perform
      end.to change { active_card_count }.from(0).to(1)

      expect(archived.reload.archived_at).not_to be_nil
      expect(archived.outcome).to eq('lost')
      new_card = KanbanCard.active.find_by(conversation_id: conversation.id)
      expect(new_card.id).not_to eq(archived.id)
    end

    it 'V7: does not create a card when the board filters exclude the conversation inbox' do
      other_inbox = create(:inbox, account: account)
      board.update!(filters: { 'inbox_ids' => [other_inbox.id] })

      expect do
        described_class.new(conversation).perform
      end.not_to(change { active_card_count })

      expect(active_card_count).to eq(0)
    end

    it 'V8: creates exactly one card when invoked twice for the same conversation (anti double-create)' do
      described_class.new(conversation).perform
      described_class.new(conversation).perform

      expect(active_card_count).to eq(1)
    end

    it 'V9 (regression): dispatches KANBAN_CARD_ADDED only AFTER the creation transaction commits' do
      # Bug: dispatch ocorria DENTRO da `transaction do`; o KanbanListener#kanban_card_added
      # roda async e faz KanbanCard.find — podendo rodar antes do commit (RecordNotFound),
      # entao o broadcast nunca chegava na tela (card so aparecia apos refresh).
      # Garantia: no momento do dispatch a profundidade de transacao volta ao baseline do
      # caller (dispatch fora do `transaction do`, ou seja, pos-commit).
      tx_depth_at_dispatch = nil
      allow(Rails.configuration.dispatcher).to receive(:dispatch) do |event_name, *_args|
        if event_name == Events::Types::KANBAN_CARD_ADDED
          tx_depth_at_dispatch = ActiveRecord::Base.connection.open_transactions
        end
      end

      baseline_depth = ActiveRecord::Base.connection.open_transactions
      described_class.new(conversation).perform

      expect(tx_depth_at_dispatch).to eq(baseline_depth)
    end
  end
end
