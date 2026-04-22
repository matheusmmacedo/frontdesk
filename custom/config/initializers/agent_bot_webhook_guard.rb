# frozen_string_literal: true

# AGENT BOT WEBHOOK GUARD (ROBUSTO)
# Garante que todo webhook de agent_bot saia na hora, mesmo se Sidekiq estiver travado.
# - Dispara síncrono via Net::HTTP (blocking, mas rápido)
# - Dedupe por 60s em Rails.cache
# - Loga no Rails.logger + grava rastro em conversation.additional_attributes pra debug

require 'net/http'
require 'uri'
require 'json'

Rails.application.config.to_prepare do
  if defined?(Message) && !Message.method_defined?(:guard_agent_bot_webhook)
    Message.class_eval do
      after_create_commit :guard_agent_bot_webhook

      def guard_agent_bot_webhook
        return unless incoming?
        return if inbox.blank?

        bot_inbox = AgentBotInbox.find_by(inbox_id: inbox_id, status: :active)
        return if bot_inbox.blank?

        agent_bot = bot_inbox.agent_bot
        return if agent_bot.blank? || agent_bot.outgoing_url.blank?

        cache_key = "agent_bot_webhook_dispatched:#{id}"
        return if Rails.cache.read(cache_key)

        Rails.cache.write(cache_key, true, expires_in: 60.seconds)

        payload = webhook_data.merge(event: 'message_created').to_json
        uri = URI.parse(agent_bot.outgoing_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 5
        http.read_timeout = 10

        req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
        req.body = payload

        start = Time.current
        begin
          res = http.request(req)
          elapsed = ((Time.current - start) * 1000).to_i
          log_line = "[#{Time.current.iso8601}] msg=#{id} bot=#{agent_bot.name} -> #{res.code} (#{elapsed}ms)"
        rescue StandardError => e
          elapsed = ((Time.current - start) * 1000).to_i
          log_line = "[#{Time.current.iso8601}] msg=#{id} bot=#{agent_bot.name} -> ERROR #{e.class}: #{e.message} (#{elapsed}ms)"
        end

        Rails.logger.info("[AGENT_BOT_GUARD] #{log_line}")

        # Grava rastro no conversation pra QA conseguir inspecionar pelo DB sem precisar dos logs do Railway
        begin
          conv = conversation
          existing = conv.additional_attributes || {}
          log = existing['agent_bot_guard_log'] || []
          log << log_line
          log = log.last(10) # manter só os 10 últimos
          conv.update_column(:additional_attributes, existing.merge('agent_bot_guard_log' => log))
        rescue StandardError
          # não deixa esse log-extra quebrar o dispatch
        end
      rescue StandardError => e
        Rails.logger.error("[AGENT_BOT_GUARD] fatal msg=#{id}: #{e.class}: #{e.message}")
      end
    end

    Rails.logger.info '[AGENT_BOT_GUARD] Synchronous guard installed on Message model'
  end
end
