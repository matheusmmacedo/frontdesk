# frozen_string_literal: true

# KLaOS — Captura completa de erros do webhook de status da Meta.
#
# Bug observado (Mais Saúde 28/05/2026):
#   - 220+ mensagens/dia com status=failed e external_error=NULL
#   - Frontdesk fica cego: nem o usuário nem o admin sabem o motivo real
#
# Causa raiz (app/services/whatsapp/incoming_message_base_service.rb:55-62):
#   def update_message_with_status(message, status)
#     message.status = status[:status]
#     if status[:status] == 'failed' && status[:errors].present?
#       error = status[:errors]&.first
#       message.external_error = "#{error[:code]}: #{error[:title]}"
#     end
#     message.save!
#   end
#
# Quando o webhook do Meta vem em formato NOVO (depois das mudanças 2023+),
# `errors[0]` tem `:message` no lugar de `:title`, ou tem `:error_data.details`,
# ou tem só `:code` sem mais nada. O parser upstream procura por `:title`
# apenas e retorna nil. Resultado: `external_error` fica NULL.
#
# Pior: quando o webhook NÃO tem `errors[]` (caso conhecido em rate limits
# / quality drops do Meta), o `if` falha e o `external_error` fica NULL
# sem qualquer fallback.
#
# Este prepend:
#   1. Sempre loga payload bruto de status pra Railway logs (KEY:
#      [KlaosStatusErrorCapture] payload=...). Permite analisar formatos
#      novos do Meta em produção.
#   2. Extrai erros de TODOS formatos conhecidos (title, message,
#      error_data.details, href). Concatena com `code` quando presente.
#   3. Quando falha sem detalhes, grava
#      "Meta marcou failed sem detalhes (ver Railway logs)"
#      → admin nunca mais fica cego.
#
# Multi-tenant: aplica pra todos os clientes WhatsApp Cloud automaticamente.

module Whatsapp
  module KlaosStatusErrorCapture
    def update_message_with_status(message, status)
      Rails.logger.info(
        "[KlaosStatusErrorCapture] webhook status payload msg_id=#{message.id} " \
        "source_id=#{message.source_id} payload=#{status.to_json}"
      )

      message.status = status[:status]

      if status[:status] == 'failed'
        details = extract_klaos_error_details(status)
        message.external_error = details
        Rails.logger.warn(
          "[KlaosStatusErrorCapture] FAILED msg_id=#{message.id} reason=#{details}"
        )
      end

      message.save!
    end

    private

    def extract_klaos_error_details(status)
      errors = status[:errors] || status['errors']
      if errors.blank?
        return 'Meta marcou failed sem detalhes (ver Railway logs com KlaosStatusErrorCapture)'
      end

      err = errors.first
      return 'Meta enviou errors=[] vazio' if err.blank?

      parts = []
      code = klaos_dig(err, :code, 'code')
      parts << "code=#{code}" if code

      # Formato antigo (Meta 2022 e anterior)
      title = klaos_dig(err, :title, 'title')
      parts << title.to_s if title.present?

      # Formato novo (Meta 2023+)
      msg = klaos_dig(err, :message, 'message')
      parts << msg.to_s if msg.present? && msg != title

      # Formato extra: error_data nested
      details = klaos_dig(err, :error_data, 'error_data')
      if details.is_a?(Hash)
        dd = klaos_dig(details, :details, 'details')
        parts << "details=#{dd}" if dd.present?
      end

      # Link de documentação (Meta às vezes manda)
      href = klaos_dig(err, :href, 'href')
      parts << "ref=#{href}" if href.present?

      result = parts.compact.join(' | ').presence
      result || "Meta enviou errors[] sem code/title/message: #{err.to_json.truncate(300)}"
    end

    def klaos_dig(hash, *keys)
      return nil unless hash.respond_to?(:[])

      keys.each do |k|
        v = hash[k]
        return v if v
      end
      nil
    end
  end
end
