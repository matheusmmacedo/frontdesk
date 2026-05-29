# frozen_string_literal: true

# Rotas custom pro Painel de Agentes (O.1).
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream.

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/supervisor/agents',
      to: 'api/custom/v1/accounts/supervisor_agents#index',
      as: :api_custom_v1_supervisor_agents

  post '/api/custom/v1/accounts/:account_id/supervisor/agents/:user_id/force_status',
       to: 'api/custom/v1/accounts/supervisor_agents#force_status',
       as: :api_custom_v1_supervisor_force_status
end
