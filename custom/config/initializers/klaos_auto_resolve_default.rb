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
# Este initializer torna o comportamento padrao da plataforma, em duas camadas
# (mesmo desenho do audio_alerts_default.rb):
#   1. before_create — conta nova ja nasce com auto-resolve ligado.
#   2. backfill no boot — aplica nas contas existentes que nunca configuraram.
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
# Respeita escolha do cliente: o criterio e CHAVE AUSENTE, nao valor nulo. Quem
# desligar pela UI (Configuracoes -> Geral) grava a chave com nil e o backfill
# nao religa por cima.

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

  # Backfill nas contas existentes. Aplica so onde a chave esta AUSENTE —
  # quem ja configurou (inclusive quem desligou de proposito) fica intacto.
  # Roda uma vez por boot, cacheado pra web e worker nao brigarem.
  def self.backfill_existing_accounts
    return unless defined?(Account)

    cache_key = 'klaos:auto_resolve_backfilled_v1'
    return if Rails.cache.read(cache_key)

    Rails.cache.write(cache_key, true, expires_in: 1.hour)

    count = 0
    Account.where("NOT (settings ? 'auto_resolve_after')").find_each do |account|
      existing = (account.settings || {}).stringify_keys
      next if existing.key?('auto_resolve_after')

      account.update_columns(settings: DEFAULTS.merge(existing))
      ensure_label(account)
      count += 1
    end

    Rails.logger.info "[AutoResolveDefault] backfill aplicou defaults em #{count} contas" if count.positive?
  rescue StandardError => e
    Rails.logger.error "[AutoResolveDefault] backfill falhou: #{e.class}: #{e.message}"
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Account)

  unless Account.include?(KlaosAutoResolveDefault)
    Account.include(KlaosAutoResolveDefault)
    Rails.logger.info '[AutoResolveDefault] hook installed on Account#before_create'
  end

  # Assincrono pra nao segurar o boot/healthcheck.
  Thread.new do
    sleep 5
    KlaosAutoResolveDefault.backfill_existing_accounts
  end
end
