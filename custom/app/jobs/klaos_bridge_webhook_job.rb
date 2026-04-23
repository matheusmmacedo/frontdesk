# frozen_string_literal: true

# Dispara webhook pro KLaOS (fire-and-forget) com retry simples.
# Usado pelo TransferToBotController pra sincronizar estado do bridge_conversations.

class KlaosBridgeWebhookJob < ApplicationJob
  queue_as :low
  retry_on StandardError, attempts: 3, wait: 5.seconds

  def perform(url, payload)
    require 'net/http'
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 10

    req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    req.body = payload.to_json

    response = http.request(req)
    Rails.logger.info("[KlaosBridgeWebhook] #{payload[:type]} conv=#{payload[:conversation_display_id]} -> #{response.code}")
    response
  end
end
