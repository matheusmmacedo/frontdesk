# frozen_string_literal: true

# Rotas custom pros motivos de pausa (O.19).
# Usa Rails.application.routes.append pra não tocar config/routes.rb upstream.

Rails.application.routes.append do
  scope '/api/custom/v1/accounts/:account_id' do
    resources :pause_reasons,
              controller: 'api/custom/v1/accounts/pause_reasons',
              only: %i[index create update destroy] do
      collection { post :reorder }
    end

    post '/klaos/agent_pause',
         to: 'api/custom/v1/accounts/agent_pause#create',
         as: :api_custom_v1_klaos_agent_pause
  end
end
