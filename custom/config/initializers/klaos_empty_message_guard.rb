# frozen_string_literal: true

# KLaOS — Bloqueia outgoing messages vazias (defesa em profundidade).
#
# Bug raiz reproduzido em DEV (28/05/2026) + observado em prod:
#   - Composer (ReplyBox.vue) tem bug onde `hasRecordedAudio` é setado
#     incondicionalmente em onFinishRecorder, mesmo quando o upload do
#     arquivo de áudio falha. Botão Send fica habilitado, agente clica,
#     POST chega com content='' e files=undefined.
#   - Backend Messages::MessageBuilder não valida content vazio nem
#     atachments vazios → cria msg, vai pro Meta, Meta rejeita
#     "text.body required" (janela 24h) ou "Template not found" (fora janela).
#
# Bug confirmado nativo do Chatwoot (não introduzido por KLaOS):
#   - git blame: Sojan Jose 2020 / Pranav/giquieu/Sivin 2022-2024
#   - upstream/develop e upstream/master têm código IDÊNTICO
#
# Este guard rejeita ANTES de salvar quando:
#   - message_type = outgoing
#   - content em branco (nil ou "")
#   - sem attachments
#   - sem template params (additional_attributes['template_params'])
#
# Multi-tenant — vale pra qualquer canal (WhatsApp, FB, Instagram, etc).
# Sintoma pro agente: erro claro no momento do submit em vez de "msg
# enviada que depois aparece como falha".

module KlaosEmptyMessageGuard
  extend ActiveSupport::Concern

  included do
    before_validation :klaos_reject_empty_outgoing
  end

  private

  def klaos_reject_empty_outgoing
    return unless message_type == 'outgoing' || message_type == :outgoing
    return if private?
    return if klaos_has_content?
    return if klaos_has_attachments?
    return if klaos_has_template?

    errors.add(:base, 'Mensagem vazia bloqueada: precisa de texto OU anexo. ' \
                      'Possível causa: gravação de áudio falhou ao subir.')
    throw(:abort)
  end

  def klaos_has_content?
    content.present? && content.to_s.strip != ''
  end

  def klaos_has_attachments?
    # attachments coleção pode estar em memória (build) ou já persistida.
    attachments.any? { |a| a.present? }
  end

  def klaos_has_template?
    additional_attributes.is_a?(Hash) &&
      additional_attributes['template_params'].present?
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosEmptyMessageGuard)

  Message.include(KlaosEmptyMessageGuard)
  Rails.logger.info '[KlaosEmptyMessageGuard] included on Message'
end
