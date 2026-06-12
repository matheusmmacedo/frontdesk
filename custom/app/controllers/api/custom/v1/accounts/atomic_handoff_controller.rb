# frozen_string_literal: true

# Endpoint ATÔMICO de handoff (KLaOS).
#
# Por que existe: o fluxo padrão do KLaOS pra handoff por team era
#   1) POST /assignments com assignee_id=null   (desatribui)
#   2) POST /assignments com team_id=N          (muda team, dispara auto-assign)
# Esses 2 passos criavam uma janela de até 23s onde a conversa ficava
# órfã (`assignee_id=null`), e o auto-assign do Chatwoot upstream
# escolhia outro agente via round-robin — resultando em "flash-assign"
# pra agente diferente do esperado, mesmo quando o anterior estava
# atendendo.
#
# Esse endpoint resolve ATÔMICAMENTE: numa única transação, seta
# `team_id` e `assignee_id` ao mesmo tempo. Sem janela de
# `assignee_id=null`. O upstream `AutoAssignmentJob` não dispara porque
# a conversa já vem com assignee na transação.
#
# POST /api/custom/v1/accounts/:account_id/conversations/:conversation_id/handoff_atomic
# Body:
#   {
#     "team_id":        <int>  (obrigatório)
#     "target_user_id": <int>  (opcional — se informado força esse user;
#                                senão escolhe via LeastLoadedPicker)
#   }
# Auth: header `api_access_token` (mesma da API V1)
#
# Retorna:
#   {
#     "conversation_id":  <display_id>,
#     "team_id":          <int>,
#     "team_name":        <str>,
#     "assignee_id":      <int>,
#     "assignee_name":    <str>,
#     "pick_mode":        "explicit" | "auto_online_least_loaded"
#                         | "auto_offline_fallback_least_loaded"
#   }
#
# Errors:
#   422 { error: "team_not_found"  }
#   422 { error: "no_candidates"   }  team sem membros ativos na inbox
#   422 { error: "target_user_not_in_team_or_inbox" }

class Api::Custom::V1::Accounts::AtomicHandoffController < Api::V1::Accounts::BaseController
  before_action :set_conversation

  def create
    team = Current.account.teams.find_by(id: params[:team_id])
    return render json: { error: 'team_not_found' }, status: :unprocessable_entity unless team

    target_user_id = params[:target_user_id].presence&.to_i
    inbox = @conversation.inbox
    candidate_ids = (inbox.member_ids_with_assignment_capacity & team.members.ids)
    online_user_ids = fetch_online_user_ids(Current.account.id)

    pick_mode, new_user_id = pick_assignee(candidate_ids, online_user_ids, target_user_id)
    return render_pick_error(pick_mode) if new_user_id.nil?

    new_user = User.find_by(id: new_user_id)
    return render json: { error: 'user_not_found' }, status: :unprocessable_entity unless new_user

    # ATÔMICO: team + assignee no MESMO save. Sem janela de assignee_id=null.
    # AutoAssignmentJob upstream não dispara porque assignee já existe.
    ActiveRecord::Base.transaction do
      @conversation.team = team
      @conversation.assignee = new_user
      @conversation.assignee_agent_bot = nil
      @conversation.save!
    end

    render json: {
      conversation_id: @conversation.display_id,
      team_id: team.id,
      team_name: team.name,
      assignee_id: new_user.id,
      assignee_name: new_user.name,
      pick_mode: pick_mode
    }, status: :ok
  end

  private

  def set_conversation
    id_param = params[:conversation_id] || params[:id]
    @conversation = Current.account.conversations.find_by!(display_id: id_param)
  end

  def fetch_online_user_ids(account_id)
    OnlineStatusTracker.get_available_users(account_id)
                       .select { |_k, v| v == 'online' }
                       .keys.map(&:to_i)
  end

  # Retorna [pick_mode, user_id_or_nil]
  def pick_assignee(candidate_ids, online_user_ids, target_user_id)
    if target_user_id
      return [:not_in_team_or_inbox, nil] unless candidate_ids.include?(target_user_id)

      return ['explicit', target_user_id]
    end

    return [:no_candidates, nil] if candidate_ids.empty?

    candidates_online = candidate_ids & online_user_ids
    if candidates_online.any?
      [
        'auto_online_least_loaded',
        Klaos::LeastLoadedPicker.pick(account_id: Current.account.id, candidate_ids: candidates_online)
      ]
    else
      # ninguém online — usa todo o pool (será catch-up'd quando alguém entrar)
      [
        'auto_offline_fallback_least_loaded',
        Klaos::LeastLoadedPicker.pick(account_id: Current.account.id, candidate_ids: candidate_ids)
      ]
    end
  end

  def render_pick_error(mode)
    case mode
    when :not_in_team_or_inbox
      render json: { error: 'target_user_not_in_team_or_inbox' }, status: :unprocessable_entity
    when :no_candidates
      render json: { error: 'no_candidates' }, status: :unprocessable_entity
    else
      render json: { error: 'pick_failed' }, status: :unprocessable_entity
    end
  end
end
