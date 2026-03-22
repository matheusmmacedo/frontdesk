# frozen_string_literal: true

# Extends Channel::Whatsapp with WhatsappPhoneNumber association
# This runs after all models are loaded, adding the relationship
# without modifying the upstream Channel::Whatsapp file.
Rails.application.config.after_initialize do
  Channel::Whatsapp.class_eval do
    has_one :whatsapp_phone_number, class_name: 'WhatsappPhoneNumber', foreign_key: :channel_whatsapp_id, dependent: :nullify,
                                    inverse_of: :channel_whatsapp

    def whatsapp_connection
      whatsapp_phone_number&.whatsapp_connection
    end

    # Sync templates from the parent WhatsappConnection (if linked via pool)
    # Falls back to the standard per-channel sync if not linked
    def sync_templates_from_connection
      connection = whatsapp_connection
      return sync_templates unless connection&.meta_cloud?

      update(message_templates: connection.message_templates) if connection.message_templates.present?
    end
  end

  # Extend Account with whatsapp_connections association
  Account.class_eval do
    has_many :whatsapp_connections, dependent: :destroy
    has_many :whatsapp_phone_numbers, dependent: :destroy
  end
end
