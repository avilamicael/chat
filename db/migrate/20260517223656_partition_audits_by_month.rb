class PartitionAuditsByMonth < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  AUDITS_NEW_DDL = <<~SQL.squish.freeze
    CREATE TABLE audits_new (
      id              BIGSERIAL,
      auditable_id    BIGINT,
      auditable_type  VARCHAR,
      associated_id   BIGINT,
      associated_type VARCHAR,
      user_id         BIGINT,
      user_type       VARCHAR,
      username        VARCHAR,
      action          VARCHAR,
      audited_changes JSONB,
      version         INTEGER DEFAULT 0,
      comment         VARCHAR,
      remote_address  VARCHAR,
      request_uuid    VARCHAR,
      created_at      TIMESTAMP,
      PRIMARY KEY (id, created_at)
    ) PARTITION BY RANGE (created_at);
  SQL

  AUDITS_INDEXES = [
    'CREATE INDEX index_audits_on_auditable ON audits (auditable_type, auditable_id, version);',
    'CREATE INDEX index_audits_on_associated ON audits (associated_type, associated_id);',
    'CREATE INDEX index_audits_on_created_at ON audits (created_at);',
    'CREATE INDEX index_audits_on_request_uuid ON audits (request_uuid);',
    'CREATE INDEX index_audits_on_user ON audits (user_id, user_type);'
  ].freeze

  def up
    say_with_time 'partition audits table — estimated downtime <60s for typical install' do
      rebuild_and_swap
      AUDITS_INDEXES.each { |sql| connection.execute(sql) }
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'manual rollback — re-export partitions + DROP (see RESEARCH.md §5.6)'
  end

  private

  def rebuild_and_swap
    ActiveRecord::Base.transaction do
      connection.execute(AUDITS_NEW_DDL)
      create_monthly_partitions
      connection.execute('CREATE TABLE audits_default PARTITION OF audits_new DEFAULT;')
      connection.execute('INSERT INTO audits_new SELECT * FROM audits;')
      connection.execute('ALTER TABLE audits RENAME TO audits_old;')
      connection.execute('ALTER TABLE audits_new RENAME TO audits;')
      connection.execute('DROP TABLE audits_old;')
      # Renomeia sequence para o nome natural pós-swap (caso contrário schema.rb
      # registra `audits_new_id_seq` que não existe em CI/fresh load).
      connection.execute('ALTER SEQUENCE audits_new_id_seq RENAME TO audits_id_seq;')
    end
  end

  def create_monthly_partitions
    cursor = 6.months.ago.beginning_of_month
    last_month = 3.months.from_now.beginning_of_month
    while cursor <= last_month
      part_name   = "audits_#{cursor.strftime('%Y_%m')}"
      range_start = cursor.strftime('%Y-%m-%d')
      range_end   = (cursor + 1.month).strftime('%Y-%m-%d')
      connection.execute(
        "CREATE TABLE #{part_name} PARTITION OF audits_new " \
        "FOR VALUES FROM ('#{range_start}') TO ('#{range_end}');"
      )
      cursor += 1.month
    end
  end
end
