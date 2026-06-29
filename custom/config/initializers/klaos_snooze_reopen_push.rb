# frozen_string_literal: true

# KLaOS — Push notification quando conv reabre de snooze (fix queixa Gustavo).
#
# Bug original: agente "adia" conv pra X hora. Job ReopenSnoozedConversationsJob
# roda no horário e abre a conv (status snoozed → open) corretamente. MAS
# Chatwoot vanilla NÃO gera Notification do tipo "snooze_reopen" — só pra
# assignment/mention/new_message. Resultado: agente só vê a conv voltar se
# tiver tela aberta + WebSocket conectado. Fechou navegador? Perde.
#
# Fix: hook custom after_update_commit em Conversation que detecta o
# status_change snoozed→open e envia Web Push direto pro assignee humano
# (sem criar Notification model — porque o enum upstream não tem o tipo
# certo). Service Worker do Chatwoot já intercepta push e mostra notification
# mesmo com tela fechada.
#
# Dedup: 5min por conv via Redis::Alfred (evita spam se job tentar reabrir 2x).
#
# Cobre: assignee humano com browser_push subscription. FCM mobile fica pra
# Fase 2 (Mais Saúde prod usa só browser push hoje).

module KlaosSnoozeReopenPush
  extend ActiveSupport::Concern

  REOPEN_COOLDOWN_KEY = 'klaos:snooze_reopen_push:conv:%<id>d'
  REOPEN_COOLDOWN_SECONDS = 300

  included do
    after_update_commit :klaos_dispatch_snooze_reopen_push, if: :klaos_just_reopened_from_snooze?
  end

  private

  def klaos_just_reopened_from_snooze?
    return false unless saved_change_to_status?

    old_status, new_status = saved_change_to_status
    old_status.to_s == 'snoozed' && new_status.to_s == 'open'
  end

  def klaos_dispatch_snooze_reopen_push
    return if assignee_id.blank?

    cache_key = format(REOPEN_COOLDOWN_KEY, id: id)
    return if ::Redis::Alfred.get(cache_key).present?

    ::Redis::Alfred.setex(cache_key, true, REOPEN_COOLDOWN_SECONDS)

    Klaos::SnoozeReopenPushJob.perform_later(id, assignee_id)
  rescue StandardError => e
    Rails.logger.warn "[KlaosSnoozeReopenPush] dispatch falhou conv=#{id}: #{e.class}: #{e.message}"
  end
end

module Klaos
  class SnoozeReopenPushJob < ApplicationJob
    queue_as :medium

    def perform(conversation_id, user_id)
      conversation = Conversation.find_by(id: conversation_id)
      return if conversation.blank?

      user = User.find_by(id: user_id)
      return if user.blank?

      user.notification_subscriptions.each do |subscription|
        if subscription.browser_push?
          deliver_browser_push(conversation, user, subscription)
        end
        # FCM mobile: pular (Mais Saúde só usa browser push hoje).
      end
    end

    private

    def deliver_browser_push(conversation, user, subscription)
      return if VapidService.public_key.blank?

      payload_json = JSON.generate(
        title: "🔔 Conversa #{conversation.display_id} voltou do adiar",
        body: conversation.contact&.name.presence || 'Cliente',
        tag: "snooze_reopen_#{conversation.display_id}",
        url: deep_link(conversation)
      )

      WebPush.payload_send(
        message: payload_json,
        endpoint: subscription.subscription_attributes['endpoint'],
        p256dh: subscription.subscription_attributes['p256dh'],
        auth: subscription.subscription_attributes['auth'],
        vapid: {
          subject: deep_link(conversation),
          public_key: VapidService.public_key,
          private_key: VapidService.private_key
        },
        ssl_timeout: 5,
        open_timeout: 5,
        read_timeout: 5
      )

      Rails.logger.info(
        "[KlaosSnoozeReopenPush] browser push enviado user=#{user.email} conv=#{conversation.display_id}"
      )
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized => e
      Rails.logger.info "[KlaosSnoozeReopenPush] subscription expirada user=#{user.id}: #{e.message}"
      subscription.destroy!
    rescue WebPush::TooManyRequests => e
      Rails.logger.warn "[KlaosSnoozeReopenPush] rate limit user=#{user.id}: #{e.message}"
    rescue Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error "[KlaosSnoozeReopenPush] timeout user=#{user.id}: #{e.message}"
    rescue StandardError => e
      Rails.logger.warn(
        "[KlaosSnoozeReopenPush] erro user=#{user.id} conv=#{conversation.id}: #{e.class}: #{e.message}"
      )
    end

    def deep_link(conversation)
      base = ENV.fetch('FRONTEND_URL', 'https://app-desk.klaos.ai')
      "#{base}/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}"
    end
  end
end

Rails.application.config.to_prepare do
  conversation_class = 'Conversation'.safe_constantize
  if conversation_class && !conversation_class.include?(KlaosSnoozeReopenPush)
    conversation_class.include(KlaosSnoozeReopenPush)
    Rails.logger.info '[KlaosSnoozeReopenPush] included on Conversation'
  end
end
