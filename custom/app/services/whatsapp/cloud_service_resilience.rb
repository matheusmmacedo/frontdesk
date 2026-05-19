# frozen_string_literal: true

# RESILIENCE PATCH for Whatsapp::Providers::WhatsappCloudService
#
# Sintomas observados em prod (issue do Gustavo):
#   - "Falha ao enviar" toda vez que manda imagem ou áudio.
#
# Causa raiz:
#   1. send_attachment_message (image/video/doc) → manda pra Meta o link
#      signed Supabase (attachment.download_url). Meta faz GET dessa URL.
#      Se Supabase trava/devolve 5xx pra Meta → Meta retorna erro → "falha".
#   2. send_audio_via_media_upload → blob.download(Supabase) + POST(Meta).
#      blob.download falha intermitente → exception sobe → "falha".
#
# Patch:
#   - Retry com exponential backoff em erros transientes.
#   - blob.download separado (catch network errors).
#   - HTTParty.post catch Net::ReadTimeout/Net::OpenTimeout/HTTPError.
#   - Re-resolve a download_url em cada retry (signed URL nova).
#   - Mete um timeout explícito no upload (Meta pode demorar).
#
# Não toca upstream — usa prepend.

module Whatsapp
  module CloudServiceResilience
    MAX_ATTEMPTS = 3
    BACKOFF_SECONDS = [1, 3, 9].freeze # cumulativo

    # Tempo de espera por response do upload Meta. Default HTTParty é 60s,
    # mas em pico Meta pode demorar. Subimos pra 90s.
    UPLOAD_TIMEOUT = 90

    RETRYABLE_NETWORK_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::WriteTimeout,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EPIPE,
      OpenSSL::SSL::SSLError,
      SocketError
    ].freeze

    # Patterns no `external_error` (que vem do Meta) que indicam erro
    # TRANSIENTE — vale retry. Chatwoot só guarda a string da mensagem,
    # não o code, então tem que casar texto.
    # ref: https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes/
    META_RETRYABLE_PATTERNS = [
      /media.*download/i,        # 131053 — Meta não conseguiu baixar mídia do nosso storage
      /failed to download/i,
      /unable to download/i,
      /service unavailable/i,    # 131016
      /temporarily unavailable/i,
      /timeout/i,
      /rate limit/i,             # 130429, 4, 613
      /request limit/i,
      /try again later/i,
      /internal error/i          # erros genéricos transientes Meta
    ].freeze

    def send_attachment_message(phone_number, message)
      with_retry(label: 'send_attachment_message', message: message) do
        super
      end
    end

    def send_audio_via_media_upload(phone_number, message, attachment)
      with_retry(label: 'send_audio_via_media_upload', message: message) do
        super
      end
    end

    private

    def with_retry(label:, message:)
      attempt = 0
      last_error = nil

      while attempt < MAX_ATTEMPTS
        attempt += 1
        begin
          result = yield

          # process_response já tratou erro fatal e marcou message como failed?
          # Se sim, e o erro é retryable, dá pra tentar de novo desfazendo o status.
          if message.reload.status == 'failed' && retryable_meta_error?(message)
            Rails.logger.warn "[WhatsApp][#{label}] Meta retornou erro retryable (tent. #{attempt}/#{MAX_ATTEMPTS}) message_id=#{message.id} status_meta=#{message.external_error}"
            sleep_for_backoff(attempt)
            reset_message_for_retry(message)
            next
          end

          return result
        rescue *RETRYABLE_NETWORK_ERRORS => e
          last_error = e
          Rails.logger.warn "[WhatsApp][#{label}] erro de rede (tent. #{attempt}/#{MAX_ATTEMPTS}) message_id=#{message.id}: #{e.class.name}: #{e.message}"
          if attempt < MAX_ATTEMPTS
            sleep_for_backoff(attempt)
            reset_message_for_retry(message)
            next
          end
          # Esgotou — falha com erro claro pra UI
          message.update!(status: :failed, external_error: "Falha de rede ao enviar (#{e.class.name})")
          raise
        rescue StandardError => e
          # Erro inesperado — não retry, propaga
          Rails.logger.error "[WhatsApp][#{label}] erro inesperado message_id=#{message.id}: #{e.class.name}: #{e.message}"
          raise
        end
      end

      Rails.logger.error "[WhatsApp][#{label}] esgotou #{MAX_ATTEMPTS} tentativas message_id=#{message.id} last_error=#{last_error&.message}"
    end

    def retryable_meta_error?(message)
      err = message.external_error.to_s
      return false if err.blank?

      # Tenta extrair código do formato "131016: ..." OU "code: 131016"
      code_match = err.match(/(?:code[:\s]*)?(\d{3,7})/i)
      return false unless code_match

      code = code_match[1].to_i
      META_RETRYABLE_ERROR_CODES.include?(code)
    end

    def reset_message_for_retry(message)
      message.update_columns(status: Message.statuses[:sent], external_error: nil)
    rescue StandardError => e
      Rails.logger.warn "[WhatsApp] reset_message_for_retry falhou: #{e.message}"
    end

    def sleep_for_backoff(attempt)
      delay = BACKOFF_SECONDS[attempt - 1] || BACKOFF_SECONDS.last
      sleep(delay)
    end
  end
end

# O prepend é aplicado em custom/config/initializers/whatsapp_cloud_service_resilience.rb
# pra garantir que o Zeitwerk carregue a classe upstream antes.
