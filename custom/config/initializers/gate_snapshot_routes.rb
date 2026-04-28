# frozen_string_literal: true

# Rota custom pro endpoint do Chatwoot Gate (KLaOS).
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream
# (sobrevive merge). O append roda depois do routes.rb principal — rotas
# registradas aqui ficam no fim da tabela.
#
# Endpoint: GET /api/custom/v1/accounts/:account_id/conversations/:conversation_id/gate_snapshot
# Auth:     header `api_access_token` (mesma da API V1)

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/conversations/:conversation_id/gate_snapshot',
      to: 'api/custom/v1/accounts/gate_snapshot#show',
      as: :api_custom_v1_account_conversation_gate_snapshot
end
