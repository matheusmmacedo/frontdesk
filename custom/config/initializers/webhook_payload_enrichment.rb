# frozen_string_literal: true

# WEBHOOK PAYLOAD ENRICHMENT
# Adds channel_type to inbox.webhook_data so downstream consumers (KLaOS)
# can distinguish between Channel::WebWidget, Channel::Whatsapp, Channel::Api, etc.
# without having to look up the inbox separately.
#
# This is safe because it only adds fields — existing consumers still get id/name.

Rails.application.config.to_prepare do
  if defined?(Inbox) && !Inbox.method_defined?(:klaos_webhook_data_enriched)
    Inbox.class_eval do
      alias_method :original_webhook_data, :webhook_data unless method_defined?(:original_webhook_data)

      def webhook_data
        original_webhook_data.merge(
          channel_type: channel_type,
          channel_name: channel_type&.gsub('Channel::', ''),
          provider: (channel.try(:provider) if channel.respond_to?(:provider))
        ).compact
      end

      def klaos_webhook_data_enriched
        true
      end
    end

    Rails.logger.info '[WEBHOOK_ENRICHMENT] Inbox.webhook_data patched with channel_type'
  end
end
