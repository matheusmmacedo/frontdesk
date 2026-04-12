# frozen_string_literal: true

# CRM Bridge Extensions
# Extends Conversation model to enrich webhook payloads with CRM deal data.
# When a conversation has crm_deal_id in custom_attributes, the webhook payload
# includes it so KLaOS can update the deal accordingly.
#
# Also registers custom_attribute_definitions for CRM fields so they show up
# properly in the Frontdesk UI sidebar.

Rails.application.config.after_initialize do
  # Register CRM custom attribute definitions for the Conversation entity.
  # These definitions make the CRM fields appear with proper labels in the sidebar.
  CRM_ATTRIBUTE_DEFINITIONS = [
    { attribute_display_name: 'CRM Deal', attribute_display_type: 'text', attribute_key: 'crm_deal_name',
      attribute_description: 'Nome do deal no KLaOS CRM', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Valor do Deal', attribute_display_type: 'text', attribute_key: 'crm_deal_value',
      attribute_description: 'Valor do deal no CRM', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Estágio', attribute_display_type: 'text', attribute_key: 'crm_deal_stage',
      attribute_description: 'Estágio do pipeline', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Lead Score', attribute_display_type: 'number', attribute_key: 'crm_lead_score',
      attribute_description: 'Score do lead (0-100)', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Pipeline', attribute_display_type: 'text', attribute_key: 'crm_pipeline',
      attribute_description: 'Pipeline do CRM', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Owner do Deal', attribute_display_type: 'text', attribute_key: 'crm_deal_owner',
      attribute_description: 'Responsável pelo deal', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Link do Deal', attribute_display_type: 'link', attribute_key: 'crm_deal_url',
      attribute_description: 'URL para abrir o deal no KLaOS', attribute_model: 'conversation_attribute' },
    # SDR scheduling attributes (KLaOS Leads Ops)
    { attribute_display_name: 'Agendado em', attribute_display_type: 'date', attribute_key: 'scheduled_at',
      attribute_description: 'Data/hora do agendamento feito pelo SDR', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Link do Agendamento', attribute_display_type: 'link', attribute_key: 'scheduling_link',
      attribute_description: 'URL da reunião agendada', attribute_model: 'conversation_attribute' },
    { attribute_display_name: 'Closer Atribuído', attribute_display_type: 'text', attribute_key: 'closer_assigned',
      attribute_description: 'Nome do closer responsável pelo lead', attribute_model: 'conversation_attribute' }
  ].freeze

  # Auto-create CRM attribute definitions for all accounts that have a KLaOS webhook
  # This runs once at boot — idempotent (skips if already exists)
  begin
    Account.find_each do |account|
      # Only create for accounts that have a KLaOS webhook configured
      has_klaos_webhook = account.webhooks.any? { |w| w.url.include?('klaos') }
      next unless has_klaos_webhook

      CRM_ATTRIBUTE_DEFINITIONS.each do |attr_def|
        CustomAttributeDefinition.find_or_create_by(
          account: account,
          attribute_key: attr_def[:attribute_key],
          attribute_model: attr_def[:attribute_model].to_i == 0 ? 1 : attr_def[:attribute_model]
        ) do |cad|
          cad.attribute_display_name = attr_def[:attribute_display_name]
          cad.attribute_display_type = attr_def[:attribute_display_type]
          cad.attribute_description = attr_def[:attribute_description]
        end
      rescue StandardError => e
        Rails.logger.debug("[CRM_BRIDGE] Skipped attribute #{attr_def[:attribute_key]}: #{e.message}")
      end
    end
  rescue StandardError => e
    Rails.logger.info("[CRM_BRIDGE] Could not auto-create CRM attributes at boot: #{e.message}")
  end
end
