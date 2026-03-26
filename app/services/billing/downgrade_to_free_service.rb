class Billing::DowngradeToFreeService
  PLAN_FEATURES = YAML.safe_load(Rails.root.join('config/plan_features.yml').read).freeze

  def initialize(account)
    @account = account
  end

  def perform
    all_features = PLAN_FEATURES.values.flatten.uniq

    @account.transaction do
      @account.disable_features!(*all_features)
      @account.custom_attributes = @account.custom_attributes.merge(
        'plan_name' => 'free',
        'plan_expires_at' => nil,
        'trial_ends_at' => nil
      )
      @account.save!
    end
  end
end
