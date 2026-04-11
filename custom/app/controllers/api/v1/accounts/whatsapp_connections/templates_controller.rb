# frozen_string_literal: true

class Api::V1::Accounts::WhatsappConnections::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection
  before_action :ensure_meta_cloud!

  def index
    render json: { templates: @connection.message_templates, synced_at: @connection.message_templates_last_updated }
  end

  def create
    validated = validate_and_build_params!(is_update: false)
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.create_template(validated)
    render json: result, status: :created
  rescue WhatsappConnections::Meta::TemplateValidatorService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    validated = validate_and_build_params!(is_update: true)
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.update_template(params[:id], validated)
    render json: result
  rescue WhatsappConnections::Meta::TemplateValidatorService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
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

  def validate_and_build_params!(is_update: false)
    raw = build_template_params(is_update)
    validator = WhatsappConnections::Meta::TemplateValidatorService.new(raw, is_update: is_update)
    validator.validate!
    raw
  end

  def build_template_params(is_update)
    if is_update
      # Only components can be updated per Meta rules
      params.permit(components: build_components_permit)
    else
      params.permit(:name, :language, :category, :allow_category_change, components: build_components_permit)
    end
  end

  # Explicitly whitelist component structure instead of using wildcard {}
  def build_components_permit
    [
      :type, :format, :text, :url, :phone_number,
      { buttons: [:type, :text, :url, :phone_number, :example, { example: [] }] },
      { example: [:header_text, :header_url, { header_handle: [] }, { header_text: [] }, { body_text: [[]] }] }
    ]
  end
end
