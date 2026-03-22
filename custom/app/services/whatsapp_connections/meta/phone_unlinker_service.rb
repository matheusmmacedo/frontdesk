# frozen_string_literal: true

# Unlinks a WhatsappPhoneNumber from its inbox by destroying Channel::Whatsapp + Inbox.
module WhatsappConnections
  module Meta
    class PhoneUnlinkerService
      def initialize(phone_number_record)
        @phone_number_record = phone_number_record
      end

      def perform
        raise 'Phone number is not linked' unless @phone_number_record.linked?

        channel = @phone_number_record.channel_whatsapp
        inbox = @phone_number_record.inbox

        # Mark as available first to clear FKs before destroy
        @phone_number_record.mark_available!

        # Destroy inbox first (sync, not async), then channel
        inbox&.destroy
        channel&.destroy

        true
      end
    end
  end
end
