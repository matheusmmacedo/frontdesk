# frozen_string_literal: true

# KLaOS — Setar motivo de pausa do agente corrente (O.19).
#
# POST /api/custom/v1/accounts/:id/klaos/agent_pause
#   Body: { reason_id: 12 }
#
# Atualiza pause_reason_id no evento de availability ABERTO (ended_at NULL)
# do current_user. Aceita só se o evento atual tiver status=busy.
#
# Pra fluxo completo: o frontend dispara PRIMEIRO updateAvailability (busy)
# pra criar o evento — depois disso chama esse endpoint pra setar o motivo.

class Api::Custom::V1::Accounts::AgentPauseController < Api::V1::Accounts::BaseController
  def create
    reason_id = params[:reason_id].to_i
    reason = KlaosPauseReason.where(account_id: Current.account.id).find_by(id: reason_id)
    return render json: { error: 'invalid reason' }, status: :unprocessable_entity if reason.nil?

    event = KlaosAgentAvailabilityEvent
            .where(account_id: Current.account.id, user_id: Current.user.id, ended_at: nil)
            .order(started_at: :desc)
            .first

    return render json: { error: 'no open availability event' }, status: :not_found if event.nil?
    return render json: { error: 'current status is not busy' }, status: :conflict unless event.busy?

    event.update!(pause_reason_id: reason.id)
    render json: { ok: true, event_id: event.id, reason: { id: reason.id, name: reason.name, icon: reason.icon } }
  end
end
