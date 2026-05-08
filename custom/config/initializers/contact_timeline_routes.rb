# frozen_string_literal: true

# Rota custom pro endpoint de Linha do tempo unificada de contato.
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream.
#
# Endpoint: GET /api/custom/v1/accounts/:account_id/contacts/:contact_id/timeline
# Auth: header `api_access_token` (mesma da API V1)

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/contacts/:contact_id/timeline',
      to: 'api/custom/v1/accounts/contact_timeline#index',
      as: :api_custom_v1_account_contact_timeline
end
