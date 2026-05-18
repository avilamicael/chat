require 'rails_helper'

# Spec exception (justified in chatwoot/CLAUDE.md): valida integridade da migration
# `PartitionAuditsByMonth`. É a ÚNICA spec adicionada neste milestone.
require Rails.root.glob('db/migrate/*_partition_audits_by_month.rb').first.to_s

# rubocop:disable RSpec/SpecFilePathFormat
describe PartitionAuditsByMonth, type: :migration do
  it 'is irreversible — raises on down' do
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end

  it 'creates partitioned audits table with monthly partitions' do
    # Roda contra um schema já migrado (CI/dev rodam `db:migrate` antes do RSpec).
    partition_count = ActiveRecord::Base.connection.exec_query(<<~SQL.squish).rows.first.first
      SELECT count(*) FROM pg_class c
      JOIN pg_inherits i ON i.inhrelid = c.oid
      JOIN pg_class p ON p.oid = i.inhparent
      WHERE p.relname = 'audits' AND c.relname LIKE 'audits_%';
    SQL

    expect(partition_count).to be >= 10
  end

  it 'audits root table is declared as partitioned by RANGE on created_at' do
    partkey = ActiveRecord::Base.connection.exec_query(<<~SQL.squish).rows.first&.first
      SELECT pg_get_partkeydef(c.oid) FROM pg_class c
      WHERE c.relname = 'audits' AND c.relkind = 'p';
    SQL

    expect(partkey).to include('RANGE').and include('created_at')
  end

  it 'has default catch-all partition `audits_default`' do
    exists = ActiveRecord::Base.connection.exec_query(<<~SQL.squish).rows.first.first
      SELECT count(*) FROM pg_class WHERE relname = 'audits_default';
    SQL

    expect(exists).to eq(1)
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
