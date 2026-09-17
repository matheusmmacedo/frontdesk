# frozen_string_literal: true

# Este arquivo e carregado por config/application.rb, antes do boot completo.
require 'active_support/core_ext/module/attribute_accessors_per_thread'

# DE ONDE VEIO A REQUISICAO: PAINEL OU TOKEN DE INTEGRACAO
#
# O model nao sabe se o `Current.user` e uma pessoa no painel ou o KLaOS
# usando o token do usuario I.A: os dois chegam como `User`. Algumas regras
# nossas precisam dessa diferenca:
#
#   - klaos_reabre_em_acao_nossa.rb: so mensagem de PESSOA cancela adiamento;
#   - klaos_reabrir_em_data_marcada.rb: so PESSOA agenda "encerrar e reabrir
#     comigo em DD/MM".
#
# `KlaosOrigemDaRequisicao.via_token` fica true durante uma requisicao da API
# autenticada por `api_access_token` (o mesmo teste do upstream em
# Api::BaseController#authenticate_by_access_token?) e volta a nil no fim,
# inclusive com erro. Fora de requisicao (jobs, console) vale nil.

module KlaosOrigemDaRequisicao
  thread_mattr_accessor :via_token

  module Marcador
    extend ActiveSupport::Concern

    included do
      around_action :klaos_marcar_origem_da_requisicao
    end

    private

    def klaos_marcar_origem_da_requisicao
      KlaosOrigemDaRequisicao.via_token =
        request.headers[:api_access_token].present? || request.headers[:HTTP_API_ACCESS_TOKEN].present?
      yield
    ensure
      KlaosOrigemDaRequisicao.via_token = nil
    end
  end
end

Rails.application.config.to_prepare do
  controller = 'Api::BaseController'.safe_constantize
  next unless controller
  next if controller.include?(KlaosOrigemDaRequisicao::Marcador)

  controller.include(KlaosOrigemDaRequisicao::Marcador)
  Rails.logger.info '[KlaosOrigemDaRequisicao] included on Api::BaseController'
end
