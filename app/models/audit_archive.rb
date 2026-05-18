class AuditArchive < ApplicationRecord
  validates :period_start, :period_end, :storage_path, :record_count,
            :checksum_sha256, :archived_at, presence: true
  validates :period_start, uniqueness: true

  scope :before, ->(date) { where('period_end <= ?', date) }
end
