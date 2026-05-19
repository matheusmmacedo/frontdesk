# frozen_string_literal: true

# FIX — ActiveStorage proxy controller serve conteúdo sem Content-Length
#
# Quando `resolve_model_to_route = :rails_storage_proxy` está ativo,
# `<audio src>` e `<video src>` mostram duração "Infinity:NaN" porque
# o Rails serve via `send_blob_stream` → chunked transfer encoding →
# sem Content-Length → player HTML5 não consegue calcular duração.
#
# Range requests funcionam (seek), mas o pre-roll para calcular a
# duração total no load inicial NÃO funciona sem Content-Length.
#
# Fix: pra requests SEM Range, baixa o blob inteiro em memória e
# manda via send_data (que seta Content-Length). Pra requests COM
# Range, mantém comportamento padrão (já funciona porque mandar
# range já implica Content-Length do chunk).
#
# Limite: arquivo > 50MB cai no fluxo padrão (streaming chunked,
# sem Content-Length) pra não estourar memória. WhatsApp limita
# áudio em 16MB e imagem em 5MB, então 99% dos arquivos couber.

module ActiveStorageProxyWithContentLength
  def show
    if request.headers['Range'].present?
      super
      return
    end

    if @blob.byte_size.to_i > 50.megabytes
      super
      return
    end

    # Carrega blob inteiro em memória e serve com Content-Length.
    # Browser consegue calcular duração de áudio/vídeo + Cache-Control
    # idêntico ao do http_cache_forever (~100 anos).
    data = String.new
    @blob.download { |chunk| data << chunk }

    response.headers['Cache-Control'] = 'public, max-age=3155695200'
    response.headers['Accept-Ranges'] = 'bytes'

    send_data data,
              filename: @blob.filename.sanitized,
              disposition: action_dispositions(params[:disposition] || 'inline', @blob.content_type),
              type: @blob.content_type
  end
end
