# frozen_string_literal: true

# AGENT BOT WEBHOOK GUARD
# Ensures agent bot webhooks fire for every incoming message on bot-enabled inboxes.
# Runs alongside Chatwoot's built-in AgentBotListener with Rails.cache dedup.

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

        payload = webhook_data.merge(event: 'message_created')
        AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload)

        Rails.logger.info("[AGENT_BOT_GUARD] Dispatched msg=#{id} -> bot=#{agent_bot.name}")
      rescue StandardError => e
        Rails.logger.error("[AGENT_BOT_GUARD] Error msg=#{id}: #{e.class}: #{e.message}")
      end
    end

    Rails.logger.info '[AGENT_BOT_GUARD] Guard installed on Message model'
  end
end
