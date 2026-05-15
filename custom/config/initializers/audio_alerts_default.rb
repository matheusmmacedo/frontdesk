# frozen_string_literal: true

# AUDIO ALERTS DEFAULT ON
#
# Chatwoot upstream cria User com ui_settings = {} (default do schema).
# Front-end lê chaves ausentes como falsy → alarme sonoro fica DESLIGADO
# por padrão pra todo agente novo. Operacionalmente isso é ruim: novo
# atendente entra na conta, recebe conversa, não escuta nada, achamos
# que o sistema "não notifica".
#
# Duas camadas de proteção:
#   1. before_create — usuário novo nasce com defaults ON.
#   2. backfill no boot — varre users existentes sem a chave e aplica
#      os defaults. Idempotente (UPDATE só quem precisa) e roda uma vez
#      por boot.
#
# Combo:
#   enable_audio_alerts                           = 'all'   → todo evento
#   always_play_audio_alert                       = true    → aba ativa também
#   alert_if_unread_assigned_conversation_exist   = false   → SEM repetição 30s (invasivo)
#   notification_tone                             = 'ding'  → tom padrão
#
# Usuário sempre pode desligar em Perfil → Notificações de áudio (não
# sobrescrevemos chaves que o próprio user já configurou).

module KlaosAudioAlertsDefault
  AUDIO_DEFAULTS = {
    'enable_audio_alerts' => 'all',
    'always_play_audio_alert' => true,
    'alert_if_unread_assigned_conversation_exist' => false,
    'notification_tone' => 'ding'
  }.freeze

  def self.included(base)
    base.before_create :klaos_apply_audio_alert_defaults
  end

  def klaos_apply_audio_alert_defaults
    existing = (ui_settings || {}).stringify_keys
    self.ui_settings = AUDIO_DEFAULTS.merge(existing)
  end

  # Backfill em users existentes — varre quem não tem a chave essencial
  # e aplica os defaults preservando o resto do ui_settings. Roda uma vez
  # por boot do processo (cacheado por Rails.cache pra não brigar entre
  # web/worker simultâneos).
  def self.backfill_existing_users
    return unless defined?(User)

    cache_key = 'klaos:audio_alerts_backfilled_v1'
    return if Rails.cache.read(cache_key)

    affected = User.where("NOT (ui_settings ? 'enable_audio_alerts')")
                   .or(User.where(ui_settings: nil))
                   .or(User.where(ui_settings: {}))

    count = 0
    affected.find_each do |u|
      existing = (u.ui_settings || {}).stringify_keys
      next if existing.key?('enable_audio_alerts')
      u.update_columns(ui_settings: AUDIO_DEFAULTS.merge(existing))
      count += 1
    end

    Rails.cache.write(cache_key, true, expires_in: 1.hour)
    Rails.logger.info "[AudioAlertsDefault] backfill aplicou defaults em #{count} users" if count.positive?
  rescue StandardError => e
    Rails.logger.error "[AudioAlertsDefault] backfill falhou: #{e.class}: #{e.message}"
  end
end

Rails.application.config.to_prepare do
  next unless defined?(User)

  unless User.include?(KlaosAudioAlertsDefault)
    User.include(KlaosAudioAlertsDefault)
    Rails.logger.info '[AudioAlertsDefault] hook installed on User#before_create'
  end

  # Backfill assíncrono — não bloqueia boot. Roda em outro thread pra dar
  # tempo do app subir e responder healthcheck.
  Thread.new do
    sleep 5
    KlaosAudioAlertsDefault.backfill_existing_users
  end
end
