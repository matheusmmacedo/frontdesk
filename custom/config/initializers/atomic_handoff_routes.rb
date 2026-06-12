# frozen_string_literal: true

# Rota custom pro endpoint atômico de handoff (KLaOS).
# Substitui o fluxo "unassign + change_team" do KLaOS por uma chamada
# atômica que evita a janela de assignee_id=null e o flash-assign do
# auto-assignment upstream.
#
# Endpoint: POST /api/custom/v1/accounts/:account_id/conversations/:conversation_id/handoff_atomic
# Auth:     header `api_access_token` (mesma da API V1)
#
# Spec completo no controller: custom/app/controllers/api/custom/v1/accounts/atomic_handoff_controller.rb

Rails.application.routes.append do
  post '/api/custom/v1/accounts/:account_id/conversations/:conversation_id/handoff_atomic',
       to: 'api/custom/v1/accounts/atomic_handoff#create',
       as: :api_custom_v1_account_conversation_handoff_atomic
end
