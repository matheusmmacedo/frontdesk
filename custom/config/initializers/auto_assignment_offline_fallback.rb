# frozen_string_literal: true

# AUTO ASSIGNMENT — OFFLINE FALLBACK (Bug F1)
#
# Upstream Chatwoot só atribui assignee se houver agente *online* no Redis no
# momento exato da mudança de team. Quando o KLaOS muda team_id via API e
# nenhum agente do (inbox ∩ team) está com aba aberta, conversation fica
# com team_id setado mas assignee_id = NULL — usuário reclama "ninguém pegou
# pra mim mesmo eu sendo do time e online".
#
# Causa: AgentAssignmentService#find_assignee filtra por OnlineStatusTracker
# (Redis) e devolve nil se intersect vazio. DB.availability=1 é cache, fica
# desatualizado.
#
# Fix modular: quando online vazio, usar primeiro user_id (ordenado por id)
# de allowed_agent_ids como fallback offline. Funciona pra qualquer conta;
# habilitado per-account via accounts.custom_attributes:
#   { "klaos_auto_assignment_offline_fallback": true }
#
# Default off → comportamento upstream intacto pra todas as outras contas.
#
# ---------------------------------------------------------------------------
# 10/08/2026 — QUEM SE MARCOU INDISPONÍVEL FICA DE FORA
#
# O fallback acima confundia duas coisas muito diferentes:
#
#   sem presença no Redis  → a pessoa está trabalhando, só não tem a aba em
#                            foco nos últimos 20s. Distribuir é o certo, e é
#                            exatamente pra isso que este arquivo existe.
#   availability = offline → a pessoa se marcou indisponível, ou está de
#                            férias. Distribuir é errado, sempre.
#
# Como o fallback ignorava status, a Yasmin recebeu 7 conversas em 10/08
# estando de férias E já marcada como offline no sistema. O time de vendas da
# Mais Saúde é Ludiana + Yasmin; fora do horário as duas somem do Redis, o
# fallback disparava e o rodízio de menor carga escolhia a Yasmin na metade
# das vezes.
#
# Agora o fallback só considera quem está com availability = online no banco.
# Se ninguém do time estiver disponível, ninguém recebe e a conversa fica sem
# dono — que é o resultado correto às 3 da manhã e nas férias de alguém.
#
# Cuidado ao mexer: `availability` mora em account_users (por conta), não em
# users. A mesma pessoa pode estar online num cliente e offline em outro.

module KlaosAutoAssignmentOfflineFallback
  def find_assignee
    agent = super
    return agent if agent

    return nil unless klaos_offline_fallback_enabled?
    return nil if allowed_agent_ids.blank?

    klaos_pick_offline_fallback
  end

  private

  # Dos candidatos do time, só os que NÃO se marcaram indisponíveis.
  # availability: 0 = online, 1 = offline, 2 = busy (ocupado).
  # Quem está busy também fica de fora: se a pessoa sinalizou que não pode
  # pegar mais conversa, o fallback não é motivo pra ignorar isso.
  def klaos_candidatos_disponiveis
    account_id = conversation&.account_id
    return [] if account_id.blank?

    AccountUser
      .where(account_id: account_id, user_id: allowed_agent_ids)
      .where(availability: :online)
      .pluck(:user_id)
  end

  def klaos_offline_fallback_enabled?
    account = conversation&.account
    return false unless account

    flag = account.custom_attributes&.dig('klaos_auto_assignment_offline_fallback')
    ActiveModel::Type::Boolean.new.cast(flag)
  end

  def klaos_pick_offline_fallback
    # Load balancing: agente com MENOR carga atual de convs abertas.
    # Substitui o antigo `sort.first` (que pegava sempre o menor ID e
    # acabava acumulando estoque no mesmo agente). Ver:
    #   custom/app/services/klaos/least_loaded_picker.rb
    account_id = conversation&.account_id
    disponiveis = klaos_candidatos_disponiveis

    if disponiveis.blank?
      Rails.logger.info(
        '[KlaosOfflineFallback] ninguém disponível — conversa fica sem dono ' \
        "conv=#{conversation.id} team=#{conversation.team_id} " \
        "candidatos=#{allowed_agent_ids.inspect} (todos offline/busy)"
      )
      return nil
    end

    user_id = Klaos::LeastLoadedPicker.pick(
      account_id: account_id,
      candidate_ids: disponiveis
    )
    user = User.find_by(id: user_id) if user_id

    Rails.logger.info(
      '[KlaosOfflineFallback] sem presença no Redis — distribuindo entre quem ' \
      "está disponível conv=#{conversation.id} team=#{conversation.team_id} " \
      "inbox=#{conversation.inbox_id} candidatos=#{allowed_agent_ids.inspect} " \
      "disponíveis=#{disponiveis.inspect} " \
      "escolhido=#{user_id} nome=#{user&.name.inspect} (via least_loaded)"
    )

    user
  end
end

Rails.application.config.to_prepare do
  next unless defined?(AutoAssignment::AgentAssignmentService)
  next if AutoAssignment::AgentAssignmentService.include?(KlaosAutoAssignmentOfflineFallback)

  AutoAssignment::AgentAssignmentService.prepend(KlaosAutoAssignmentOfflineFallback)
  Rails.logger.info '[KlaosOfflineFallback] Initializer loaded'
end
