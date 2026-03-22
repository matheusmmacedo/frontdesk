# frozen_string_literal: true

# Creates a WhatsappConnection for Meta Cloud API using a direct System User token.
# No OAuth flow needed — the token is provided directly (e.g., from Meta Business Suite).
module WhatsappConnections
  module Meta
    class DirectTokenConnectionService
      def initialize(account:, access_token:, waba_id:, business_id:, name: nil)
        @account = account
        @access_token = access_token
        @waba_id = waba_id
        @business_id = business_id
        @name = name
      end

      def perform
        validate_params!
        validate_token!
        connection = create_connection
        sync_phone_numbers(connection)
        sync_templates(connection)
        connection
      end

      private

      def validate_params!
        raise ArgumentError, 'access_token is required' if @access_token.blank?
        raise ArgumentError, 'waba_id is required' if @waba_id.blank?
        raise ArgumentError, 'business_id is required' if @business_id.blank?
      end

      def validate_token!
        # Verify the token can access the WABA by fetching phone numbers
        api_client = Whatsapp::FacebookApiClient.new(@access_token)
        response = api_client.fetch_phone_numbers(@waba_id)
        raise 'Invalid token or WABA ID: cannot access phone numbers' unless response['data']
      end

      def create_connection
        WhatsappConnection.create!(
          account: @account,
          provider: 'meta_cloud',
          name: @name || "WABA #{@waba_id}",
          credentials: {
            access_token: @access_token,
            waba_id: @waba_id,
            business_id: @business_id
          },
          status: 'active'
        )
      end

      def sync_phone_numbers(connection)
        WhatsappConnections::Meta::PhoneSyncService.new(connection, @access_token).perform
      end

      def sync_templates(connection)
        WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Template sync failed for connection #{connection.id}: #{e.message}")
      end
    end
  end
end
