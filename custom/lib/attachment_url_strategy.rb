# frozen_string_literal: true

# ATTACHMENT URL STRATEGY — proxy pra imagem/file, redirect pra áudio/vídeo
#
# Contexto: ActiveStorage proxy mode (resolve_model_to_route = :rails_storage_proxy)
# resolve o "indisponível intermitente" pra imagens (URLs estáveis,
# Cache-Control 100 anos, browser cacheia eternamente).
#
# Mas proxy mode usa send_blob_stream → ActionController::Live → chunked
# transfer encoding → SEM Content-Length. Player HTML5 <audio>/<video>
# precisa de Content-Length pra calcular `duration` no metadata load
# → sem isso aparece "Infinity:NaN".
#
# Solução: pra áudio/vídeo, força o uso de redirect URL (signed Supabase),
# que tem Content-Length nativo. Pra imagem/file, mantém proxy (mais
# importante o cache estável que duração de player).
#
# Trade-off: signed URL áudio/vídeo expira em 24h (service_urls_expire_in).
# Pra atendimento normal (áudio escutado em minutos/horas) é OK. Se ficar
# pendente >24h, refresh resolve.

module AttachmentUrlStrategy
  AUDIO_VIDEO_TYPES = %w[audio video].freeze

  def file_url
    return '' unless file.attached?

    if AUDIO_VIDEO_TYPES.include?(file_type)
      # Força redirect (não proxy) — gera signed URL Supabase com
      # Content-Length nativo pro player HTML5 ler duração.
      Rails.application.routes.url_helpers.rails_storage_redirect_url(file)
    else
      super
    end
  end
end
