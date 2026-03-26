class FixKanbanForeignKeysOnDelete < ActiveRecord::Migration[7.1]
  def change
    # When a conversation is deleted, cascade to kanban_card_conversations (join table)
    remove_foreign_key :kanban_card_conversations, column: :conversation_id
    add_foreign_key :kanban_card_conversations, :conversations, column: :conversation_id, on_delete: :cascade

    # When a conversation is deleted, nullify conversation_id on kanban_cards
    # (card may still have a title and remain valid)
    remove_foreign_key :kanban_cards, column: :conversation_id
    add_foreign_key :kanban_cards, :conversations, column: :conversation_id, on_delete: :nullify
  end
end
