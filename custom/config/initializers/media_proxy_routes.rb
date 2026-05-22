# frozen_string_literal: true

# Rota do media proxy custom (Content-Length + cache + range).
# Append pra não tocar config/routes.rb upstream.
#
# GET /api/custom/v1/media/:signed_id/*filename
#   signed_id = blob.signed_id (purpose blob_id, permanente)
#   *filename = nome do arquivo (glob, aceita pontos/extensão)
#   format: false → extensão (.ogg/.jpg) não é parseada como formato
Rails.application.routes.append do
  get '/api/custom/v1/media/:signed_id/*filename',
      to: 'api/custom/v1/media#show',
      as: :klaos_media,
      format: false
end
