# frozen_string_literal: true

# KLaOS — Painel de Agentes (supervisão em tempo real) — O.1.
#
# Endpoint admin-only que devolve a grid de agentes da conta com:
#   - estado atual (online/busy/offline)
#   - chats em atendimento AGORA
#   - atendidos hoje + TMA hoje
#   - tempo logado hoje + tempo em pausa hoje
#
# Tempos vêm de KlaosAgentTimingService (eventos persistidos por
# klaos_agent_availability_tracking.rb). TMA vem de V2::Reports::AgentSummaryBuilder
# nativo do Chatwoot.
#
# POST .../agents/:user_id/force_status — admin força status de OUTRO
# agente (logout forçado, força pausa, etc).

class Api::Custom::V1::Accounts::SupervisorAgentsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization

  def index
    agents = Current.account.users.includes(:account_users).to_a
    agent_ids = agents.map(&:id)

    timing = KlaosAgentTimingService.new(account: Current.account, user_ids: agent_ids).call
    chats_now = chats_per_agent(agent_ids)
    summary = summary_counts(agents)

    rows = agents.map do |user|
      au = user.account_users.find { |x| x.account_id == Current.account.id }
      t  = timing[user.id] || { online_s: 0, busy_s: 0, offline_s: 0, attended_today: 0 }
      {
        id: user.id,
        name: user.available_name,
        email: user.email,
        thumbnail: user.avatar_url,
        role: au&.role,
        availability: au&.availability,
        chats_now: chats_now[user.id] || 0,
        attended_today: t[:attended_today],
        online_today_s: t[:online_s],
        busy_today_s: t[:busy_s],
        offline_today_s: t[:offline_s]
      }
    end

    render json: { agents: rows, summary: summary, generated_at: Time.current.to_i }
  end

  # POST /api/custom/v1/accounts/:account_id/supervisor/agents/:user_id/force_status
  # Body: { status: "offline" | "online" | "busy" }
  def force_status
    new_status = params[:status].to_s
    unless %w[online offline busy].include?(new_status)
      return render json: { error: 'invalid status' }, status: :unprocessable_entity
    end

    au = Current.account.account_users.find_by!(user_id: params[:user_id])
    au.update!(availability: new_status)
    render json: { ok: true, user_id: au.user_id.to_i, availability: au.availability }
  end

  private

  def check_admin_authorization
    return if Current.account_user&.administrator?

    render json: { error: 'admin only' }, status: :forbidden
  end

  # Contagem de conversas em status :open OU :pending atribuídas a cada agente.
  def chats_per_agent(agent_ids)
    Current.account.conversations
           .where(assignee_id: agent_ids)
           .where(status: %i[open pending])
           .group(:assignee_id)
           .count
  end

  def summary_counts(agents)
    counts = { online: 0, busy: 0, offline: 0, with_chats: 0 }
    chats = chats_per_agent(agents.map(&:id))
    agents.each do |u|
      au = u.account_users.find { |x| x.account_id == Current.account.id }
      next if au.nil?

      counts[au.availability.to_sym] += 1 if counts.key?(au.availability.to_sym)
      counts[:with_chats] += 1 if (chats[u.id] || 0).positive?
    end
    counts
  end
end
