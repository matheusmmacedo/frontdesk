# frozen_string_literal: true

# Rotas pro endpoint custom de "snooze returns".
# Spec completo no controller:
#   custom/app/controllers/api/custom/v1/accounts/snooze_returns_controller.rb

Rails.application.routes.append do
  get '/api/custom/v1/accounts/:account_id/snooze_returns',
      to: 'api/custom/v1/accounts/snooze_returns#index',
      as: :api_custom_v1_account_snooze_returns

  post '/api/custom/v1/accounts/:account_id/snooze_returns/dismiss',
       to: 'api/custom/v1/accounts/snooze_returns#dismiss',
       as: :api_custom_v1_account_snooze_returns_dismiss
end
