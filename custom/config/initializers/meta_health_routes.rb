# frozen_string_literal: true

# Rota do KLaOS Meta Health (Fase 2 do fix de áudio).
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream.

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/meta_health',
      to: 'api/custom/v1/accounts/meta_health#index',
      as: :api_custom_v1_account_meta_health
end
