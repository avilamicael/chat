class Billing::HandleBillingEventService
  PLAN_FEATURES = YAML.safe_load(Rails.root.join('config/plan_features.yml').read).freeze

  def initialize(payload)
    @payload = payload.with_indifferent_access
  end

  def perform
    account = Account.find_by(id: @payload[:account_id])
    return unless account

    case @payload[:event]
    when 'subscription.activated'
      activate_plan(account, @payload[:plan], @payload[:expires_at])
    when 'subscription.cancelled'
      downgrade_to_free(account)
    when 'trial.started'
      Billing::StartTrialService.new(account, trial_ends_at: @payload[:trial_ends_at]).perform
    end
  end

  private

  def activate_plan(account, plan, expires_at)
    plan_features = PLAN_FEATURES[plan.to_s] || []
    all_feature_names = PLAN_FEATURES.values.flatten.uniq

    account.transaction do
      account.enable_features(*plan_features)
      features_to_disable = all_feature_names - plan_features
      account.disable_features(*features_to_disable)
      account.save!

      account.custom_attributes = account.custom_attributes.merge(
        'plan_name' => plan.to_s,
        'plan_expires_at' => expires_at,
        'trial_ends_at' => nil
      )
      account.save!
    end

    update_installation_plan(account, plan.to_s)
  end

  def downgrade_to_free(account)
    Billing::DowngradeToFreeService.new(account).perform
  end

  def update_installation_plan(account, plan)
    config = InstallationConfig.find_or_initialize_by(name: 'INSTALLATION_PRICING_PLAN')
    config.value = plan
    config.save!
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: account).capture_exception
  end
end
