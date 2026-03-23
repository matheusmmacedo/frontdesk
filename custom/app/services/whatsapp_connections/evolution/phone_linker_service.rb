# frozen_string_literal: true

# Links/unlinks an Evolution API phone number to a Chatwoot inbox.
# Creates a Channel::Whatsapp with provider 'default' (will be routed through Evolution).
module WhatsappConnections
  module Evolution
    class PhoneLinkerService
      def initialize(phone_number_record)
        @phone_number_record = phone_number_record
        @connection = phone_number_record.whatsapp_connection
        @account = phone_number_record.account
      end

      def link
        validate_link!
        channel, inbox = create_channel_and_inbox
        configure_evolution_chatwoot_integration(channel, inbox)
        @phone_number_record.mark_linked!(inbox: inbox, channel: channel)
        { channel: channel, inbox: inbox }
      end

      def unlink
        raise 'Phone number is not linked' unless @phone_number_record.linked?

        channel = @phone_number_record.channel_whatsapp
        @phone_number_record.mark_available!
        channel&.destroy!
        true
      end

      private

      def validate_link!
        raise 'Phone number is not available for linking' unless @phone_number_record.available?
        raise 'Phone number has no actual number yet (still pending connection)' if @phone_number_record.phone_number.start_with?('pending_')

        existing = Channel::Whatsapp.find_by(phone_number: @phone_number_record.phone_number)
        raise "Phone number #{@phone_number_record.phone_number} already exists as a channel" if existing
      end

      def create_channel_and_inbox
        ActiveRecord::Base.transaction do
          channel = Channel::Whatsapp.create!(
            account: @account,
            phone_number: @phone_number_record.phone_number,
            provider: 'default',
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
        api_client = WhatsappConnections::Evolution::ApiClient.new
        {
          'api_key' => GlobalConfigService.load('EVOLUTION_API_GLOBAL_KEY', ''),
          'api_base_url' => GlobalConfigService.load('EVOLUTION_API_BASE_URL', ''),
          'instance_name' => @phone_number_record.phone_number_id,
          'source' => 'whatsapp_pool_evolution'
        }
      end

      def inbox_name
        display = @phone_number_record.display_name.presence || @phone_number_record.phone_number
        "#{display} WhatsApp"
      end

      def configure_evolution_chatwoot_integration(channel, inbox)
        api_client = WhatsappConnections::Evolution::ApiClient.new
        frontend_url = GlobalConfigService.load('FRONTEND_URL', '')

        api_client.set_chatwoot_integration(@phone_number_record.phone_number_id, {
          enabled: true,
          account_id: @account.id.to_s,
          token: find_or_create_api_token,
          url: frontend_url,
          sign_msg: true,
          reopen_conversation: true,
          conversation_pending: false,
          inbox_id: inbox.id.to_s
        })
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Evolution Chatwoot integration setup failed: #{e.message}")
      end

      def find_or_create_api_token
        # Use the account's first admin user's access token
        admin_user = @account.account_users.find_by(role: :administrator)&.user
        return '' unless admin_user

        token = admin_user.access_token
        return token.token if token

        admin_user.create_access_token!.token
      end
    end
  end
end
