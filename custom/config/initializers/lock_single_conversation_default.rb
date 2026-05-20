# frozen_string_literal: true

# LOCK TO SINGLE CONVERSATION — DEFAULT GLOBAL
#
# Chatwoot upstream cria Inbox com lock_to_single_conversation = false (default
# do schema). Resultado: toda vez que uma conversa é resolvida e o cliente volta
# a falar, nasce uma conversa NOVA. O histórico do contato fica fragmentado em
# várias conversas separadas (ruim pro atendimento: "perdi o contexto", e ruim
# pra IA Lara que precisa do fio da meada).
#
# Decisão KLaOS: TODA caixa acumula num thread único por contato (estilo
# WhatsApp). Cliente que volta cai na MESMA conversa (o set_conversation do
# incoming usa @contact_inbox.conversations.last quando lock está ON).
#
# Duas camadas:
#   1. before_create — caixa nova nasce com lock ON.
#   2. backfill ÚNICO (não recorrente) — liga o lock em todas as caixas que já
#      existem, UMA vez. Guardado por InstallationConfig pra não brigar com
#      caixas que um admin queira deixar como exceção (OFF) depois.
#
# Admin ainda pode desligar manualmente uma caixa específica em
# Configurações → Caixa de entrada (não guardamos o update; só o default de
# criação e o backfill inicial).
#
# Limitação nativa: o lock NÃO funde conversas passadas que já existem soltas.
# Ele só passa a acumular daqui pra frente. O histórico antigo unificado é
# mostrado pela tela custom KlaosTimeline.

module KlaosLockSingleConversationDefault
  BACKFILL_FLAG = 'KLAOS_LOCK_SINGLE_CONV_BACKFILLED'

  def self.included(base)
    base.before_create :klaos_force_lock_single_conversation
  end

  def klaos_force_lock_single_conversation
    # Coluna é NOT NULL default false → caixa nova chega aqui com false a menos
    # que alguém tenha setado true explicitamente. Forçamos true pra ser o
    # default global. (Exceções: admin desliga depois, via update normal.)
    self.lock_to_single_conversation = true unless lock_to_single_conversation
  end

  # Backfill UMA vez. Idempotente via flag persistente em InstallationConfig —
  # não roda de novo em boots futuros, pra não reverter exceções manuais.
  def self.backfill_existing_inboxes
    return unless defined?(Inbox) && defined?(InstallationConfig)

    flag = InstallationConfig.find_by(name: BACKFILL_FLAG)
    return if flag && [true, 'true'].include?(flag.value)

    count = Inbox.where(lock_to_single_conversation: false)
                 .update_all(lock_to_single_conversation: true)

    InstallationConfig.find_or_initialize_by(name: BACKFILL_FLAG)
                      .tap { |c| c.value = true; c.save! }
    GlobalConfig.clear_cache if defined?(GlobalConfig)

    Rails.logger.info "[LockSingleConv] backfill ligou lock em #{count} inboxes (one-time)"
  rescue StandardError => e
    Rails.logger.error "[LockSingleConv] backfill falhou: #{e.class}: #{e.message}"
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Inbox)

  unless Inbox.include?(KlaosLockSingleConversationDefault)
    Inbox.include(KlaosLockSingleConversationDefault)
    Rails.logger.info '[LockSingleConv] hook installed on Inbox#before_create'
  end

  # Backfill assíncrono — não bloqueia boot/healthcheck.
  Thread.new do
    sleep 5
    KlaosLockSingleConversationDefault.backfill_existing_inboxes
  end
end
