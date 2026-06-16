# frozen_string_literal: true

# KLaOS — "Marcar como não lida" funciona em qualquer conv, inclusive
# disparos outgoing sem resposta do cliente (templates de cobrança/
# marketing onde cliente nunca respondeu).
#
# Bug original (reportado 16/06): clicar "Marcar como não lida" na conv
# da STELLA ZAPPI GOMES (display 1791) não fazia nada visualmente. Causa:
# o controller upstream usa `messages.incoming.last.created_at - 1.second`
# como `agent_last_seen_at` — se NÃO TEM mensagem incoming (cliente nunca
# respondeu), `last_seen_at` vira nil, salva nil no DB, e `unread_count`
# calculado pelo serializer sempre dá 0 (cálculo é COUNT incoming WHERE
# created_at > agent_last_seen_at; sem incoming, count = 0). Resultado:
# badge não aparece.
#
# Fix: além do comportamento upstream, persistir um timestamp em
# `additional_attributes['klaos_marked_unread_at']` que o frontend lê pra
# pintar a card como não-lida independente do unread_count. Quando o
# agente vê a conv (update_last_seen), o attribute é limpo.

module KlaosMarkUnread
  KLAOS_UNREAD_KEY = 'klaos_marked_unread_at'
  # Quando o agente abre/lê uma conv que voltou do snooze, limpar o
  # timestamp também — sem isso o SnoozeReturnPulse re-aplica o pulse
  # a cada 60s. Gustavo reportou (16/06): "alerta com reloginho piscando,
  # clico e volta".
  KLAOS_SNOOZE_RETURNED_KEY = 'klaos_returned_from_snooze_at'

  def unread
    super
    klaos_persist_marked_unread!
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosMarkUnread] persist falhou conv=#{@conversation&.id}: #{e.message}"
    )
  end

  def update_last_seen
    klaos_clear_marked_unread!
    super
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosMarkUnread] clear falhou conv=#{@conversation&.id}: #{e.message}"
    )
  end

  private

  def klaos_persist_marked_unread!
    return if @conversation.blank?

    extras = (@conversation.additional_attributes || {}).merge(
      KLAOS_UNREAD_KEY => Time.current.iso8601
    )
    # update_columns pra pular callbacks. O broadcast da mudança vai pela
    # action_cable do upstream via update_last_seen_on_conversation que
    # super chamou. Frontend escuta `conversation.updated` e re-renderiza
    # a card com o badge.
    @conversation.update_columns(additional_attributes: extras)
    klaos_broadcast_attr_change
  end

  def klaos_clear_marked_unread!
    return if @conversation.blank?

    extras = @conversation.additional_attributes || {}
    # Limpa AMBOS: marked_unread (badge "!") e returned_from_snooze (pulse ⏰).
    # Os dois somem quando o agente abre a conv.
    return unless extras.key?(KLAOS_UNREAD_KEY) || extras.key?(KLAOS_SNOOZE_RETURNED_KEY)

    extras = extras.dup
    extras.delete(KLAOS_UNREAD_KEY)
    extras.delete(KLAOS_SNOOZE_RETURNED_KEY)
    @conversation.update_columns(additional_attributes: extras)
  end

  # Dispara update event manualmente porque update_columns não dispara
  # callbacks. Frontend precisa receber pra re-renderizar a card.
  def klaos_broadcast_attr_change
    return if @conversation.blank?

    payload = @conversation.reload.push_event_data
    ::ActionCableBroadcastJob.perform_later(
      @conversation.account.users.pluck(:pubsub_token).compact.uniq,
      Events::Types::CONVERSATION_UPDATED,
      payload
    )
  end
end

Rails.application.config.to_prepare do
  # Em Rails 7 com Zeitwerk, `defined?` pode falhar com classes autoload-lazy
  # antes do controller ser tocado pela primeira vez. Forçar via
  # safe_constantize que dispara o autoload corretamente.
  controller = 'Api::V1::Accounts::ConversationsController'.safe_constantize
  next unless controller
  next if controller.include?(KlaosMarkUnread)

  controller.prepend(KlaosMarkUnread)
  Rails.logger.info '[KlaosMarkUnread] prepended on ConversationsController'
end
