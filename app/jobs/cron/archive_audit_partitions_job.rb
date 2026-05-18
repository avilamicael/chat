# Pipeline diário de retenção da tabela `audits`:
#   1. Lista partições filhas via pg_class + pg_inherits.
#   2. Para cada partição cujo `range_end <= cutoff` (RETENTION_MONTHS atrás):
#      a. SKIP se `AuditArchive.exists?(period_start:)` (idempotência).
#      b. Stream rows → NDJSON gzipado → upload via ActiveStorage::Blob.
#      c. Cria `AuditArchive` (registro do manifesto).
#      d. SÓ APÓS sucesso de upload + INSERT, `DROP TABLE` da partição local.
#   3. Cria a partição do mês N+1 se ainda faltar (idempotente via pg_class check).
#
# Em qualquer falha (upload, INSERT, etc.) a partição local é mantida intacta
# para retry no próximo cron — garantia anti-perda de audits.
class Cron::ArchiveAuditPartitionsJob < ApplicationJob
  queue_as :scheduled_jobs

  RETENTION_MONTHS = 6
  ARCHIVE_BATCH_SIZE = 5000

  def perform
    archive_old_partitions
    create_upcoming_partition
  end

  private

  def archive_old_partitions
    cutoff = RETENTION_MONTHS.months.ago.beginning_of_month
    list_partitions.each do |part|
      next if part[:name] == 'audits_default'
      next unless part[:range_end] <= cutoff
      next if AuditArchive.exists?(period_start: part[:range_start])

      archive_partition(part)
    end
  end

  def list_partitions
    rows = ActiveRecord::Base.connection.exec_query(<<~SQL.squish)
      SELECT c.relname AS name,
             pg_get_expr(c.relpartbound, c.oid) AS bounds
      FROM pg_class c
      JOIN pg_inherits i ON i.inhrelid = c.oid
      JOIN pg_class p ON p.oid = i.inhparent
      WHERE p.relname = 'audits' AND c.relname LIKE 'audits_%'
    SQL
    rows.filter_map { |r| parse_partition(r) }
  end

  def parse_partition(row)
    return { name: row['name'], range_start: nil, range_end: nil } if row['bounds']&.include?('DEFAULT')

    match = row['bounds'].to_s.match(/FROM \('([^']+)'\) TO \('([^']+)'\)/)
    return nil unless match

    {
      name: row['name'],
      range_start: Time.zone.parse(match[1]),
      range_end: Time.zone.parse(match[2])
    }
  end

  def archive_partition(part)
    filename = "#{part[:range_start].strftime('%Y-%m')}.json.gz"
    tempfile = Tempfile.new(['audit-archive', '.json.gz'], binmode: true)
    digest = Digest::SHA256.new
    record_count = stream_partition_to_gzip(part[:name], tempfile, digest)

    blob = upload_archive(tempfile, filename)
    persist_manifest(part, blob, record_count, digest)
    drop_partition(part[:name])

    Rails.logger.info "[Cron::ArchiveAuditPartitionsJob] archived #{part[:name]} (#{record_count} rows)"
  rescue StandardError => e
    Rails.logger.error "[Cron::ArchiveAuditPartitionsJob] failed for #{part[:name]}: #{e.message}"
    ChatwootExceptionTracker.new(e).capture_exception
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def stream_partition_to_gzip(table_name, tempfile, digest)
    gz = Zlib::GzipWriter.new(tempfile)
    record_count = 0
    ActiveRecord::Base.connection.exec_query("SELECT * FROM #{table_name} ORDER BY id").each do |row|
      line = "#{JSON.generate(row)}\n"
      gz.write(line)
      digest.update(line) # rubocop:disable Rails/SaveBang — Digest::SHA256#update, not AR
      record_count += 1
    end
    gz.close
    tempfile.rewind
    record_count
  end

  def upload_archive(tempfile, filename)
    ActiveStorage::Blob.create_and_upload!(
      io: tempfile,
      filename: filename,
      content_type: 'application/gzip',
      service_name: ENV.fetch('AUDIT_ARCHIVE_STORAGE_SERVICE', 'amazon').to_sym
    )
  end

  def persist_manifest(part, blob, record_count, digest)
    AuditArchive.create!(
      period_start: part[:range_start],
      period_end: part[:range_end],
      storage_path: blob.key,
      record_count: record_count,
      checksum_sha256: digest.hexdigest,
      archived_at: Time.current
    )
  end

  def drop_partition(table_name)
    ActiveRecord::Base.connection.execute("DROP TABLE #{table_name};")
  end

  def create_upcoming_partition
    next_month = 1.month.from_now.beginning_of_month
    part_name  = "audits_#{next_month.strftime('%Y_%m')}"

    exists = ActiveRecord::Base.connection.exec_query(
      "SELECT 1 FROM pg_class WHERE relname = '#{part_name}'"
    ).any?
    return if exists

    range_start = next_month.strftime('%Y-%m-%d')
    range_end   = (next_month + 1.month).strftime('%Y-%m-%d')
    ActiveRecord::Base.connection.execute(
      "CREATE TABLE #{part_name} PARTITION OF audits " \
      "FOR VALUES FROM ('#{range_start}') TO ('#{range_end}');"
    )
    Rails.logger.info "[Cron::ArchiveAuditPartitionsJob] created upcoming partition #{part_name}"
  end
end
