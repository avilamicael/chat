class AddUniqueConstraintToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    # Remove join table entries for duplicate cards first (FK constraint)
    execute <<~SQL
      DELETE FROM kanban_card_conversations
      WHERE kanban_card_id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY kanban_board_id, conversation_id
                   ORDER BY created_at DESC
                 ) AS rn
          FROM kanban_cards
          WHERE conversation_id IS NOT NULL
        ) ranked
        WHERE rn > 1
      )
    SQL

    # Remove duplicate cards keeping the most recent one per (board, conversation)
    execute <<~SQL
      DELETE FROM kanban_cards
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY kanban_board_id, conversation_id
                   ORDER BY created_at DESC
                 ) AS rn
          FROM kanban_cards
          WHERE conversation_id IS NOT NULL
        ) ranked
        WHERE rn > 1
      )
    SQL

    add_index :kanban_cards, [:kanban_board_id, :conversation_id],
              unique: true,
              where: 'conversation_id IS NOT NULL',
              name: 'idx_unique_kanban_card_board_conversation'
  end
end
