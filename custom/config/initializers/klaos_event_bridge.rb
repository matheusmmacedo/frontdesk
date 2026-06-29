# frozen_string_literal: true

# KLaOS — Bridge de eventos Frontdesk → KLaOS (Fase 1 sync bidirecional).
#
# Adiciona suporte a webhooks pra mudanças que Chatwoot vanilla não emite:
#   - inbox_deleted (vanilla só emite created/updated)
#   - team_created / team_updated / team_deleted
#   - agent_bot_assigned / agent_bot_unassigned (em inbox)
#
# Eventos são entregues como WebhookJob normal:
#   - reutilizam webhook account-level já existente
#   - usam o secret per-webhook pra HMAC X-Chatwoot-Signature
#   - URL configurada via UI/API do Chatwoot pelo KLaOS
#
# Por que NÃO passamos pelo Rails dispatcher: pra não acoplar com mudanças
# em WebhookListener e EventDispatcherJob. A reentrega aqui é mínima
# (replica deliver_account_webhooks).
#
# Pra o KLaOS receber, o webhook account-level dele precisa ter os eventos
# acima nas `subscriptions`. A extensão de Webhook::ALLOWED_WEBHOOK_EVENTS
# abaixo permite que ele salve essas subscriptions via API/UI normal.
#
# Doc: docs/para-frontdesk-agent/BRIEF_sync_bidirecional_klaos_frontdesk.md

# Service-like que despacha um payload pros webhooks account-level
# que assinam o evento. Replica WebhookListener#deliver_account_webhooks
# pra evitar precisar prependear nele.
module KlaosEventBridge
  module_function

  def deliver(account, event_name, payload)
    return if account.nil?

    account.webhooks.account_type.find_each do |webhook|
      next unless webhook.subscriptions.include?(event_name)

      WebhookJob.perform_later(
        webhook.url,
        payload,
        :account_webhook,
        secret: webhook.secret,
        delivery_id: SecureRandom.uuid
      )
    end
  rescue StandardError => e
    Rails.logger.warn "[KlaosEventBridge] deliver event=#{event_name} falhou: #{e.class}: #{e.message}"
  end
end

KLAOS_EVENT_BRIDGE_EXTRA_EVENTS = %w[
  inbox_deleted
  team_created team_updated team_deleted
  agent_bot_assigned agent_bot_unassigned
].freeze

# Override do validate_webhook_subscriptions via prepend. NÃO mexe na
# constante ALLOWED_WEBHOOK_EVENTS porque o método original do Webhook usa
# constant lookup via Module.nesting que pode ser cacheado por Bootsnap ou
# resetado em reload (tentativa anterior com remove_const+const_set não
# funcionou em runtime, persistia 422). Prepend de validator é a forma
# robusta: substitui o método em si na chain de lookup.
module KlaosWebhookAllowExtraEvents
  def validate_webhook_subscriptions
    allowed = self.class::ALLOWED_WEBHOOK_EVENTS + KLAOS_EVENT_BRIDGE_EXTRA_EVENTS
    invalid = !subscriptions.instance_of?(Array) ||
              subscriptions.blank? ||
              (subscriptions.uniq - allowed).length.positive?
    errors.add(:subscriptions, I18n.t('errors.webhook.invalid')) if invalid
  end
end

Rails.application.config.to_prepare do
  # Prepend do override do validator. Idempotente (não-prepend duplicado).
  webhook_class = 'Webhook'.safe_constantize
  if webhook_class && !webhook_class.include?(KlaosWebhookAllowExtraEvents)
    webhook_class.prepend(KlaosWebhookAllowExtraEvents)
    Rails.logger.info "[KlaosEventBridge] Webhook#validate_webhook_subscriptions prepended pra aceitar #{KLAOS_EVENT_BRIDGE_EXTRA_EVENTS.inspect}"
  end

  # ---- Inbox: only `inbox_deleted` é novo (created/updated já em WebhookListener) ----
  inbox_class = 'Inbox'.safe_constantize
  if inbox_class && !inbox_class.method_defined?(:klaos_event_bridge_attached)
    inbox_class.class_eval do
      after_destroy_commit :klaos_dispatch_inbox_deleted

      def klaos_dispatch_inbox_deleted
        return if account.nil?

        payload = {
          event: 'inbox_deleted',
          account_id: account_id,
          inbox: {
            id: id,
            name: name,
            channel_type: channel_type,
            deleted_at: Time.current.iso8601
          }
        }
        KlaosEventBridge.deliver(account, 'inbox_deleted', payload)
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] inbox_deleted dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_event_bridge_attached
        true
      end
    end
    Rails.logger.info '[KlaosEventBridge] Inbox#after_destroy_commit registrado'
  end

  # ---- Team: created / updated / deleted ----
  team_class = 'Team'.safe_constantize
  if team_class && !team_class.method_defined?(:klaos_event_bridge_attached)
    team_class.class_eval do
      after_create_commit :klaos_dispatch_team_created
      after_update_commit :klaos_dispatch_team_updated, if: :klaos_team_significant_change?
      after_destroy_commit :klaos_dispatch_team_deleted

      # Filtra mudanças triviais — só dispara quando name/description/auto_assign
      # mudam. Evita ruído de touch (members_count etc).
      def klaos_team_significant_change?
        saved_change_to_name? || saved_change_to_description? || saved_change_to_allow_auto_assign?
      end

      def klaos_dispatch_team_created
        return if account.nil?

        KlaosEventBridge.deliver(account, 'team_created', {
                                   event: 'team_created',
                                   account_id: account_id,
                                   team: klaos_team_payload
                                 })
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] team_created dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_dispatch_team_updated
        return if account.nil?

        KlaosEventBridge.deliver(account, 'team_updated', {
                                   event: 'team_updated',
                                   account_id: account_id,
                                   team: klaos_team_payload,
                                   changed_attributes: saved_changes.except('updated_at')
                                 })
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] team_updated dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_dispatch_team_deleted
        return if account.nil?

        KlaosEventBridge.deliver(account, 'team_deleted', {
                                   event: 'team_deleted',
                                   account_id: account_id,
                                   team: { id: id, name: name, deleted_at: Time.current.iso8601 }
                                 })
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] team_deleted dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_team_payload
        {
          id: id,
          name: name,
          description: description,
          allow_auto_assign: allow_auto_assign
        }
      end

      def klaos_event_bridge_attached
        true
      end
    end
    Rails.logger.info '[KlaosEventBridge] Team callbacks (created/updated/deleted) registrados'
  end

  # ---- AgentBotInbox: assigned (create) / unassigned (destroy) ----
  # Esses eventos têm inbox.channel_type embutido no payload — KLaOS
  # pediu pra evitar 2ª chamada de lookup (Q1 do brief).
  agent_bot_inbox_class = 'AgentBotInbox'.safe_constantize
  if agent_bot_inbox_class && !agent_bot_inbox_class.method_defined?(:klaos_event_bridge_attached)
    agent_bot_inbox_class.class_eval do
      after_create_commit :klaos_dispatch_agent_bot_assigned
      after_destroy_commit :klaos_dispatch_agent_bot_unassigned

      def klaos_dispatch_agent_bot_assigned
        return if inbox.nil? || inbox.account.nil?

        KlaosEventBridge.deliver(inbox.account, 'agent_bot_assigned', klaos_agent_bot_payload('agent_bot_assigned'))
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] agent_bot_assigned dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_dispatch_agent_bot_unassigned
        return if inbox.nil? || inbox.account.nil?

        KlaosEventBridge.deliver(inbox.account, 'agent_bot_unassigned', klaos_agent_bot_payload('agent_bot_unassigned'))
      rescue StandardError => e
        Rails.logger.warn "[KlaosEventBridge] agent_bot_unassigned dispatch falhou id=#{id}: #{e.class}: #{e.message}"
      end

      def klaos_agent_bot_payload(event)
        {
          event: event,
          account_id: inbox.account_id,
          inbox_id: inbox_id,
          inbox: {
            id: inbox.id,
            name: inbox.name,
            channel_type: inbox.channel_type
          },
          agent_bot_id: agent_bot_id,
          status: status
        }
      end

      def klaos_event_bridge_attached
        true
      end
    end
    Rails.logger.info '[KlaosEventBridge] AgentBotInbox callbacks (assigned/unassigned) registrados'
  end
end
