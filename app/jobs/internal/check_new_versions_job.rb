class Internal::CheckNewVersionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Version check disabled — updates are applied manually
  end
end

Internal::CheckNewVersionsJob.prepend_mod_with('Internal::CheckNewVersionsJob')
