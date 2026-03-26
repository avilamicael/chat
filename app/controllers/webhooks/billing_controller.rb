class Webhooks::BillingController < ActionController::API
  def process_payload
    payload = request.body.read
    sig = request.headers['X-Billing-Signature']

    unless valid_signature?(payload, sig)
      head :unauthorized and return
    end

    Billing::HandleBillingEventService.new(JSON.parse(payload)).perform
    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
    head :internal_server_error
  end

  private

  def valid_signature?(payload, sig)
    secret = ENV.fetch('BILLING_WEBHOOK_SECRET', nil)
    return false if secret.blank? || sig.blank?

    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
    ActiveSupport::SecurityUtils.secure_compare(expected, sig)
  end
end
