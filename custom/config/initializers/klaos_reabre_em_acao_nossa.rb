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

# (16/09/2026) DUAS EXCECOES, pedido do Gustavo ("reabre aleatoriamente com a
# propria Lara").
#
# 1. COBRAR-AGORA NAO E ACAO DO BOT.
#    O atendente aplica a etiqueta cobrar-agora numa conversa resolvida, o KLaOS
#    manda o template com o token do usuario I.A e o `reopen_resolved_conversation`
#    ve bot ativo na inbox e grava `pending`. A conversa que o humano pediu para
#    cobrar vira territorio da Lara: conta 9, 24 casos em 30 dias; 13 das 40
#    reaberturas humanas vieram logo depois desse `pending` (conv 2063: Gustavo
#    cobra, "pendente por I.A", cliente agradece, Lara responde).
#    Agora: mensagem do cobrar-agora em conversa com dono reabre `open` e mantem
#    o dono. `open` com dono nao aciona rodizio (`should_run_auto_assignment?`
#    exige assignee em branco). Sem dono, segue o upstream (`pending`): quando
#    o humano clicar em reabrir, klaos_reabrir_atribui_quem_reabriu.rb atribui
#    a conversa a ele. Abrir `open` sem dono deixaria a Lara atrelada e sem
#    botao de reabrir para o humano assumir.
#    Como se reconhece: `template_params.klaos_origem == 'cobrar_agora'` (marca
#    que o KLaOS passa a mandar), `additional_attributes.klaos_origem` (se um
#    dia vier fora do template) ou o nome do template, que hoje ja identifica
#    o fluxo (`cobr_cobrar_agora_v2`, `cobr_cobrar_agora_card_v2`,
#    `<prefixo>_cobr_cobrar_agora_v2`).
#
# 2. REGUA NAO CANCELA ADIAMENTO.
#    Conversa adiada so perde a hora quando uma PESSOA fala com o cliente (ou
#    quando o cliente escreve, no upstream). Template da regua, mensagem do bot
#    e qualquer envio por token de integracao deixam a conversa adiada: a
#    regua da conta 9 cobra quase todo dia e nenhum adiamento longo de devedor
#    sobrevivia. Cobrar-agora conta como pessoa (foi um humano que pediu).

module KlaosReabreEmAcaoNossa
  ORIGEM_COBRAR_AGORA = 'cobrar_agora'

  def reopen_conversation
    super

    return unless klaos_acao_nossa_reabre?
    return unless conversation.resolved? || conversation.snoozed?

    cobrar_agora = klaos_cobrar_agora?

    if conversation.snoozed?
      # Regua/bot/integracao: a conversa continua adiada.
      return unless cobrar_agora || klaos_mensagem_de_pessoa?

      # Adiada: uma pessoa acabou de falar com o cliente, entao ela nao esta
      # mais esperando o relogio. Limpa a hora ANTES de mudar o status, senao a
      # conversa volta a ser candidata do job que reabre adiadas.
      conversation.update_columns(snoozed_until: nil) # rubocop:disable Rails/SkipsModelValidations
    end

    if cobrar_agora && conversation.assignee_id.present?
      # Humano pediu a cobranca: fica com quem ja era dono, fora do bot.
      conversation.open!
    else
      # Quem decide o status e o upstream (bot ativo -> pending, resto -> open).
      reopen_resolved_conversation
    end
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

  def klaos_template_params
    extras = additional_attributes.is_a?(Hash) ? additional_attributes : {}
    tp = extras['template_params']
    tp.is_a?(Hash) ? tp : {}
  end

  def klaos_cobrar_agora?
    extras = additional_attributes.is_a?(Hash) ? additional_attributes : {}
    return true if extras['klaos_origem'].to_s == ORIGEM_COBRAR_AGORA

    tp = klaos_template_params
    return true if tp['klaos_origem'].to_s == ORIGEM_COBRAR_AGORA

    tp['name'].to_s.include?('cobrar_agora')
  end

  # Pessoa digitando no painel. Nao conta: bot, template (regua), automacao,
  # campanha e qualquer mensagem que entrou por api_access_token.
  def klaos_mensagem_de_pessoa?
    return false unless sender.is_a?(User)
    return false if klaos_template_params.present?
    conteudo = content_attributes
    return false if conteudo.is_a?(Hash) && conteudo['automation_rule_id'].present?

    extras = additional_attributes
    return false if extras.is_a?(Hash) && extras['campaign_id'].present?
    return false if defined?(KlaosOrigemDaRequisicao) && KlaosOrigemDaRequisicao.via_token

    true
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosReabreEmAcaoNossa)

  Message.prepend(KlaosReabreEmAcaoNossa)
  Rails.logger.info '[KlaosReabreEmAcaoNossa] prepended on Message'
end
