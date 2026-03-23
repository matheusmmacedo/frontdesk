# frozen_string_literal: true

# Periodically syncs message templates for all active Meta Cloud connections.
# Can be triggered by scheduler (e.g., every 3 hours) or manually.
module WhatsappConnections
  class TemplatesSyncJob < ApplicationJob
    queue_as :low

    def perform
      WhatsappConnection.active.meta_cloud.find_each do |connection|
        next if recently_synced?(connection)

        sync_templates(connection)
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Template sync failed for connection #{connection.id}: #{e.message}")
      end
    end

    private

    def recently_synced?(connection)
      connection.message_templates_last_updated.present? &&
        connection.message_templates_last_updated > 3.hours.ago
    end

    def sync_templates(connection)
      WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
    end
  end
end
