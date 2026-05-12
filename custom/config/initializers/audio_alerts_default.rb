# frozen_string_literal: true

# AUDIO ALERTS DEFAULT ON
#
# Chatwoot upstream cria User com ui_settings = {} (default do schema).
# Front-end lê chaves ausentes como falsy → alarme sonoro fica DESLIGADO
# por padrão pra todo agente novo. Operacionalmente isso é ruim: novo
# atendente entra na conta, recebe conversa, não escuta nada, achamos
# que o sistema "não notifica".
#
# Esse hook injeta os defaults ON no momento da criação do User. Não
# sobrescreve nada que já tenha sido setado explicitamente (defaults
# perdem do que veio no payload), então criação manual via console com
# ui_settings custom continua respeitada.
#
# Combo:
#   enable_audio_alerts                           = 'all'   → todo evento
#   always_play_audio_alert                       = true    → aba ativa também
#   alert_if_unread_assigned_conversation_exist   = true    → repete 30s
#   notification_tone                             = 'ding'  → tom padrão
#
# Usuário sempre pode desligar em Perfil → Notificações de áudio.

module KlaosAudioAlertsDefault
  AUDIO_DEFAULTS = {
    'enable_audio_alerts' => 'all',
    'always_play_audio_alert' => true,
    'alert_if_unread_assigned_conversation_exist' => true,
    'notification_tone' => 'ding'
  }.freeze

  def self.included(base)
    base.before_create :klaos_apply_audio_alert_defaults
  end

  def klaos_apply_audio_alert_defaults
    existing = (ui_settings || {}).stringify_keys
    self.ui_settings = AUDIO_DEFAULTS.merge(existing)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(User)
  next if User.include?(KlaosAudioAlertsDefault)

  User.include(KlaosAudioAlertsDefault)
  Rails.logger.info '[AudioAlertsDefault] hook installed on User#before_create'
end
