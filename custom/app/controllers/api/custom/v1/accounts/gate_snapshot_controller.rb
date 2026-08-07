# frozen_string_literal: true

# Endpoint dedicado pro Chatwoot Gate do KLaOS.
#
# Por que existe: o serializer da API V1 do Chatwoot
# (_conversation.json.jbuilder) não emite assignee_agent_bot_id, agent_bot_id
# top-level, nem meta.assignee_agent_bot.id. Quando o assignee é um AgentBot,
# ele aparece como meta.assignee comum com meta.assignee_type='AgentBot'.
# O gate do KLaOS precisa distinguir 4 estados:
#   - cw_human_assignee  (assignee humano)
#   - cw_team_only       (só team_id, sem assignee)
#   - cw_bot_attached    (assignee_agent_bot_id setado)
#   - cw_status_unknown  (estado ambíguo → fail-closed)
# Como o JSON padrão fundia bot e humano em meta.assignee, o gate caía sempre
# em cw_status_unknown nos modos bot. Esse endpoint expõe os 4 campos crus
# pra eliminar a ambiguidade.
#
# GET /api/custom/v1/accounts/:account_id/conversations/:conversation_id/gate_snapshot
# Retorna:
#   {
#     "conversation_id": <display_id>,
#     "account_id": <account_id>,
#     "status": "open|pending|resolved|snoozed",
#     "assignee_id": <int|null>,
#     "team_id": <int|null>,
#     "agent_bot_id": <int|null>,
#     "assignee_message_count": <int>,
#     "assignee_last_message_at": <iso8601|null>
#   }
#
# (07/08/2026) Os dois últimos campos existem para separar DOIS donos que o
# `assignee_id` sozinho confunde:
#
#   - quem o auto-assignment da inbox SORTEOU (`enable_auto_assignment`), que
#     não falou com ninguém e pode ser substituído;
#   - quem está de fato no meio do atendimento e não pode perder a conversa.
#
# O KLaOS pulava a transferência sempre que encontrava um dono, então o
# sorteio ganhava do pedido do cliente: na Blue Care conv 247 o cliente
# escreveu "Olá Laura", o KLaOS resolveu a Laura e a conversa ficou com quem
# o sorteio pegou — a Laura teve que se atribuir na mão 44s depois.
#
# A contagem é escopada ao assignee ATUAL de propósito: a pergunta é "essa
# pessoa está atendendo?", não "alguém já respondeu aqui?". Assim o bot da
# conta (que também é um User) não conta como atendimento humano.

class Api::Custom::V1::Accounts::GateSnapshotController < Api::V1::Accounts::BaseController
  before_action :set_conversation

  def show
    render json: {
      conversation_id: @conversation.display_id,
      account_id: @conversation.account_id,
      status: @conversation.status,
      assignee_id: @conversation.assignee_id,
      team_id: @conversation.team_id,
      agent_bot_id: @conversation.assignee_agent_bot_id,
      assignee_message_count: assignee_messages.count,
      assignee_last_message_at: assignee_messages.maximum(:created_at)&.iso8601
    }, status: :ok
  end

  private

  # Mensagens que o dono atual mandou para o cliente. Nota privada não conta:
  # anotar não é atender.
  def assignee_messages
    return Message.none if @conversation.assignee_id.blank?

    @conversation.messages.outgoing.where(
      private: false,
      sender_type: 'User',
      sender_id: @conversation.assignee_id
    )
  end

  def set_conversation
    id_param = params[:conversation_id] || params[:id]
    @conversation = Current.account.conversations.find_by!(display_id: id_param)
  end
end
