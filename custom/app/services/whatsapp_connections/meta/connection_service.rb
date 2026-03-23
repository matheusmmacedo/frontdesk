# frozen_string_literal: true

# Creates a WhatsappConnection for Meta Cloud API after OAuth.
# Reuses the existing FacebookApiClient for token exchange.
module WhatsappConnections
  module Meta
    class ConnectionService
      def initialize(account:, code:, waba_id:, business_id:)
        @account = account
        @code = code
        @waba_id = waba_id
        @business_id = business_id
      end

      def perform
        validate_params!
        access_token = exchange_token
        validate_token(access_token)
        connection = create_connection(access_token)
        sync_phone_numbers(connection, access_token)
        sync_templates(connection)
        connection
      end

      private

      def validate_params!
        raise ArgumentError, 'code is required' if @code.blank?
        raise ArgumentError, 'waba_id is required' if @waba_id.blank?
        raise ArgumentError, 'business_id is required' if @business_id.blank?
      end

      def exchange_token
        Whatsapp::TokenExchangeService.new(@code).perform
      end

      def validate_token(access_token)
        Whatsapp::TokenValidationService.new(access_token, @waba_id).perform
      end

      def create_connection(access_token)
        WhatsappConnection.create!(
          account: @account,
          provider: 'meta_cloud',
          name: "WABA #{@waba_id}",
          credentials: {
            access_token: access_token,
            waba_id: @waba_id,
            business_id: @business_id
          },
          status: 'active'
        )
      end

      def sync_phone_numbers(connection, access_token)
        WhatsappConnections::Meta::PhoneSyncService.new(connection, access_token).perform
      end

      def sync_templates(connection)
        WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Template sync failed for connection #{connection.id}: #{e.message}")
      end
    end
  end
end
