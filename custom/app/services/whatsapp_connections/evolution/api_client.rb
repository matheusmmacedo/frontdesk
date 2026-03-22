# frozen_string_literal: true

# HTTP client for Evolution API v2.
# Reads global config from InstallationConfig (set by Super Admin).
module WhatsappConnections
  module Evolution
    class ApiClient
      class EvolutionApiError < StandardError; end

      def initialize
        @base_url = GlobalConfigService.load('EVOLUTION_API_BASE_URL', '').chomp('/')
        @global_key = GlobalConfigService.load('EVOLUTION_API_GLOBAL_KEY', '')

        raise EvolutionApiError, 'Evolution API not configured. Set EVOLUTION_API_BASE_URL and EVOLUTION_API_GLOBAL_KEY in Super Admin.' if @base_url.blank? || @global_key.blank?
      end

      # List all instances
      def fetch_instances
        response = get('/instance/fetchInstances')
        response.parsed_response || []
      end

      # Get connection state of an instance
      def connection_state(instance_name)
        response = get("/instance/connectionState/#{instance_name}")
        response.parsed_response
      end

      # Create a new instance
      # params: { instanceName:, integration:, qrcode:, ... }
      def create_instance(params)
        response = post('/instance/create', params)
        response.parsed_response
      end

      # Connect instance (returns QR code)
      def connect_instance(instance_name)
        response = get("/instance/connect/#{instance_name}")
        response.parsed_response
      end

      # Disconnect instance
      def logout_instance(instance_name)
        response = delete("/instance/logout/#{instance_name}")
        response.parsed_response
      end

      # Delete instance
      def delete_instance(instance_name)
        response = delete("/instance/delete/#{instance_name}")
        response.parsed_response
      end

      # Send text message
      def send_text(instance_name, phone, text)
        post("/message/sendText/#{instance_name}", {
               number: phone,
               text: text
             })
      end

      # Fetch instance profile (phone number, name, etc.)
      def fetch_profile(instance_name)
        response = get("/instance/fetchProfile/#{instance_name}")
        response.parsed_response
      rescue StandardError
        nil
      end

      # Set Chatwoot integration on Evolution side
      def set_chatwoot_integration(instance_name, params)
        post("/chatwoot/set/#{instance_name}", params)
      end

      private

      def get(path)
        response = HTTParty.get(
          "#{@base_url}#{path}",
          headers: auth_headers
        )
        handle_response(response)
      end

      def post(path, body = {})
        response = HTTParty.post(
          "#{@base_url}#{path}",
          headers: auth_headers.merge('Content-Type' => 'application/json'),
          body: body.to_json
        )
        handle_response(response)
      end

      def delete(path)
        response = HTTParty.delete(
          "#{@base_url}#{path}",
          headers: auth_headers
        )
        handle_response(response)
      end

      def auth_headers
        { 'apikey' => @global_key }
      end

      def handle_response(response)
        return response if response.success?

        error_msg = begin
          response.parsed_response&.dig('message') || response.body
        rescue StandardError
          response.body
        end
        raise EvolutionApiError, "Evolution API error (#{response.code}): #{error_msg}"
      end
    end
  end
end
