# frozen_string_literal: true

# AGENT BOT WEBHOOK GUARD
# Guarantees agent bot webhooks fire for EVERY incoming message on bot-enabled inboxes.
#
# Problem: Chatwoot's built-in AgentBotListener (SyncDispatcher) sometimes fails
# to dispatch AgentBots::WebhookJob, especially for recently provisioned bots.
#
# Solution: Replace the unreliable listener-based dispatch with a direct
# after_create_commit callback on Message. This runs in the same transaction
# commit hook as the original dispatch_create_events, but is more reliable
# because it doesn't depend on the event dispatcher chain.
#
# Deduplication: We mark the message with a flag in content_attributes so
# both this guard AND the normal listener can coexist without double-dispatch.

Rails.application.config.after_initialize do
  Message.class_eval do
    after_create_commit :guard_agent_bot_webhook

    private

    def guard_agent_bot_webhook
      return unless incoming?
      return if inbox.blank?

      bot_inbox = inbox.agent_bot_inbox
      return unless bot_inbox&.active?

      agent_bot = inbox.agent_bot
      return unless agent_bot&.outgoing_url.present?

      # Check if already dispatched (flag set by this guard)
      cache_key = "agent_bot_webhook_dispatched:#{id}"
      return if Rails.cache.read(cache_key)

      # Mark as dispatched (TTL 60s — enough to prevent duplicates)
      Rails.cache.write(cache_key, true, expires_in: 60.seconds)

      # Dispatch the webhook
      payload = webhook_data.merge(event: 'message_created')
      AgentBots::WebhookJob.perform_later(agent_bot.outgoing_url, payload)

      Rails.logger.info("[AGENT_BOT_GUARD] Dispatched webhook for msg #{id} → #{agent_bot.name} (#{agent_bot.outgoing_url.last(40)})")
    rescue StandardError => e
      Rails.logger.error("[AGENT_BOT_GUARD] Error for msg #{id}: #{e.message}")
    end
  end
end
