# frozen_string_literal: true

# AUTO-RESOLVE TAMBEM EM `pending`
#
# O auto-resolve nativo so enxerga `open`:
#
#   scope :resolvable_not_waiting, ->(min) {
#     open.where('last_activity_at < ? AND waiting_since IS NULL', ...) }
#
# So que o nosso fluxo de cobranca joga a conversa exatamente para fora desse
# alcance: o KLaOS dispara o template e marca a conversa como pendente
# ("Conversa foi marcada como pendente por Klaus"). Cliente que nao responde
# fica ali para sempre — invisivel para a regra, para a metrica de abertas e
# para quem olha a caixa.
#
# Medido em PROD 02/08, DEPOIS de ligar o auto-resolve:
#
#   conta  9 Mais Saude  39 pending, 39 (100%) paradas ha +24h, a mais antiga 68d
#   conta 10 GMB         27 pending, 27 (100%) paradas ha +24h, a mais antiga 143d
#   conta 11 Aupes       12 pending, 12 (100%) paradas ha +24h, a mais antiga 46d
#
# Caso que trouxe o assunto: conv 1251 (conta 9), template cobr_d5_lembrete
# enviado, sem resposta, 30 dias parada, status `pending`.
#
# ARMADILHA — NAO usar toggle_status
# O job nativo chama `conversation.toggle_status`, e ele faz (conversation.rb):
#
#   self.status = open? ? :resolved : :open
#   self.status = :open if pending? || snoozed?     # <-- aqui
#
# Ou seja: em `pending` o toggle REABRE. Incluir pending no scope do job
# nativo produziria o oposto do desejado — a conversa voltaria para `open`
# carimbada com a etiqueta de "auto-resolvida". Por isso este initializer
# resolve explicitamente, em vez de alternar.
#
# ESCOPO: estritamente aditivo. Roda DEPOIS do super, que continua tratando as
# `open` exatamente como antes. Mesmos criterios do nativo — janela
# `auto_resolve_after`, `auto_resolve_ignore_waiting`, etiqueta,
# `auto_resolve_message` e o teto de BULK_ACTIONS_LIMIT por rodada.
#
# Desligavel por conta: `settings['klaos_auto_resolve_include_pending'] = false`.

module KlaosAutoResolvePending
  def perform(account:)
    super

    begin
      klaos_resolver_pendentes(account)
    rescue StandardError => e
      # rescue restrito a ESTA etapa. Se envolvesse o super tambem, uma falha
      # do job nativo sumiria no log em vez de estourar e ser reenfileirada.
      Rails.logger.error "[AutoResolvePending] falhou account=#{account.id}: #{e.class}: #{e.message}"
    end
  end

  private

  def klaos_resolver_pendentes(account)
    return unless klaos_pending_habilitado?(account)

    minutos = account.auto_resolve_after.to_i
    return if minutos.zero?

    escopo = account.conversations
                    .pending
                    .where('last_activity_at < ?', Time.now.utc - minutos.minutes)
                    .where.not(contact_id: nil)
    escopo = escopo.where(waiting_since: nil) if account.auto_resolve_ignore_waiting

    total = 0
    escopo.limit(Limits::BULK_ACTIONS_LIMIT).each do |conversation|
      if account.auto_resolve_message.present?
        ::MessageTemplates::Template::AutoResolve.new(conversation: conversation).perform
      end
      conversation.add_labels(account.auto_resolve_label) if account.auto_resolve_label.present?
      conversation.update(status: :resolved)
      total += 1
    end

    Rails.logger.info "[AutoResolvePending] resolveu #{total} pending account=#{account.id}" if total.positive?
  end

  def klaos_pending_habilitado?(account)
    (account.settings || {})['klaos_auto_resolve_include_pending'] != false
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversations::ResolutionJob)

  # ancestors.include?, nao include?: o segundo nao e confiavel para modulo
  # PREPENDED, e um prepend duplicado empilharia dois supers.
  unless Conversations::ResolutionJob.ancestors.include?(KlaosAutoResolvePending)
    Conversations::ResolutionJob.prepend(KlaosAutoResolvePending)
    Rails.logger.info '[AutoResolvePending] prepended on Conversations::ResolutionJob'
  end
end
