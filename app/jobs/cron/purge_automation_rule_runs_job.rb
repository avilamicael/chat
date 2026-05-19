# AUT-08 (D-E9): retencao 30 dias para AutomationRuleRun.
# Roda diariamente as 0315 UTC (offset de 0300 do archive_audit_partitions_job
# para nao competir por DB locks na mesma janela de baixo trafego).
#
# Usa in_batches.delete_all para evitar carregar bilhoes de rows em memoria
# em caso de janela maior (ex: backfill ou skipped runs).
class Cron::PurgeAutomationRuleRunsJob < ApplicationJob
  queue_as :scheduled_jobs

  RETENTION_DAYS = 30

  def perform
    cutoff = RETENTION_DAYS.days.ago
    AutomationRuleRun.where('created_at < ?', cutoff).in_batches.delete_all
  end
end
