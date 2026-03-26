class Billing::StartTrialService
  PLAN_FEATURES = YAML.safe_load(Rails.root.join('config/plan_features.yml').read).freeze

  def initialize(account, trial_ends_at: nil, days: nil)
    @account = account
    @trial_ends_at = trial_ends_at || compute_end_date(days)
  end

  def perform
    return unless @trial_ends_at

    trial_features = PLAN_FEATURES['trial'] || []

    @account.transaction do
      @account.enable_features!(*trial_features)
      @account.custom_attributes = @account.custom_attributes.merge(
        'plan_name' => 'trial',
        'trial_ends_at' => @trial_ends_at.to_s
      )
      @account.save!
    end
  end

  private

  def compute_end_date(days)
    return nil unless days.to_i.positive?

    days.to_i.days.from_now.iso8601
  end
end
