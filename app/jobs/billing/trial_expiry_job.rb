class Billing::TrialExpiryJob < ApplicationJob
  queue_as :low

  def perform
    Account.where("custom_attributes->>'plan_name' = 'trial'").find_each do |account|
      trial_ends_at = account.custom_attributes['trial_ends_at']
      next if trial_ends_at.blank?
      next unless Time.zone.parse(trial_ends_at) < Time.zone.now

      Billing::DowngradeToFreeService.new(account).perform
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end
end
