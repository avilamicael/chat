class AddLastMovedAtToKanbanCards < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    add_column :kanban_cards, :last_moved_at, :datetime, null: true
    add_index :kanban_cards, :last_moved_at, algorithm: :concurrently

    # Backfill: cards existentes recebem created_at como aproximação inicial.
    # Movimentações reais via Kanban::CardMoveService sobrescrevem.
    KanbanCard.in_batches(of: 1000).update_all('last_moved_at = created_at')
  end

  def down
    remove_index :kanban_cards, :last_moved_at, algorithm: :concurrently
    remove_column :kanban_cards, :last_moved_at
  end
end
