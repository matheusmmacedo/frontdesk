# frozen_string_literal: true

# KLaOS — Job que envia Web Push quando conv reabre do snooze.
# Enfileirado pelo hook KlaosSnoozeReopenPush no model Conversation.
# Não usa Notification model — envia push direto via WebPush + VAPID,
# porque enum upstream não tem tipo "reopened_from_snooze".
#
# Doc/contexto: custom/config/initializers/klaos_snooze_reopen_push.rb

module Klaos
  class SnoozeReopenPushJob < ApplicationJob
    queue_as :medium

    def perform(conversation_id, user_id)
      conversation = Conversation.find_by(id: conversation_id)
      return if conversation.blank?

      user = User.find_by(id: user_id)
      return if user.blank?

      user.notification_subscriptions.each do |subscription|
        deliver_browser_push(conversation, user, subscription) if subscription.browser_push?
        # FCM mobile: Mais Saúde só usa browser push hoje; pular.
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
