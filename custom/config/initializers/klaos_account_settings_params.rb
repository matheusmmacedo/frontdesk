# frozen_string_literal: true

# KLaOS — amplia a allow-list de settings do AccountsController.
#
# Upstream permite apenas auto_resolve_* + audio_transcriptions em
# `permitted_settings_attributes` (Api::V1::AccountsController). Sem este
# patch, qualquer setting custom do KLaOS enviada pelo frontend seria
# silenciosamente descartada pelo strong_params.
#
# Chaves KLaOS aceitas em account.settings hoje:
# - :auto_offline_default — toggle "Manter agentes online até logout manual" (ponto 9)
#
# Quando novas features modulares forem adicionadas (item 10 unassigned_label,
# item 2 auto_assign_on_template_send), basta estender esta lista.
module KlaosAccountSettingsParams
  KLAOS_SETTINGS_KEYS = [
    :auto_offline_default,
    :unassigned_label,
    :snooze_reopen_alert,
    :auto_assign_on_template_send
  ].freeze

  private

  def permitted_settings_attributes
    super + KlaosAccountSettingsParams::KLAOS_SETTINGS_KEYS
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Api::V1::AccountsController)
  next if Api::V1::AccountsController.include?(KlaosAccountSettingsParams)

  Api::V1::AccountsController.prepend(KlaosAccountSettingsParams)
  Rails.logger.info '[KlaosAccountSettingsParams] prepended on Api::V1::AccountsController'
end
