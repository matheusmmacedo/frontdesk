# frozen_string_literal: true

# ACAO NOSSA REABRE CONVERSA RESOLVIDA / ADIADA
#
# Regra do negocio (07/08/2026): "se a conversa esta resolvida e fizemos uma
# nova acao, reabre a conversa; e se o cliente nao responder, o guard de 24h
# pega. Inclusive se ela estiver resolvida tem que reabrir com o bot como
# responsavel."
#
# O upstream so reabre por mensagem do CLIENTE (app/models/message.rb):
#
#   def reopen_conversation
#     return if conversation.muted?
#     return unless incoming?          # <-- aqui
#     conversation.open! if conversation.snoozed?
#     reopen_resolved_conversation if conversation.resolved?
#   end
#
# Consequencia medida na conta 9: a cobranca sai numa conversa ja `resolved` e
# a conversa CONTINUA `resolved`. Do lado do atendente a cobranca simplesmente
# nao existe — nao esta em nenhuma fila, ninguem acompanha a resposta.
#
# Aqui a reabertura passa a valer tambem para mensagem NOSSA (outgoing
# nao-privada): cobranca, template, resposta. Nota interna e activity (etiqueta,
# atribuicao) continuam de fora — trocar etiqueta nao e "falar com o cliente".
#
# POR QUE `pending` E NAO `open` — e o "bot como responsavel" do pedido:
#
#   AutoAssignmentHandler dispara o rodizio em `conversation_status_changed_to_open?`
#   com assignee em branco. Reabrir 80 cobrancas/dia em `open` despejaria todas
#   elas, sorteadas, em cima dos atendentes — exatamente a queixa recorrente de
#   "conversa da Yasmin caindo pro Gustavo".
#
#   `pending` e o estado que o proprio Chatwoot usa para "o bot esta cuidando":
#   e o que o upstream ja escolhe em `reopen_resolved_conversation` quando a
#   inbox tem bot ativo. Nao dispara rodizio, e a conversa volta a ser visivel.
#
# Por isso este decorator NAO decide o status sozinho: delega para o
# `reopen_resolved_conversation` do upstream, que ja faz a escolha certa por
# tipo de inbox (bot ativo -> pending, api/demais -> open). Um caminho so, sem
# copia divergente.
#
# Casa com klaos_auto_resolve_relogio_real.rb: aquele garante que a conversa
# recem-cobrada nao seja fechada em 3 minutos; este garante que ela seja
# reaberta quando ja estava fechada. Sem os dois, a cobranca fica invisivel.
#
# Desligavel por conta: settings['klaos_reabre_em_acao_nossa'] = false.

module KlaosReabreEmAcaoNossa
  def reopen_conversation
    super

    return unless klaos_acao_nossa_reabre?
    return unless conversation.resolved? || conversation.snoozed?

    # Adiada: a gente acabou de falar com o cliente, entao ela nao esta mais
    # esperando o relogio. Limpa a hora ANTES de mudar o status, senao a conversa
    # volta a ser candidata do job que reabre adiadas.
    conversation.update_columns(snoozed_until: nil) if conversation.snoozed? # rubocop:disable Rails/SkipsModelValidations

    # Quem decide o status e o upstream (bot ativo -> pending, resto -> open).
    reopen_resolved_conversation
  end

  private

  def klaos_acao_nossa_reabre?
    return false if conversation.muted?
    return false if private?
    # incoming ja e tratado pelo super — nao reprocessar.
    return false unless message_type == 'outgoing'

    conta = conversation.account
    (conta&.settings || {})['klaos_reabre_em_acao_nossa'] != false
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosReabreEmAcaoNossa)

  Message.prepend(KlaosReabreEmAcaoNossa)
  Rails.logger.info '[KlaosReabreEmAcaoNossa] prepended on Message'
end
