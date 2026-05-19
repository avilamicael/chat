# == Schema Information
#
# Table name: audit_archives
#
#  id              :bigint           not null, primary key
#  archived_at     :datetime         not null
#  checksum_sha256 :string(64)       not null
#  period_end      :datetime         not null
#  period_start    :datetime         not null
#  record_count    :bigint           not null
#  storage_path    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_audit_archives_on_period_start  (period_start) UNIQUE
#
class AuditArchive < ApplicationRecord
  validates :period_start, :period_end, :storage_path, :record_count,
            :checksum_sha256, :archived_at, presence: true
  validates :period_start, uniqueness: true

  scope :before, ->(date) { where('period_end <= ?', date) }
end
