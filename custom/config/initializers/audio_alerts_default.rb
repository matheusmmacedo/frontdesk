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
#   1. before_create — usuário novo nasce com defaults ON (aqui).
#   2. backfill nos users existentes — em
#      db/migrate/20260802180100_backfill_audio_alert_defaults.rb.
#      Ficava neste arquivo, num Thread no boot, e nunca chegou a rodar;
#      o porquê está registrado mais abaixo e na migration.
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

  # O backfill em users existentes ficava AQUI, num `Thread.new` disparado no
  # to_prepare. NUNCA FUNCIONOU: a thread nasce fora do contexto de conexão do
  # Rails e cai no database.yml cru (POSTGRES_* com defaults localhost /
  # chatwoot_production) em vez da DATABASE_URL, morrendo em todo boot com
  #
  #   [AudioAlertsDefault] backfill falhou: ActiveRecord::NoDatabaseError:
  #     We could not find your database: railway
  #
  # O `rescue` transformava isso em uma linha de log que ninguém lia, então a
  # camada 2 parecia existir e não existia — agente antigo seguiu sem som.
  # Descoberto em 02/08/2026 ao copiar este mesmo padrão para o auto-resolve.
  #
  # Agora é db/migrate/20260802180100_backfill_audio_alert_defaults.rb, que
  # roda no preDeployCommand com o ambiente inteiro montado.
end

Rails.application.config.to_prepare do
  next unless defined?(User)

  unless User.include?(KlaosAudioAlertsDefault)
    User.include(KlaosAudioAlertsDefault)
    Rails.logger.info '[AudioAlertsDefault] hook installed on User#before_create'
  end
end
