# frozen_string_literal: true

# AUTO-RESOLVE POR INATIVIDADE — DEFAULT DA PLATAFORMA
#
# Upstream cria Account com settings = {} e `auto_resolve_after` nulo. O
# scheduler (Account::ConversationsResolutionSchedulerJob) varre
# `Account.with_auto_resolve`, que filtra exatamente
# `settings->>'auto_resolve_after' IS NOT NULL` — ou seja, conta sem o valor
# NUNCA e varrida. Resultado observado em prod: conversas abertas ha 80 dias
# sem ninguem responder nem resolver, entupindo a caixa e mentindo na metrica
# de "abertas".
#
# Este initializer cuida das contas NOVAS: before_create, a conta ja nasce com
# auto-resolve ligado.
#
# As contas que ja existiam sao tratadas pela migration
# db/migrate/20260802180000_backfill_auto_resolve_defaults.rb. O backfill NAO
# roda no boot: a primeira versao tentou num `Thread.new` dentro do to_prepare
# (padrao copiado do audio_alerts_default.rb) e falhou em todo boot com
# `ActiveRecord::NoDatabaseError: We could not find your database: railway` —
# a thread nasce fora do contexto de conexao do Rails e cai no database.yml
# cru (POSTGRES_* com defaults localhost/chatwoot_production) em vez da
# DATABASE_URL. Ver a migration para o diagnostico completo.
#
# Defaults:
#   auto_resolve_after           = 1440  (24h de inatividade)
#   auto_resolve_ignore_waiting  = true  (NAO fecha quem espera resposta nossa)
#   auto_resolve_label           = 'auto-resolvida-inatividade'
#   auto_resolve_message         = (nao setado de proposito)
#
# Sobre `ignore_waiting`: o scope `resolvable_not_waiting` exige
# `waiting_since IS NULL`. `waiting_since` marca conversa onde o cliente falou
# e ninguem nosso respondeu ainda — pendencia NOSSA. Com a flag ligada essas
# ficam abertas de proposito; fecham so as que ja foram atendidas e esfriaram.
#
# Sobre a etiqueta: sem ela nao da pra distinguir, no relatorio, o que a equipe
# resolveu de verdade do que o robo fechou por silencio. O Label e criado na
# conta pra aparecer no filtro da UI (add_labels sozinho cria so a tag).
#
# Respeita escolha do cliente: aqui e na migration o criterio e CHAVE AUSENTE,
# nao valor nulo. Quem desligar pela UI (Configuracoes -> Geral) grava a chave
# com nil e nao e religado por cima.

module KlaosAutoResolveDefault
  DEFAULTS = {
    'auto_resolve_after' => 1440,
    'auto_resolve_ignore_waiting' => true,
    'auto_resolve_label' => 'auto-resolvida-inatividade'
  }.freeze

  LABEL_TITLE = 'auto-resolvida-inatividade'
  LABEL_COLOR = '#6C757D'

  def self.included(base)
    base.before_create :klaos_apply_auto_resolve_defaults
    base.after_create :klaos_ensure_auto_resolve_label
  end

  def klaos_apply_auto_resolve_defaults
    existing = (settings || {}).stringify_keys
    self.settings = DEFAULTS.merge(existing)
  end

  def klaos_ensure_auto_resolve_label
    KlaosAutoResolveDefault.ensure_label(self)
  end

  # Idempotente: so cria se a conta ainda nao tem a etiqueta.
  def self.ensure_label(account)
    return unless defined?(Label)
    return if account.labels.exists?(title: LABEL_TITLE)

    account.labels.create!(
      title: LABEL_TITLE,
      description: 'Encerrada automaticamente por inatividade',
      color: LABEL_COLOR,
      show_on_sidebar: true
    )
  rescue StandardError => e
    Rails.logger.warn "[AutoResolveDefault] label falhou account=#{account.id}: #{e.message}"
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Account)

  unless Account.include?(KlaosAutoResolveDefault)
    Account.include(KlaosAutoResolveDefault)
    Rails.logger.info '[AutoResolveDefault] hook installed on Account#before_create'
  end
end
