# frozen_string_literal: true

# AUTO-RESOLVE NAO ENCOSTA EM CONVERSA COM ATENDENTE RESPONSAVEL
#
# INCIDENTE 02/08/2026 — o auto-resolve fechou conversa que estava atribuida a
# gente de verdade. Na conta 9 (Mais Saude), das 81 conversas que ele encerrou,
# 67 tinham assignee humano: Gustavo, Yasmin e outros. Contas 10 e 12: 26 e 12,
# todas atribuidas.
#
# CAUSA: o scope nativo olha inatividade e `waiting_since`, e nada mais.
#
#   scope :resolvable_not_waiting, ->(min) {
#     open.where('last_activity_at < ? AND waiting_since IS NULL', ...) }
#
# `waiting_since` responde "o cliente esta esperando resposta nossa?" — NAO
# responde "tem alguem cuidando disso?". Uma conversa que o atendente ja
# respondeu tem `waiting_since` nulo e, ficando 24h parada, virava alvo. Do
# ponto de vista do atendente, a conversa dele sumiu da caixa sozinha.
#
# REGRA: conversa com atendente responsavel (`assignee_id`) NAO e encerrada por
# inatividade, ponto. Quem assumiu decide quando encerrar. Auto-resolve existe
# para o que ficou ORFAO — sem dono, sem ninguem olhando.
#
# Cobre os DOIS caminhos:
#   - `open`    -> decorator em Conversations::ResolutionJob#conversation_scope
#   - `pending` -> klaos_auto_resolve_pending.rb consulta o mesmo helper
#
# `assignee_id` e vinculo com User (humano). Bot nao ocupa esse campo, entao
# conversa que so a Lara/ANA tocou continua elegivel — que e o desejado.
#
# Desligavel por conta: settings['klaos_auto_resolve_skip_assigned'] = false.

module KlaosAutoResolveSkipAssigned
  # Fonte unica da regra, consumida pelos dois caminhos.
  def self.pular_atribuidas?(account)
    (account.settings || {})['klaos_auto_resolve_skip_assigned'] != false
  end

  private

  # private para nao promover a visibilidade do metodo original do job.
  def conversation_scope(account)
    escopo = super
    return escopo unless KlaosAutoResolveSkipAssigned.pular_atribuidas?(account)

    escopo.where(assignee_id: nil)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversations::ResolutionJob)

  unless Conversations::ResolutionJob.ancestors.include?(KlaosAutoResolveSkipAssigned)
    Conversations::ResolutionJob.prepend(KlaosAutoResolveSkipAssigned)
    Rails.logger.info '[AutoResolveSkipAssigned] prepended on Conversations::ResolutionJob'
  end
end
