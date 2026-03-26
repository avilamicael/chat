class CreateKanbanCardConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_card_conversations do |t|
      t.references :kanban_card, null: false, foreign_key: true, index: true
      t.references :conversation, null: false, foreign_key: true, index: true
      t.timestamps
    end

    add_index :kanban_card_conversations,
              [:kanban_card_id, :conversation_id],
              unique: true,
              name: 'idx_unique_kanban_card_conversation'

    # Migrar dados existentes: cada card com conversation_id → join table
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO kanban_card_conversations (kanban_card_id, conversation_id, created_at, updated_at)
          SELECT id, conversation_id, NOW(), NOW()
          FROM kanban_cards
          WHERE conversation_id IS NOT NULL
          ON CONFLICT DO NOTHING
        SQL
      end
    end
  end
end
