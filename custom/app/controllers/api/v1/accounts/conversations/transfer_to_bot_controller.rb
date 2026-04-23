# frozen_string_literal: true

# TRANSFER TO BOT CONTROLLER
# Endpoint customizado pra devolver uma conversa ao bot da inbox.
# Ação: status → pending, assignee/team → null, postar nota privada, disparar webhook KLaOS.
#
# POST /api/v1/accounts/:account_id/conversations/:conversation_id/transfer_to_bot

class Api::V1::Accounts::Conversations::TransferToBotController < Api::V1::Accounts::Conversations::BaseController
  # Override do BaseController: em member routes, o param é :id (não :conversation_id)
  def conversation
    @conversation ||= Current.account.conversations.find_by!(
      display_id: params[:conversation_id] || params[:id]
    )
    authorize @conversation, :show?
  end

  def create
    authorize_transfer!

    ActiveRecord::Base.transaction do
      @conversation.update_columns(
        assignee_id: nil,
        team_id: nil,
        status: Conversation.statuses[:pending]
      )
      @conversation.messages.create!(
        content: "Conversa devolvida ao bot por #{current_user.name}",
        message_type: :activity,
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id
      )
    end

    notify_klaos_bridge(@conversation, current_user)

    render json: { success: true, conversation_id: @conversation.display_id }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[TransferToBot] failed conv=#{@conversation&.id}: #{e.class}: #{e.message}")
    render json: { error: 'Transfer failed', detail: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_transfer!
    return if current_user.is_a?(User) && current_user.administrator?
    return if current_user.is_a?(User) && @conversation.inbox.inbox_members.exists?(user_id: current_user.id)

    render json: { error: 'Forbidden' }, status: :forbidden
  end

  def notify_klaos_bridge(conversation, user)
    webhook_url = conversation.account.custom_attributes&.dig('klaos_bridge_webhook_url')
    return if webhook_url.blank?

    payload = {
      type: 'manual_transfer_to_bot',
      account_id: conversation.account_id,
      conversation_display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      initiator: { id: user.id, name: user.name, email: user.email },
      timestamp: Time.current.iso8601
    }

    KlaosBridgeWebhookJob.perform_later(webhook_url, payload)
  rescue StandardError => e
    Rails.logger.warn("[TransferToBot] webhook enqueue failed: #{e.class}: #{e.message}")
  end
end
