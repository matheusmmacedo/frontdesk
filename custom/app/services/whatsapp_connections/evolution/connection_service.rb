# frozen_string_literal: true

# Creates a WhatsappConnection for Evolution API.
# Evolution config is global (Super Admin), but each account has its own connection record.
module WhatsappConnections
  module Evolution
    class ConnectionService
      def initialize(account:, name: nil)
        @account = account
        @name = name || 'Evolution API'
      end

      def perform
        validate_single_connection!
        validate_global_config!
        connection = create_connection
        sync_instances(connection)
        connection
      end

      private

      def validate_single_connection!
        existing = @account.whatsapp_connections.where(provider: 'evolution').first
        raise 'Já existe uma conexão WhatsApp Não Oficial nesta conta' if existing
      end

      def validate_global_config!
        # This will raise if not configured
        WhatsappConnections::Evolution::ApiClient.new
      end

      def create_connection
        WhatsappConnection.create!(
          account: @account,
          provider: 'evolution',
          name: @name,
          credentials: {},
          status: 'active'
        )
      end

      def sync_instances(connection)
        WhatsappConnections::Evolution::InstanceSyncService.new(connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Evolution instance sync failed: #{e.message}")
      end
    end
  end
end
