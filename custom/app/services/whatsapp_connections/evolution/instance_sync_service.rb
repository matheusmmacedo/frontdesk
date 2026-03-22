# frozen_string_literal: true

# Syncs Evolution API instances for a given account's connection.
# Uses account_id prefix to isolate instances per tenant.
module WhatsappConnections
  module Evolution
    class InstanceSyncService
      def initialize(connection)
        @connection = connection
        @account = connection.account
      end

      def perform
        raise ArgumentError, 'Connection must be evolution' unless @connection.evolution?

        api_client = WhatsappConnections::Evolution::ApiClient.new
        all_instances = api_client.fetch_instances

        # Filter instances belonging to this account (by prefix convention)
        account_instances = filter_account_instances(all_instances)
        sync_numbers(account_instances, api_client)
      end

      private

      def instance_prefix
        "account_#{@account.id}_"
      end

      def filter_account_instances(instances)
        instances.select do |inst|
          name = inst.dig('instance', 'instanceName') || inst['instanceName'] || ''
          name.start_with?(instance_prefix)
        end
      end

      def sync_numbers(instances, api_client)
        existing_ids = @connection.whatsapp_phone_numbers.pluck(:phone_number_id)

        instances.each do |inst|
          instance_name = inst.dig('instance', 'instanceName') || inst['instanceName']
          next if instance_name.blank?
          next if existing_ids.include?(instance_name)

          owner = inst.dig('instance', 'owner') || ''
          phone_number = extract_phone(owner)
          connection_status = inst.dig('instance', 'status') || 'unknown'
          profile_name = inst.dig('instance', 'profileName') || instance_name

          @connection.whatsapp_phone_numbers.create!(
            account: @account,
            phone_number: phone_number.presence || "pending_#{instance_name}",
            phone_number_id: instance_name,
            display_name: profile_name,
            status: phone_number.present? ? 'available' : 'pending',
            provider_info: {
              instance_name: instance_name,
              connection_status: connection_status,
              profile_name: profile_name
            }
          )
        end

        # Update status for existing numbers
        @connection.whatsapp_phone_numbers.where.not(phone_number_id: nil).find_each do |phone|
          update_instance_status(phone, api_client)
        end
      end

      def update_instance_status(phone, api_client)
        state = api_client.connection_state(phone.phone_number_id)
        new_status = state.dig('instance', 'state') || state['state'] || 'unknown'

        phone.update(
          provider_info: phone.provider_info.merge('connection_status' => new_status)
        )
      rescue StandardError => e
        Rails.logger.warn("[WHATSAPP_POOL] Could not check status for #{phone.phone_number_id}: #{e.message}")
      end

      def extract_phone(owner_string)
        return '' if owner_string.blank?

        # Evolution stores owner as "5511999999999@s.whatsapp.net"
        number = owner_string.split('@').first
        number.present? ? "+#{number}" : ''
      end
    end
  end
end
