# frozen_string_literal: true

# Manages Evolution API instances: create, connect (QR), disconnect, delete.
module WhatsappConnections
  module Evolution
    class InstanceManagerService
      def initialize(connection)
        @connection = connection
        @account = connection.account
        @api_client = WhatsappConnections::Evolution::ApiClient.new
      end

      # Create a new Evolution instance for this account
      # display_name: human-friendly name (used as suffix)
      def create_instance(display_name)
        instance_name = build_instance_name(display_name)

        result = @api_client.create_instance(
          instanceName: instance_name,
          integration: 'WHATSAPP-BAILEYS',
          qrcode: true
        )

        # Configure webhook on Evolution so it forwards events to this Frontdesk instance
        configure_webhook(instance_name)

        phone_record = @connection.whatsapp_phone_numbers.create!(
          account: @account,
          phone_number: "pending_#{instance_name}",
          phone_number_id: instance_name,
          display_name: display_name,
          status: 'pending',
          provider_info: {
            instance_name: instance_name,
            connection_status: 'created'
          }
        )

        { instance: result, phone_number: phone_record }
      end

      # Get QR code to connect an instance
      def connect_instance(phone_number_record)
        instance_name = phone_number_record.phone_number_id
        result = @api_client.connect_instance(instance_name)

        phone_number_record.update!(
          provider_info: phone_number_record.provider_info.merge(
            'connection_status' => 'connecting',
            'qrcode' => result.dig('base64') || result.dig('qrcode', 'base64')
          )
        )

        result
      end

      # Check instance status and update phone number if connected
      def check_status(phone_number_record)
        instance_name = phone_number_record.phone_number_id
        state = @api_client.connection_state(instance_name)
        connection_status = state.dig('instance', 'state') || state['state'] || 'unknown'

        updates = { provider_info: phone_number_record.provider_info.merge('connection_status' => connection_status) }

        # If connected, try to get the actual phone number with retry
        if connection_status == 'open' && phone_number_record.phone_number.start_with?('pending_')
          phone = fetch_phone_with_retry(instance_name)
          if phone.present?
            updates[:phone_number] = phone
            updates[:status] = 'available'
          end
        end

        phone_number_record.update!(updates)
        { status: connection_status, phone_number: phone_number_record }
      end

      # Disconnect (logout) an instance
      def disconnect_instance(phone_number_record)
        @api_client.logout_instance(phone_number_record.phone_number_id)
        phone_number_record.update!(
          provider_info: phone_number_record.provider_info.merge('connection_status' => 'disconnected')
        )
      end

      # Delete an instance entirely
      def delete_instance(phone_number_record)
        # Unlink first if linked
        if phone_number_record.linked?
          WhatsappConnections::Evolution::PhoneLinkerService.new(phone_number_record).unlink
        end

        @api_client.delete_instance(phone_number_record.phone_number_id)
        phone_number_record.destroy!
      end

      private

      # Configure Evolution webhook so messages and status events are forwarded
      def configure_webhook(instance_name)
        frontend_url = GlobalConfigService.load('FRONTEND_URL', '')
        return if frontend_url.blank?

        webhook_url = "#{frontend_url}/webhooks/whatsapp"
        @api_client.set_webhook(instance_name, {
          url: webhook_url,
          webhook_by_events: false,
          webhook_base64: true,
          events: %w[
            MESSAGES_UPSERT
            MESSAGES_UPDATE
            SEND_MESSAGE
            CONNECTION_UPDATE
            QRCODE_UPDATED
          ]
        })
        Rails.logger.info("[EVOLUTION] Webhook configured for #{instance_name}: #{webhook_url}")
      rescue StandardError => e
        Rails.logger.warn("[EVOLUTION] Webhook setup failed for #{instance_name}: #{e.message}")
      end

      def build_instance_name(display_name)
        sanitized = display_name.parameterize(separator: '_')
        "account_#{@account.id}_#{sanitized}_#{SecureRandom.hex(4)}"
      end

      # Retry profile fetch up to 3 times with delay (Evolution may not have profile ready immediately)
      def fetch_phone_with_retry(instance_name, retries: 3, delay: 2)
        retries.times do |attempt|
          sleep(delay) if attempt > 0
          profile = @api_client.fetch_profile(instance_name)
          next unless profile

          owner = profile.dig('owner') || profile.dig('instance', 'owner') || ''
          phone = extract_phone(owner)
          return phone if phone.present?
        end
        ''
      end

      def extract_phone(owner_string)
        return '' if owner_string.blank?

        number = owner_string.split('@').first
        number.present? ? "+#{number}" : ''
      end
    end
  end
end
