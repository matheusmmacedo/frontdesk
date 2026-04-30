# frozen_string_literal: true

# Intercepts WABA template lifecycle webhooks (`message_template_*` fields)
# that the upstream `Webhooks::WhatsappEventsJob` ignores. When Meta changes
# a template's status / category / quality, we want the local cache
# (`WhatsappConnection.message_templates` + each linked `Channel::Whatsapp`)
# to reflect that within seconds — not on the next 3h batch sync. We also
# notify the KLaOS bridge so it can rehydrate `waba_templates` on its side
# (no other way to keep the régua's FK in sync with reality).
#
# Lives directly in `custom/app/jobs/` (not under `concerns/`) so Zeitwerk
# autoloads `WhatsappTemplateEventsHandler` without needing a `collapse`
# directive on a custom path. Prepended at boot via
# `custom/config/initializers/whatsapp_template_events_extension.rb`.
module WhatsappTemplateEventsHandler
  extend ActiveSupport::Concern

  TEMPLATE_FIELD_PREFIX = 'message_template_'

  def perform(params = {})
    return handle_template_event(params) if template_event?(params)

    super
  end

  private

  def template_event?(params)
    field = params.dig(:entry, 0, :changes, 0, :field).to_s
    field.start_with?(TEMPLATE_FIELD_PREFIX)
  end

  def handle_template_event(params)
    waba_id = params.dig(:entry, 0, :id).to_s
    change_value = params.dig(:entry, 0, :changes, 0, :value) || {}
    field = params.dig(:entry, 0, :changes, 0, :field).to_s

    Rails.logger.info(
      "[WHATSAPP_POOL] template event #{field} for WABA=#{waba_id} " \
      "name=#{change_value[:message_template_name]} event=#{change_value[:event]}"
    )

    connection = WhatsappConnection.find_by(waba_id: waba_id)
    if connection.blank?
      Rails.logger.warn("[WHATSAPP_POOL] template event ignored: no WhatsappConnection for WABA #{waba_id}")
      return
    end

    refresh_local_cache(connection)
    alert_if_critical(connection, field, change_value)
    notify_klaos_bridge(connection, field, change_value)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP_POOL] template event handler failed: #{e.class}: #{e.message}")
    raise # let ApplicationJob's retry kick in
  end

  def refresh_local_cache(connection)
    WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
  end

  def alert_if_critical(connection, field, change)
    # UTILITY → MARKETING: bloqueador potencial pra régua de cobrança
    return unless field == 'message_template_category_update' &&
                  change[:previous_category] == 'UTILITY' &&
                  change[:new_category] == 'MARKETING'

    msg = "Template #{change[:message_template_name]} reclassified UTILITY→MARKETING " \
          "by Meta (WABA=#{connection.waba_id})"
    Rails.logger.warn("[WHATSAPP_POOL] #{msg}")
    return unless defined?(Sentry)

    Sentry.capture_message(msg, level: :warning, extra: {
                             waba_id: connection.waba_id,
                             template_id: change[:message_template_id],
                             template_name: change[:message_template_name]
                           })
  end

  def notify_klaos_bridge(connection, field, change)
    bridge_url = ENV.fetch('KLAOS_BRIDGE_URL', nil)
    bridge_secret = ENV.fetch('FRONTDESK_BRIDGE_SECRET', nil)
    return if bridge_url.blank? || bridge_secret.blank?

    payload = {
      type: 'waba_template_changed',
      waba_id: connection.waba_id,
      field: field,
      template_id: change[:message_template_id],
      template_name: change[:message_template_name],
      template_language: change[:message_template_language],
      event: change[:event],
      previous_category: change[:previous_category],
      new_category: change[:new_category],
      reason: change[:reason]
    }.compact

    KlaosBridgeWebhookJob.perform_later("#{bridge_url}/api/webhooks/klaos/bridge-event", payload, bridge_secret)
  end
end
