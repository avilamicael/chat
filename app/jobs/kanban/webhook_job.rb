module Kanban
  class WebhookJob < ApplicationJob
    queue_as :default

    def perform(url, payload)
      return if url.blank?

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.is_a?(String) ? payload : payload.to_json

      response = http.request(request)
      Rails.logger.info "[Kanban::WebhookJob] POST #{url} -> #{response.code}"
    rescue StandardError => e
      Rails.logger.error "[Kanban::WebhookJob] Failed for #{url}: #{e.message}"
    end
  end
end
