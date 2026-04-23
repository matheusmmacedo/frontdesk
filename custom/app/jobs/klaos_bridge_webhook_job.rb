# frozen_string_literal: true

# Dispara webhook pro KLaOS bridge-event (fire-and-forget, com retry).
# Contrato definido em docs/para-frontdesk-agent/KLAOS_UPDATES.md:
#   POST https://api-dev.klaos.ai/api/webhooks/klaos/bridge-event
#   Headers: Content-Type: application/json, X-Bridge-Secret: <shared>

class KlaosBridgeWebhookJob < ApplicationJob
  queue_as :low
  retry_on StandardError, attempts: 3, wait: 5.seconds

  def perform(url, payload, secret = nil)
    require 'net/http'
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    req['X-Bridge-Secret'] = secret if secret.present?
    req.body = payload.to_json

    response = http.request(req)
    Rails.logger.info("[KlaosBridgeWebhook] #{payload[:type]} conv=#{payload[:conv_display_id]} -> #{response.code}")
    response
  end
end
