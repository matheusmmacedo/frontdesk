# frozen_string_literal: true

# Devolve conversa ao bot da inbox.
# POST /api/v1/accounts/:account_id/conversations/:conversation_id/transfer_to_bot

class Api::V1::Accounts::TransferToBotController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :authorize_transfer!

  def create
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

  def set_conversation
    id_param = params[:conversation_id] || params[:id]
    @conversation = Current.account.conversations.find_by!(display_id: id_param)
  end

  def authorize_transfer!
    return if current_user.is_a?(User) && current_user.administrator?
    return if current_user.is_a?(User) && @conversation.inbox.inbox_members.exists?(user_id: current_user.id)

    render json: { error: 'Forbidden' }, status: :forbidden
  end

  def notify_klaos_bridge(conversation, user)
    webhook_url = conversation.account.custom_attributes&.dig('klaos_bridge_webhook_url') ||
                  ENV['KLAOS_BRIDGE_WEBHOOK_URL']
    return if webhook_url.blank?

    secret = ENV['FRONTDESK_BRIDGE_SECRET']

    # Payload conforme o contrato do KLaOS (docs/para-frontdesk-agent/KLAOS_UPDATES.md)
    workspace_id = conversation.account.custom_attributes&.dig('klaos_workspace_id')
    payload = {
      type: 'manual_transfer_to_bot',
      conv_display_id: conversation.display_id,
      workspace_id: workspace_id,
      reason: "initiator:#{user.id}:#{user.name}"
    }

    KlaosBridgeWebhookJob.perform_later(webhook_url, payload, secret)
  rescue StandardError => e
    Rails.logger.warn("[TransferToBot] webhook enqueue failed: #{e.class}: #{e.message}")
  end
end
