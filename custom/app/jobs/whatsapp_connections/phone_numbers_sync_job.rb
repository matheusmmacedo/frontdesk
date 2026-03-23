# frozen_string_literal: true

# Periodically syncs phone numbers for all active connections.
# Meta Cloud: fetches numbers from WABA
# Evolution: fetches instances from Evolution API
module WhatsappConnections
  class PhoneNumbersSyncJob < ApplicationJob
    queue_as :low

    def perform
      sync_meta_connections
      sync_evolution_connections
    end

    private

    def sync_meta_connections
      WhatsappConnection.active.meta_cloud.find_each do |connection|
        WhatsappConnections::Meta::PhoneSyncService.new(connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Meta phone sync failed for connection #{connection.id}: #{e.message}")
      end
    end

    def sync_evolution_connections
      WhatsappConnection.active.evolution.find_each do |connection|
        WhatsappConnections::Evolution::InstanceSyncService.new(connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Evolution sync failed for connection #{connection.id}: #{e.message}")
      end
    end
  end
end
