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

module KlaosAutoAssignmentOfflineFallback
  def find_assignee
    agent = super
    return agent if agent

    return nil unless klaos_offline_fallback_enabled?
    return nil if allowed_agent_ids.blank?

    klaos_pick_offline_fallback
  end

  private

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
    user_id = Klaos::LeastLoadedPicker.pick(
      account_id: account_id,
      candidate_ids: allowed_agent_ids
    )
    user = User.find_by(id: user_id) if user_id

    Rails.logger.info(
      "[KlaosOfflineFallback] no online agent — assigning offline " \
      "conv=#{conversation.id} team=#{conversation.team_id} " \
      "inbox=#{conversation.inbox_id} candidates=#{allowed_agent_ids.inspect} " \
      "picked_user_id=#{user_id} picked_name=#{user&.name.inspect} (via least_loaded)"
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
