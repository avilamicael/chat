class CreateAuditArchives < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_archives do |t|
      t.datetime :period_start, null: false
      t.datetime :period_end,   null: false
      t.string   :storage_path, null: false
      t.bigint   :record_count, null: false
      t.string   :checksum_sha256, null: false, limit: 64
      t.datetime :archived_at, null: false

      t.timestamps
    end
    add_index :audit_archives, :period_start, unique: true
  end
end
