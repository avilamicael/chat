class RemoveUniqueKanbanCardBoardConversation < ActiveRecord::Migration[7.0]
  def up
    remove_index :kanban_cards, name: 'idx_unique_kanban_card_board_conversation', if_exists: true
    add_index :kanban_cards, [:kanban_board_id, :conversation_id],
              where: 'conversation_id IS NOT NULL',
              name: 'idx_kanban_card_board_conversation',
              if_not_exists: true
  end

  def down
    remove_index :kanban_cards, name: 'idx_kanban_card_board_conversation', if_exists: true
    add_index :kanban_cards, [:kanban_board_id, :conversation_id],
              unique: true,
              where: 'conversation_id IS NOT NULL',
              name: 'idx_unique_kanban_card_board_conversation',
              if_not_exists: true
  end
end
