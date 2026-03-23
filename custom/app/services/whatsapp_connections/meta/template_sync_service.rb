# frozen_string_literal: true

# Syncs message templates from Meta Graph API to the WhatsappConnection.
# Then propagates templates to all linked channels.
module WhatsappConnections
  module Meta
    class TemplateSyncService
      def initialize(connection)
        @connection = connection
      end

      def perform
        raise ArgumentError, 'Connection must be meta_cloud' unless @connection.meta_cloud?

        templates = fetch_all_templates
        @connection.update!(message_templates: templates)
        @connection.mark_templates_updated
        propagate_to_channels(templates)
        templates
      end

      private

      def fetch_all_templates
        api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
        base_url = GlobalConfigService.load('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
        url = "#{base_url}/#{api_version}/#{@connection.waba_id}/message_templates?access_token=#{@connection.access_token}"

        templates = []
        loop do
          response = HTTParty.get(url)
          raise "Template fetch failed: #{response.body}" unless response.success?

          data = response.parsed_response
          templates.concat(data['data'] || [])

          url = data.dig('paging', 'next')
          break if url.blank?
        end

        templates
      end

      def propagate_to_channels(templates)
        @connection.linked_phone_numbers.includes(:channel_whatsapp).find_each do |phone|
          phone.channel_whatsapp&.update(message_templates: templates)
        end
      end
    end
  end
end
