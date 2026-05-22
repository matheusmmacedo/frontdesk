# frozen_string_literal: true

# KLaOS — Media proxy com Content-Length (fix definitivo de "mídia indisponível").
#
# Problema: o proxy do ActiveStorage usa ActionController::Live → streaming
# chunked → SEM Content-Length → player HTML5 de áudio/vídeo não calcula a
# duração ("Infinity:NaN"). Por isso áudio/vídeo estavam em modo REDIRECT, que
# resolve numa signed URL do Supabase com TTL (expira → "indisponível após um
# tempo").
#
# Este controller serve o blob DIRETO (não-Live), setando:
#   - Content-Length (player calcula duração)
#   - Accept-Ranges/Range 206 (seek)
#   - Cache-Control longo + immutable (Cloudflare/browser cacheiam → URL estável,
#     nunca expira; bytes baixados ~1x)
#   - retry no download (resiliência a blip do Supabase) e SEM cachear erro
#
# URL: GET /api/custom/v1/media/:signed_id/*filename  (signed_id = blob.signed_id,
# permanente). Público (o signed_id é a credencial) — herda ActionController::Base
# direto pra NÃO pegar auth/CSRF do app nem o ActionController::Live do AS.
#
# Mídia (áudio/vídeo/imagem) é pequena → blob.download em memória é aceitável.
class Api::Custom::V1::MediaController < ActionController::Base
  CACHE_CONTROL = 'public, max-age=31536000, immutable'
  MAX_DOWNLOAD_ATTEMPTS = 3

  def show
    blob = ActiveStorage::Blob.find_signed(params[:signed_id])
    return error(:not_found) if blob.nil?

    data = download_with_retry(blob)
    return error(:bad_gateway) if data.nil?

    response.headers['Accept-Ranges'] = 'bytes'
    response.headers['Cache-Control'] = CACHE_CONTROL

    range = request.headers['Range']
    match = range.present? ? range.match(/bytes=(\d+)-(\d*)/) : nil

    if match
      from = match[1].to_i
      to = match[2].present? ? match[2].to_i : (blob.byte_size - 1)
      to = blob.byte_size - 1 if to >= blob.byte_size
      from = 0 if from.negative? || from > to
      slice = data.byteslice(from, (to - from + 1)) || ''
      response.headers['Content-Range'] = "bytes #{from}-#{to}/#{blob.byte_size}"
      send_data slice, type: blob.content_type, disposition: 'inline',
                       filename: blob.filename.to_s, status: :partial_content
    else
      send_data data, type: blob.content_type, disposition: 'inline',
                      filename: blob.filename.to_s
    end
  rescue StandardError => e
    Rails.logger.error "[MediaProxy] erro signed_id=#{params[:signed_id]}: #{e.class}: #{e.message}"
    error(:bad_gateway)
  end

  private

  # Não cacheia erro (pra um blip transiente não "grudar" no Cloudflare/browser).
  def error(status)
    response.headers['Cache-Control'] = 'no-store'
    head status
  end

  def download_with_retry(blob)
    attempts = 0
    begin
      attempts += 1
      blob.download
    rescue StandardError => e
      if attempts < MAX_DOWNLOAD_ATTEMPTS
        sleep(0.3 * attempts)
        retry
      end
      Rails.logger.error "[MediaProxy] download falhou após #{attempts} tentativas (blob #{blob.id}): #{e.class}: #{e.message}"
      nil
    end
  end
end
