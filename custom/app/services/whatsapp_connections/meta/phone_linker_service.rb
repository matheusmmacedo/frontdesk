# frozen_string_literal: true

# Links a WhatsappPhoneNumber to a new inbox by creating Channel::Whatsapp + Inbox.
# Reuses existing Chatwoot services for webhook setup.
module WhatsappConnections
  module Meta
    class PhoneLinkerService
      def initialize(phone_number_record, inbox_name: nil)
        @phone_number_record = phone_number_record
        @connection = phone_number_record.whatsapp_connection
        @account = phone_number_record.account
        @custom_inbox_name = inbox_name
      end

      def perform
        validate!
        cleanup_orphan_channel!
        channel, inbox = create_channel_and_inbox
        # NOTE: Webhook setup is handled automatically by Channel::Whatsapp
        # after_commit hook when source != 'embedded_signup' (see should_auto_setup_webhooks?).
        # Since we set source='whatsapp_pool', webhooks ARE auto-configured with Meta.
        sync_channel_templates(channel)
        @phone_number_record.mark_linked!(inbox: inbox, channel: channel)
        { channel: channel, inbox: inbox }
      end

      private

      def validate!
        raise 'Phone number is already linked' if @phone_number_record.linked?
        raise 'Connection must be meta_cloud' unless @connection.meta_cloud?
      end

      # If a previous channel exists for this phone (orphan from failed unlink), clean it up
      def cleanup_orphan_channel!
        existing = Channel::Whatsapp.find_by(phone_number: @phone_number_record.phone_number)
        return unless existing

        Rails.logger.warn("[WHATSAPP_POOL] Cleaning up orphan channel for #{@phone_number_record.phone_number}")
        existing.inbox&.destroy
        existing.destroy
      end

      def create_channel_and_inbox
        ActiveRecord::Base.transaction do
          channel = Channel::Whatsapp.create!(
            account: @account,
            phone_number: @phone_number_record.phone_number,
            provider: 'whatsapp_cloud',
            provider_config: build_provider_config
          )

          inbox = Inbox.create!(
            account: @account,
            name: inbox_name,
            channel: channel
          )

          [channel, inbox]
        end
      end

      def build_provider_config
        {
          'api_key' => @connection.access_token,
          'phone_number_id' => @phone_number_record.phone_number_id,
          'business_account_id' => @connection.waba_id,
          'webhook_verify_token' => SecureRandom.hex(16),
          'source' => 'whatsapp_pool'
        }
      end

      def inbox_name
        return @custom_inbox_name if @custom_inbox_name.present?

        display = @phone_number_record.display_name.presence || @phone_number_record.phone_number
        "#{display} WhatsApp"
      end

      def setup_webhooks(channel)
        channel.setup_webhooks
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Webhook setup failed for #{channel.phone_number}: #{e.message}")
      end

      def sync_channel_templates(channel)
        return unless @connection.message_templates.present?

        channel.update(message_templates: @connection.message_templates)
      end
    end
  end
end
