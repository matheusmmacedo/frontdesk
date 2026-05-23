# frozen_string_literal: true

# Devolve conversa ao bot da inbox.
# POST /api/v1/accounts/:account_id/conversations/:conversation_id/transfer_to_bot

class Api::V1::Accounts::TransferToBotController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :authorize_transfer!

  def create
    ActiveRecord::Base.transaction do
      # Reatribui o agent_bot da inbox à conversa: quando o humano assumiu,
      # o callback reset_agent_bot_when_assignee_present zerou assignee_agent_bot_id.
      # Sem reanexar, o Chatwoot Gate do KLaOS vê agent_bot_id=null e decide
      # bot mudo (fail-closed). Reanexar deixa o gate ver cw_bot_attached.
      #
      # NÃO checamos abi.active? aqui porque a flag controla o listener
      # nativo do Chatwoot (que disparia o webhook do bot direto do
      # message_router). KLaOS bypassa o listener — consulta o gate e
      # despacha sua própria pipeline. Pra arquitetura KLaOS, o que importa
      # é "tem bot configurado pra essa inbox?", não "o flag tá ligado?".
      # Em dev a abi normalmente fica status=0 por default (admin nunca
      # tocou no toggle de Settings > Bots), o que com active? quebrava
      # silenciosamente o "Devolver ao bot" — sintoma reportado pelo time
      # do KLaOS em 2026-04-28.
      bot_inbox = @conversation.inbox.agent_bot_inbox
      reattach_bot_id = bot_inbox&.agent_bot_id

      # save! (não update_columns) pra disparar after_update_commit →
      # ActionCable broadcasts (assignee.changed, conversation.updated).
      # Sem isso a sidebar do dashboard fica stale até reload.
      # O callback reset_agent_bot_when_assignee_present retorna early
      # quando assignee_id é blank — então o bot que setamos aqui
      # sobrevive ao save.
      @conversation.assignee_id = nil
      @conversation.team_id = nil
      @conversation.assignee_agent_bot_id = reattach_bot_id
      @conversation.status = :pending
      @conversation.save!
      activity = "Conversa devolvida ao bot por #{current_user.name}"
      activity += ' (com análise imediata)' if analyze_now?
      @conversation.messages.create!(
        content: activity,
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

  # Quando true, o atendente pediu pro bot analisar a conversa AGORA e responder
  # se fizer sentido (em vez de só esperar a próxima mensagem do cliente). Vai no
  # payload do bridge — o agente KLaOS implementa a decisão "devo responder?".
  def analyze_now?
    ActiveModel::Type::Boolean.new.cast(params[:analyze_now]) || false
  end

  def notify_klaos_bridge(conversation, user)
    webhook_url = conversation.account.custom_attributes&.dig('klaos_bridge_webhook_url') ||
                  ENV['KLAOS_BRIDGE_WEBHOOK_URL']
    return if webhook_url.blank?

    secret = ENV['FRONTDESK_BRIDGE_SECRET']

    # KLaOS exige workspace_id no payload (bridgeEvent.controller.ts) — sem ele
    # o webhook é rejeitado com 400 e o status no KLaOS nunca é destravado,
    # deixando o bot mudo. Falha alto pra não voltar a passar despercebido.
    workspace_id = conversation.account.custom_attributes&.dig('klaos_workspace_id')
    if workspace_id.blank?
      Rails.logger.error(
        "[TransferToBot] account=#{conversation.account_id} missing klaos_workspace_id custom_attribute — " \
        "skipping bridge webhook. Bot return won't be honored on KLaOS side until this is set."
      )
      return
    end

    payload = {
      type: 'manual_transfer_to_bot',
      conv_display_id: conversation.display_id,
      workspace_id: workspace_id,
      chatwoot_account_id: conversation.account_id,
      # KLaOS: quando true, rodar o agente sobre o histórico AGORA e responder se
      # fizer sentido (não esperar a próxima mensagem do cliente). Contrato em
      # docs/para-klaos-agent/BRIDGE_ANALYZE_ON_TRANSFER.md. Campo aditivo —
      # KLaOS ignora até implementar (backward-compatible).
      analyze_now: analyze_now?,
      reason: "initiator:#{user.id}:#{user.name}"
    }

    KlaosBridgeWebhookJob.perform_later(webhook_url, payload, secret)
  rescue StandardError => e
    Rails.logger.warn("[TransferToBot] webhook enqueue failed: #{e.class}: #{e.message}")
  end
end
