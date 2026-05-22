# frozen_string_literal: true

# ATTACHMENT URL STRATEGY — toda mídia pelo proxy custom com Content-Length
#
# Contexto/histórico:
#   - Imagem: proxy mode (resolve_model_to_route = :rails_storage_proxy) resolveu
#     o "indisponível intermitente" (URL estável, cache longo).
#   - Áudio/vídeo: o proxy upstream usa ActionController::Live → chunked → SEM
#     Content-Length → player HTML5 dá "Infinity:NaN". Por isso ficaram em
#     REDIRECT (signed URL Supabase tem Content-Length nativo) — MAS a signed URL
#     expira (service_urls_expire_in) → "indisponível após um tempo".
#
# Fix definitivo: TODA mídia (image/audio/video) passa a usar o proxy custom
# (Api::Custom::V1::MediaController), que serve o blob com Content-Length +
# Accept-Ranges + Cache-Control longo + retry. Resultado:
#   - URL permanente e cacheável (Cloudflare) → nunca expira.
#   - Content-Length presente → player calcula duração (sem Infinity:NaN).
#   - Range/seek funciona.
#
# Documentos (file) seguem no proxy upstream (super) — não precisam de duração.
#
# Attachment#download_url continua direto pro Supabase (Meta WhatsApp fetcha de lá).

module AttachmentUrlStrategy
  MEDIA_TYPES = %w[image audio video].freeze

  def file_url
    return '' unless file.attached?
    return super unless MEDIA_TYPES.include?(file_type)

    blob = file.blob
    Rails.application.routes.url_helpers.klaos_media_url(
      signed_id: blob.signed_id,
      filename: blob.filename.to_s
    )
  rescue StandardError => e
    # Rota custom indisponível / host ausente → cai pro comportamento upstream.
    Rails.logger&.warn("[AttachmentUrlStrategy] fallback pra super: #{e.class}: #{e.message}")
    super
  end
end
