# frozen_string_literal: true

# KLaOS — Auto-atribuir conversa ao remetente quando enviar template
# (Item 2 do Gustavo).
#
# Pedido: ao disparar template ativo (notificação), a conversa cai em
# "Minhas" do remetente automaticamente. Hoje o template sai mas a
# conversa fica sem assignee_id, então o agente perde de vista a conv.
#
# Comportamento universal (decidido em 29/05/2026): SEMPRE ativo pra
# todos os clientes Frontdesk, sem toggle. Justificativa: quem dispara
# template ativo está iniciando comunicação intencional — natural que
# vire dono da conversa. Se um dia algum cliente reclamar, podemos
# voltar a colocar toggle, mas começamos com default sensato.
#
# Detecção de template: message_type == :template OU additional_attributes
# tem `template_params` (Chatwoot marca de jeitos diferentes dependendo do
# canal — coalescemos os dois pra robustez).

module KlaosAutoAssignOnTemplate
  extend ActiveSupport::Concern

  included do
    after_create :klaos_auto_assign_if_template
  end

  private

  def klaos_auto_assign_if_template
    return unless klaos_should_auto_assign?

    conversation.update_column(:assignee_id, sender_id)
    Rails.logger.info(
      "[KlaosAutoAssignOnTemplate] conv=#{conversation_id} assigned to user=#{sender_id} after template msg=#{id}"
    )
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosAutoAssignOnTemplate] falhou conv=#{conversation_id}: #{e.class}: #{e.message}"
    )
  end

  def klaos_should_auto_assign?
    return false if conversation.blank? || sender_id.blank?
    return false if conversation.assignee_id.present?
    return false unless sender_type == 'User'
    return false unless klaos_is_template_message?

    true
  end

  def klaos_is_template_message?
    return true if message_type.to_s == 'template'
    return true if additional_attributes.is_a?(Hash) &&
                   additional_attributes['template_params'].present?

    false
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosAutoAssignOnTemplate)

  Message.include(KlaosAutoAssignOnTemplate)
  Rails.logger.info '[KlaosAutoAssignOnTemplate] included on Message'
end
