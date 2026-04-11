# frozen_string_literal: true

# CRUD operations for WhatsApp message templates via Meta Graph API.
# After each mutation, re-syncs templates to keep local state up to date.
module WhatsappConnections
  module Meta
    class TemplateCrudService
      def initialize(connection)
        @connection = connection
        @api_version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
        @base_url = GlobalConfigService.load('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
      end

      # Create a new message template
      # params: { name:, language:, category:, components: [] }
      def create_template(params)
        response = HTTParty.post(
          "#{@base_url}/#{@api_version}/#{@connection.waba_id}/message_templates",
          headers: auth_headers,
          body: params.to_json
        )
        handle_response(response, 'Create template failed')
        sync_after_mutation
        response.parsed_response
      end

      # Update an existing template
      # template_id: the Meta template ID
      # params: { components: [] } (only components can be updated)
      def update_template(template_id, params)
        response = HTTParty.post(
          "#{@base_url}/#{@api_version}/#{template_id}",
          headers: auth_headers,
          body: params.to_json
        )
        handle_response(response, 'Update template failed')
        sync_after_mutation
        response.parsed_response
      end

      # Delete a template by name
      def delete_template(template_name)
        response = HTTParty.delete(
          "#{@base_url}/#{@api_version}/#{@connection.waba_id}/message_templates",
          headers: auth_headers,
          query: { name: template_name }
        )
        handle_response(response, 'Delete template failed')
        sync_after_mutation
        response.parsed_response
      end

      private

      def auth_headers
        {
          'Authorization' => "Bearer #{@connection.access_token}",
          'Content-Type' => 'application/json'
        }
      end

      def handle_response(response, error_prefix)
        return if response.success?

        error_body = response.parsed_response
        # Meta returns detailed user-facing messages in error_user_msg/error_user_title
        user_msg = error_body&.dig('error', 'error_user_msg')
        user_title = error_body&.dig('error', 'error_user_title')
        generic_msg = error_body&.dig('error', 'message')
        error_code = error_body&.dig('error', 'code')

        detail = user_msg || user_title || generic_msg || response.body
        raise "#{detail} (#{error_code || response.code})"
      end

      def sync_after_mutation
        WhatsappConnections::Meta::TemplateSyncService.new(@connection).perform
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP_POOL] Post-mutation template sync failed: #{e.message}")
      end
    end
  end
end
