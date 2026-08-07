# frozen_string_literal: true

# AUTO-RESOLVE CONTA O RELOGIO PELA ULTIMA MENSAGEM REAL, NAO POR last_activity_at
#
# INCIDENTE 07/08/2026 — Gustavo: "ate agora nao vi os envios que voce disse que
# ela fez hoje, so tem 6 conversas abertas". Medido na conta 9 no mesmo dia:
#
#   cobradas hoje ............ 86
#   fechadas pelo sistema .... 74, a maioria 3 MINUTOS depois do envio
#   carimbo do fechamento .... "marked resolved by system due to 1 days of inactivity"
#
# Exemplo: conv 252 — cobranca sai 07/08 08:35, auto-resolve fecha 08:40, e o
# `last_activity_at` da conversa continuava em 15/05. O job olhou a coluna, leu
# "83 dias parada" e fechou. Do lado de fora parece que a cobranca nunca saiu.
#
# CAUSA — uma coluna servindo a dois donos:
#
#   `last_activity_at` e ao mesmo tempo (a) a chave de ordenacao da lista e
#   (b) o relogio do auto-resolve.
#
# Em junho o `klaos_sort_ignore_activities.rb` passou a pular o update da coluna
# para tudo que nao fosse mensagem do cliente. Aquilo atendia um pedido legitimo
# ("respondo ou etiqueto e a conversa pula pra 1a posicao, perco o contexto") e
# esta CORRETO para (a). So que arrastou (b) junto: o relogio do auto-resolve
# passou a marcar a ultima fala do CLIENTE, entao qualquer coisa que a gente
# mandasse nascia ja vencida.
#
# CORRECAO — separar as duas leituras, nao desfazer nenhuma das duas:
#   - ordenacao  -> continua em `last_activity_at` (so o cliente sobe a conversa)
#   - relogio    -> passa a ser "existe mensagem real nas ultimas N horas?",
#                   contando os DOIS lados (incoming e outgoing nao-privada)
#
# So mensagem de gente conta. Ficam de fora, de proposito:
#   - `activity` (etiqueta, atribuicao, status) — trocar etiqueta nao e atendimento
#   - `private`  — nota interna nao e conversa com o cliente
#
# Efeito pratico: conversa cobrada agora sobrevive a janela inteira de
# `auto_resolve_after`. Se o cliente nao responder, ela fecha no prazo normal —
# que e a regra pedida, e nao os 3 minutos de hoje.
#
# Cobre os DOIS caminhos, pelo mesmo helper, para nao divergirem:
#   - `open`    -> decorator em Conversations::ResolutionJob#conversation_scope
#   - `pending` -> klaos_auto_resolve_pending.rb chama o helper direto
#
# Desligavel por conta: settings['klaos_auto_resolve_relogio_real'] = false.

module KlaosAutoResolveRelogioReal
  # incoming = 0, outgoing = 1 (activity e template ficam de fora de proposito).
  TIPOS_QUE_CONTAM = [0, 1].freeze

  def self.habilitado?(account)
    (account.settings || {})['klaos_auto_resolve_relogio_real'] != false
  end

  # Fonte unica da regra, consumida pelos caminhos `open` e `pending`.
  #
  # NOT EXISTS correlacionado em vez de `where.not(id: subquery)`: o planner
  # consegue cortar assim que acha a primeira mensagem recente, e nao ha a
  # armadilha de NULL do NOT IN.
  def self.sem_mensagem_desde(escopo, corte)
    escopo.where(
      'NOT EXISTS (' \
      'SELECT 1 FROM messages m ' \
      'WHERE m.conversation_id = conversations.id ' \
      "AND m.message_type IN (#{TIPOS_QUE_CONTAM.join(',')}) " \
      'AND m.private = false ' \
      'AND m.created_at >= ?)',
      corte
    )
  end

  private

  # private para nao promover a visibilidade do metodo original do job.
  def conversation_scope(account)
    escopo = super
    return escopo unless KlaosAutoResolveRelogioReal.habilitado?(account)

    minutos = account.auto_resolve_after.to_i
    return escopo if minutos.zero?

    KlaosAutoResolveRelogioReal.sem_mensagem_desde(escopo, Time.now.utc - minutos.minutes)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversations::ResolutionJob)

  unless Conversations::ResolutionJob.ancestors.include?(KlaosAutoResolveRelogioReal)
    Conversations::ResolutionJob.prepend(KlaosAutoResolveRelogioReal)
    Rails.logger.info '[AutoResolveRelogioReal] prepended on Conversations::ResolutionJob'
  end
end
