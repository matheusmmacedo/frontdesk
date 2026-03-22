# frozen_string_literal: true

# Links a WhatsappPhoneNumber to a new inbox by creating Channel::Whatsapp + Inbox.
# Reuses existing Chatwoot services for webhook setup.
module WhatsappConnections
  module Meta
    class PhoneLinkerService
      def initialize(phone_number_record)
        @phone_number_record = phone_number_record
        @connection = phone_number_record.whatsapp_connection
        @account = phone_number_record.account
      end

      def perform
        validate!
        channel, inbox = create_channel_and_inbox
        setup_webhooks(channel)
        sync_channel_templates(channel)
        @phone_number_record.mark_linked!(inbox: inbox, channel: channel)
        { channel: channel, inbox: inbox }
      end

      private

      def validate!
        raise 'Phone number is already linked' if @phone_number_record.linked?
        raise 'Connection must be meta_cloud' unless @connection.meta_cloud?

        existing = Channel::Whatsapp.find_by(phone_number: @phone_number_record.phone_number)
        raise "Phone number #{@phone_number_record.phone_number} already exists as a channel" if existing
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
