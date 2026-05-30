# frozen_string_literal: true

# KLaOS — CRUD de motivos de pausa (O.19 Pausas Tipadas).
#
# GET    /api/custom/v1/accounts/:id/pause_reasons         — público pra agentes (lista ativa)
# POST   /api/custom/v1/accounts/:id/pause_reasons         — admin
# PATCH  /api/custom/v1/accounts/:id/pause_reasons/:id     — admin
# DELETE /api/custom/v1/accounts/:id/pause_reasons/:id     — admin
#
# Soft delete: marca active=false (preserva FK em eventos passados).

class Api::Custom::V1::Accounts::PauseReasonsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization, only: %i[create update destroy reorder]
  before_action :set_reason, only: %i[update destroy]

  def index
    # Lazy-seed: se conta não tem nenhum motivo ainda, popula defaults
    Current.account.klaos_ensure_pause_reasons!
    reasons = KlaosPauseReason.where(account_id: Current.account.id).active.ordered
    render json: { reasons: reasons.map { |r| serialize(r) } }
  end

  def create
    reason = KlaosPauseReason.new(account_id: Current.account.id, **reason_params)
    if reason.save
      render json: serialize(reason), status: :created
    else
      render json: { errors: reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @reason.update(reason_params)
      render json: serialize(@reason)
    else
      render json: { errors: @reason.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @reason.update!(active: false)
    head :no_content
  end

  # Bulk reorder — body: { order: [ {id, sort_order}, ... ] }
  def reorder
    items = params[:order] || []
    KlaosPauseReason.transaction do
      items.each do |it|
        r = KlaosPauseReason.where(account_id: Current.account.id).find(it[:id])
        r.update!(sort_order: it[:sort_order].to_i)
      end
    end
    head :no_content
  end

  private

  def set_reason
    @reason = KlaosPauseReason.where(account_id: Current.account.id).find(params[:id])
  end

  def reason_params
    params.require(:reason).permit(:name, :icon, :sort_order, :active)
  end

  def check_admin_authorization
    return if Current.account_user&.administrator?

    render json: { error: 'admin only' }, status: :forbidden
  end

  def serialize(r)
    {
      id: r.id,
      name: r.name,
      icon: r.icon,
      sort_order: r.sort_order,
      active: r.active
    }
  end
end
