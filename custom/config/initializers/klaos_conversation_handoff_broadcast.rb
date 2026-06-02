# frozen_string_literal: true

# KLaOS — Broadcast custom quando o assignee de uma conversa muda
# (alerta de transferência, paridade Kualiz).
#
# Cenários cobertos:
#   1) Conv atribuída a mim (handoff IN)
#      → ActionCable event 'klaos.conversation_assigned_to_me' pro
#         pubsub_token do NOVO assignee
#   2) Conv tirada de mim (handoff OUT)
#      → ActionCable event 'klaos.conversation_unassigned_from_me'
#         pro pubsub_token do ANTIGO assignee
#
# Frontend escuta via mitt emitter (que recebe broadcasts ActionCable) e
# exibe banner discreto + som leve (ConversationHandoffAlert.vue).
#
# Diferente do Snooze Reopen (que loops audio + pulse forte), aqui é
# alerta MAIS DISCRETO porque acontece com mais frequência durante o
# turno e não pode atrapalhar atendimento.

module KlaosConversationHandoffBroadcast
  KLAOS_ASSIGNED_TO_ME_EVENT       = 'klaos.conversation_assigned_to_me'
  KLAOS_UNASSIGNED_FROM_ME_EVENT   = 'klaos.conversation_unassigned_from_me'

  extend ActiveSupport::Concern

  included do
    after_update_commit :klaos_broadcast_handoff, if: :saved_change_to_assignee_id?
  end

  private

  def klaos_broadcast_handoff
    previous_id, new_id = saved_change_to_assignee_id
    return if previous_id == new_id

    payload = klaos_handoff_payload(previous_id, new_id)

    klaos_broadcast_to_user(new_id, KLAOS_ASSIGNED_TO_ME_EVENT, payload) if new_id.present?
    if previous_id.present? && previous_id != new_id
      klaos_broadcast_to_user(previous_id, KLAOS_UNASSIGNED_FROM_ME_EVENT, payload)
    end
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosConversationHandoffBroadcast] broadcast failed conv=#{id}: #{e.class}: #{e.message}"
    )
  end

  def klaos_broadcast_to_user(user_id, event, payload)
    user  = User.find_by(id: user_id)
    token = user&.pubsub_token
    return if token.blank?

    ::ActionCableBroadcastJob.perform_later([token], event, payload)
  end

  def klaos_handoff_payload(previous_id, new_id)
    {
      conversation_id: id,
      conversation_display_id: display_id,
      contact_name: contact&.name,
      previous_assignee: klaos_assignee_summary(previous_id),
      new_assignee: klaos_assignee_summary(new_id),
      account_id: account_id,
      inbox_name: inbox&.name
    }
  end

  def klaos_assignee_summary(user_id)
    return nil if user_id.blank?

    u = User.find_by(id: user_id)
    return nil if u.nil?

    { id: u.id, name: u.available_name }
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.include?(KlaosConversationHandoffBroadcast)

  Conversation.include(KlaosConversationHandoffBroadcast)
  Rails.logger.info '[KlaosConversationHandoffBroadcast] included on Conversation'
end
