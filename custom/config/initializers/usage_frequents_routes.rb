# frozen_string_literal: true

# Rotas do KLaOS Global Usage Frequents.
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream.

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/usage_frequents',
      to: 'api/custom/v1/accounts/usage_frequents#index',
      as: :api_custom_v1_account_usage_frequents

  post '/api/custom/v1/accounts/:account_id/usage_frequents/track',
       to: 'api/custom/v1/accounts/usage_frequents#track',
       as: :api_custom_v1_account_usage_frequents_track
end
