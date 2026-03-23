# frozen_string_literal: true

# Fetches all phone numbers from a Meta WABA and syncs them as WhatsappPhoneNumbers.
# Reuses the existing FacebookApiClient.fetch_phone_numbers.
module WhatsappConnections
  module Meta
    class PhoneSyncService
      def initialize(connection, access_token = nil)
        @connection = connection
        @access_token = access_token || connection.access_token
      end

      def perform
        raise ArgumentError, 'Connection must be meta_cloud' unless @connection.meta_cloud?

        api_client = Whatsapp::FacebookApiClient.new(@access_token)
        response = api_client.fetch_phone_numbers(@connection.waba_id)
        phone_numbers_data = response['data'] || []

        sync_numbers(phone_numbers_data)
      end

      private

      def sync_numbers(phone_numbers_data)
        existing_ids = @connection.whatsapp_phone_numbers.pluck(:phone_number_id)
        remote_ids = phone_numbers_data.map { |p| p['id'] }

        # Create new numbers
        phone_numbers_data.each do |phone_data|
          next if existing_ids.include?(phone_data['id'])

          sanitized_number = sanitize_phone(phone_data['display_phone_number'])

          @connection.whatsapp_phone_numbers.create!(
            account: @connection.account,
            phone_number: "+#{sanitized_number}",
            phone_number_id: phone_data['id'],
            display_name: phone_data['verified_name'] || phone_data['display_phone_number'],
            status: 'available',
            provider_info: {
              quality_rating: phone_data['quality_rating'],
              code_verification_status: phone_data['code_verification_status'],
              verified_name: phone_data['verified_name'],
              name_status: phone_data['name_status']
            }
          )
        end

        # Mark removed numbers (that aren't linked) as error
        removed_ids = existing_ids - remote_ids
        @connection.whatsapp_phone_numbers
                   .where(phone_number_id: removed_ids, status: 'available')
                   .update_all(status: 'error') # rubocop:disable Rails/SkipsModelValidations
      end

      def sanitize_phone(phone_number)
        return phone_number if phone_number.blank?

        phone_number.gsub(/[\s\-\(\)\.\+]/, '').strip
      end
    end
  end
end
