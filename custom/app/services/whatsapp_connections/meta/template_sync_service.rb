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
          channel = phone.channel_whatsapp
          next unless channel

          filtered = filter_for_channel(templates, channel)
          channel.update(message_templates: filtered)
        end
      end

      # Filtro por prefixo pra isolamento de templates em WABAs compartilhadas
      # (MS+BC compartilham WABA 735467396201142 → templates bluecare_* vazavam pro UI MS
      # e pra waba_templates do KLaOS via getInbox).
      # Config lida de channel.provider_config['template_filter'] (jsonb Chatwoot padrão):
      #   { "prefix_whitelist": ["bluecare_"] }  → só templates com esses prefixos
      #   { "prefix_blacklist": ["bluecare_"] }  → esconde templates com esses prefixos
      # Sem config → retorna tudo (backward-compat).
      def filter_for_channel(templates, channel)
        cfg = channel.provider_config&.dig('template_filter') || {}
        whitelist = cfg['prefix_whitelist']
        blacklist = cfg['prefix_blacklist']

        out = templates
        if whitelist.is_a?(Array) && whitelist.any?
          out = out.select { |t| whitelist.any? { |p| t['name'].to_s.start_with?(p) } }
        end
        if blacklist.is_a?(Array) && blacklist.any?
          out = out.reject { |t| blacklist.any? { |p| t['name'].to_s.start_with?(p) } }
        end
        out
      end
    end
  end
end
