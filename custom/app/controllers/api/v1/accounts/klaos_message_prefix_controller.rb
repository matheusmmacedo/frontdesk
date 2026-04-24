# frozen_string_literal: true

# KLaOS Message Prefix — settings endpoint
#
# Expõe GET/PUT para `accounts.custom_attributes.klaos_human_message_template`.
# Usado pela página de settings da UI custom. Isolado do AccountsController
# upstream pra evitar patch na whitelist de custom_attributes_params.

class Api::V1::Accounts::KlaosMessagePrefixController < Api::V1::Accounts::BaseController
  before_action :authorize_admin!

  TEMPLATE_KEY = 'klaos_human_message_template'

  def show
    render json: { template: current_template, available_variables: available_variables, examples: examples }
  end

  def update
    template = params[:template].to_s.strip
    if template.length > 200
      render json: { error: 'Template muito longo (máximo 200 caracteres).' }, status: :unprocessable_entity
      return
    end

    attrs = Current.account.custom_attributes || {}
    if template.blank?
      attrs = attrs.except(TEMPLATE_KEY)
    else
      attrs = attrs.merge(TEMPLATE_KEY => template)
    end
    Current.account.update!(custom_attributes: attrs)
    render json: { template: current_template, available_variables: available_variables, examples: examples }
  end

  private

  def authorize_admin!
    return if Current.user&.administrator?(Current.account)

    render json: { error: 'Apenas administradores podem alterar esta configuração.' }, status: :forbidden
  end

  def current_template
    Current.account.custom_attributes&.dig(TEMPLATE_KEY).to_s
  end

  def available_variables
    KlaosHumanMessagePrefix::AVAILABLE_VARIABLES.map { |var, desc| { variable: var, description: desc } }
  end

  def examples
    KlaosHumanMessagePrefix::EXAMPLES
  end
end
