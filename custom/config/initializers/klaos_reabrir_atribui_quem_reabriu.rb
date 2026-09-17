# frozen_string_literal: true

# QUEM REABRE A CONVERSA FICA COM ELA
#
# Gustavo (Mais Saude), 16/09/2026: "Acabei de reabrir uma conversa com uma
# paciente usando o meu usuario: tem que reabrir comigo, mas reabre
# aleatoriamente com a propria Lara e as vezes com outra atendente. Se abriu
# pelo meu usuario, obrigatoriamente tem que vir para mim."
#
# O QUE O UPSTREAM FAZ (app/controllers/api/v1/accounts/conversations_controller.rb)
#
#   def toggle_status
#     ...
#     set_conversation_status
#     @status = @conversation.save!          # <- rodizio e webhooks rodam aqui
#     ...
#     assign_conversation if should_assign_conversation?   # <- so papel agent
#   end
#
# Tres defeitos juntos:
#   1. So atribui se o papel for `agent`. Gustavo, Marta, Ricardo sao
#      administradores: reabrem e a conversa continua sem dono, com a Lara
#      atrelada, e a Lara responde a proxima mensagem do cliente.
#   2. A atribuicao e um SEGUNDO save. No primeiro, com a conversa `open` e sem
#      dono, o rodizio do time (AutoAssignmentHandler) ja sorteou e notificou
#      outra atendente. Foi o "as vezes com outra atendente" (casos em julho).
#   3. Os webhooks do primeiro save saem sem assignee, entao o KLaOS le
#      "open sem humano" e devolve a conversa para a IA.
#
# A REGRA
#
# Pessoa (User) reabrindo pelo painel uma conversa resolved/pending/snoozed
# vira dona dela NO MESMO save que muda o status. Assim:
#   (a) o rodizio ve um dono e nao sorteia ninguem;
#   (b) `reset_agent_bot_when_assignee_present` solta a Lara nesse mesmo save;
#   (c) `conversation_status_changed` e `conversation_updated` ja saem com o
#       humano no payload.
#
# Fica de fora:
#   - requisicao com `api_access_token` (KLaOS, I.A, integracoes). O dono ali e
#     decidido pelo KLaOS; o usuario do token nao pode virar dono por reabrir.
#   - AgentBot (o upstream ja trata com `bot_handoff!`).
#   - quem nao e membro da inbox. Nao da para ser dono de conversa de uma caixa
#     em que a pessoa nao atende; nesse caso o comportamento e o do upstream.
#   - resolver e adiar: so a reabertura atribui.
#
# Desligavel por conta: accounts.settings['klaos_reabrir_atribui_quem_reabriu'] = false.

module KlaosReabrirAtribuiQuemReabriu
  STATUS_QUE_REABREM = %w[resolved pending snoozed].freeze

  def self.ativo?(account)
    (account&.settings || {})['klaos_reabrir_atribui_quem_reabriu'] != false
  end

  private

  def set_conversation_status
    status_anterior = @conversation.status
    super
    return unless klaos_atribuir_quem_reabriu?(status_anterior)

    @conversation.assignee = Current.user
  end

  def klaos_atribuir_quem_reabriu?(status_anterior)
    return false unless params[:status].to_s == 'open'
    return false unless STATUS_QUE_REABREM.include?(status_anterior.to_s)
    return false unless Current.user.is_a?(User)
    return false if authenticate_by_access_token?
    return false unless KlaosReabrirAtribuiQuemReabriu.ativo?(@conversation.account)
    return false if @conversation.assignee_id == Current.user.id

    @conversation.inbox.inbox_members.exists?(user_id: Current.user.id)
  rescue StandardError => e
    # Em duvida, nao atribui: cai no comportamento do upstream.
    Rails.logger.warn(
      "[KlaosReabrirAtribuiQuemReabriu] checagem falhou conv=#{@conversation&.id}: #{e.class}: #{e.message}"
    )
    false
  end
end

Rails.application.config.to_prepare do
  # safe_constantize, como em klaos_mark_unread.rb: com Zeitwerk o `defined?`
  # pode nao disparar o autoload do controller.
  controller = 'Api::V1::Accounts::ConversationsController'.safe_constantize
  next unless controller
  next if controller.ancestors.include?(KlaosReabrirAtribuiQuemReabriu)

  controller.prepend(KlaosReabrirAtribuiQuemReabriu)
  Rails.logger.info '[KlaosReabrirAtribuiQuemReabriu] prepended on Api::V1::Accounts::ConversationsController'
end
