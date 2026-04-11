# frozen_string_literal: true

# Unified template controller for both Meta Cloud (WABA) and Evolution (local) templates.
# Meta: validated + synced with Meta Graph API (strict rules)
# Evolution: stored locally, free-form (no external API, no approval process)
class Api::V1::Accounts::WhatsappConnections::TemplatesController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection

  def index
    render json: {
      templates: @connection.message_templates || [],
      synced_at: @connection.message_templates_last_updated,
      provider: @connection.provider
    }
  end

  def create
    if @connection.meta_cloud?
      create_meta_template
    else
      create_evolution_template
    end
  end

  def update
    if @connection.meta_cloud?
      update_meta_template
    else
      update_evolution_template
    end
  end

  def destroy
    if @connection.meta_cloud?
      destroy_meta_template
    else
      destroy_evolution_template
    end
  end

  # POST /templates/upload_media — Upload media for template header (Meta only)
  def upload_media
    return render json: { error: 'Media upload only available for Meta Cloud' }, status: :unprocessable_entity unless @connection.meta_cloud?

    file = params[:file]
    media_type = params[:media_type]
    render json: { error: 'File is required' }, status: :unprocessable_entity and return unless file
    render json: { error: 'media_type is required' }, status: :unprocessable_entity and return unless media_type

    service = WhatsappConnections::Meta::MediaUploadService.new(@connection)
    result = service.upload(file, media_type)
    render json: result
  rescue WhatsappConnections::Meta::MediaUploadService::UploadError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_connection
    @connection = Current.account.whatsapp_connections.find(params[:whatsapp_connection_id])
  end

  # ========== META CLOUD (WABA) ==========

  def create_meta_template
    validated = validate_meta_params!(is_update: false)
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.create_template(validated)
    render json: result, status: :created
  rescue WhatsappConnections::Meta::TemplateValidatorService::ValidationError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_meta_template
    validated = validate_meta_params!(is_update: true)
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.update_template(params[:id], validated)
    render json: result
  rescue WhatsappConnections::Meta::TemplateValidatorService::ValidationError, StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy_meta_template
    service = WhatsappConnections::Meta::TemplateCrudService.new(@connection)
    result = service.delete_template(params[:id])
    render json: result
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def validate_meta_params!(is_update: false)
    raw = if is_update
            params.permit(components: build_components_permit)
          else
            params.permit(:name, :language, :category, :allow_category_change, components: build_components_permit)
          end
    validator = WhatsappConnections::Meta::TemplateValidatorService.new(raw, is_update: is_update)
    validator.validate!
    raw
  end

  def build_components_permit
    [
      :type, :format, :text, :url, :phone_number,
      { buttons: [:type, :text, :url, :phone_number, :example, { example: [] }] },
      { example: [:header_text, :header_url, { header_handle: [], header_text: [], body_text: [[]] }] }
    ]
  end

  # ========== EVOLUTION (LOCAL) ==========

  def create_evolution_template
    tpl = build_evolution_template
    templates = @connection.message_templates || []
    templates.push(tpl)
    @connection.update!(message_templates: templates)
    render json: tpl, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update_evolution_template
    templates = @connection.message_templates || []
    idx = templates.index { |t| t['id'] == params[:id] }
    return render json: { error: 'Template not found' }, status: :not_found unless idx

    updated = templates[idx].merge(evolution_template_params.to_h)
    updated['updated_at'] = Time.now.utc.iso8601
    templates[idx] = updated
    @connection.update!(message_templates: templates)
    render json: updated
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy_evolution_template
    templates = @connection.message_templates || []
    templates.reject! { |t| t['id'] == params[:id] || t['name'] == params[:id] }
    @connection.update!(message_templates: templates)
    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def build_evolution_template
    p = evolution_template_params
    raise 'Name is required' if p[:name].blank?
    raise 'Body is required' if p[:body].blank?

    {
      'id' => SecureRandom.uuid,
      'name' => p[:name],
      'body' => p[:body],
      'header' => p[:header],
      'footer' => p[:footer],
      'media_url' => p[:media_url],
      'media_type' => p[:media_type],
      'buttons' => p[:buttons]&.map(&:to_h) || [],
      'category' => p[:category] || 'general',
      'language' => p[:language] || 'pt_BR',
      'provider' => 'evolution',
      'status' => 'APPROVED',
      'created_at' => Time.now.utc.iso8601,
      'updated_at' => Time.now.utc.iso8601
    }
  end

  def evolution_template_params
    params.permit(:name, :body, :header, :footer, :media_url, :media_type,
                  :category, :language, buttons: %i[type text url phone_number])
  end
end
