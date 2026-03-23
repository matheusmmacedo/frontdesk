# frozen_string_literal: true

class Api::V1::Accounts::WhatsappConnections::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection
  before_action :ensure_meta_cloud!

  def index
    render json: { templates: @connection.message_templates, synced_at: @connection.message_templates_last_updated }
  end

  def create
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.create_template(template_params)
    render json: result, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.update_template(params[:id], template_update_params)
    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.delete_template(params[:id])
    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_connection
    @connection = Current.account.whatsapp_connections.find(params[:whatsapp_connection_id])
  end

  def ensure_meta_cloud!
    return if @connection.meta_cloud?

    render json: { error: 'Templates are only available for Meta Cloud connections' }, status: :unprocessable_entity
  end

  def template_params
    params.permit(:name, :language, :category, :allow_category_change, components: {})
  end

  def template_update_params
    params.permit(components: {})
  end
end
