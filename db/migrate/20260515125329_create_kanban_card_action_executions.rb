class CreateKanbanCardActionExecutions < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_card_action_executions do |t|
      t.references :card, null: false, foreign_key: { to_table: :kanban_cards }, index: false
      t.references :column, null: false, foreign_key: { to_table: :kanban_columns }, index: false
      t.string :action_id, limit: 64, null: false
      t.string :trigger_event_id, limit: 36, null: false
      t.string :direction, null: false
      t.string :status, null: false, default: 'pending'
      t.text :last_error
      t.datetime :executed_at
      t.timestamps
    end

    # DEBT-02: UNIQUE constraint garante idempotência — mesmo trigger_event_id não executa
    # a mesma action duas vezes (retry Sidekiq, dupla execução, etc.)
    add_index :kanban_card_action_executions,
              %i[card_id action_id trigger_event_id],
              unique: true,
              name: 'idx_unique_card_action_execution'

    add_index :kanban_card_action_executions,
              %i[column_id executed_at],
              name: 'idx_card_action_executions_column_executed'
  end
end
