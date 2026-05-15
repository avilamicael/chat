class AddWebhookSecretToKanbanColumns < ActiveRecord::Migration[7.1]
  def up
    add_column :kanban_columns, :webhook_secret, :string

    # D9: backfill secret for all existing columns via CSPRNG (64-char hex, > 128-bit entropy)
    # has_secure_token em KanbanColumn irá gerar base58(24) para novas rows — ambos seguros
    KanbanColumn.where(webhook_secret: nil).find_each do |col|
      col.update_column(:webhook_secret, SecureRandom.hex(32))
    end

    change_column_null :kanban_columns, :webhook_secret, false
  end

  def down
    remove_column :kanban_columns, :webhook_secret
  end
end
