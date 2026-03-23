# frozen_string_literal: true

class Api::V1::Accounts::WhatsappConnections::EvolutionController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection
  before_action :ensure_evolution!
  before_action :fetch_phone_number, only: [:qrcode, :status, :destroy, :disconnect]

  # POST - Create a new Evolution instance
  def create
    service = WhatsappConnections::Evolution::InstanceManagerService.new(@connection)
    result = service.create_instance(params[:display_name] || 'WhatsApp')
    render json: {
      instance: result[:instance],
      phone_number: phone_number_response(result[:phone_number])
    }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE - Delete an Evolution instance
  def destroy
    service = WhatsappConnections::Evolution::InstanceManagerService.new(@connection)
    service.delete_instance(@phone_number)
    head :no_content
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET - Get QR code to connect an instance
  def qrcode
    service = WhatsappConnections::Evolution::InstanceManagerService.new(@connection)
    result = service.connect_instance(@phone_number)
    render json: {
      qrcode: result.dig('base64') || result.dig('qrcode', 'base64'),
      pairingCode: result.dig('pairingCode'),
      phone_number: phone_number_response(@phone_number.reload)
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # GET - Check instance connection status
  def status
    service = WhatsappConnections::Evolution::InstanceManagerService.new(@connection)
    result = service.check_status(@phone_number)
    render json: phone_number_response(result[:phone_number])
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # POST - Disconnect instance
  def disconnect
    service = WhatsappConnections::Evolution::InstanceManagerService.new(@connection)
    service.disconnect_instance(@phone_number)
    render json: phone_number_response(@phone_number.reload)
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_connection
    @connection = Current.account.whatsapp_connections.find(params[:whatsapp_connection_id])
  end

  def ensure_evolution!
    return if @connection.evolution?

    render json: { error: 'This endpoint is only for Evolution connections' }, status: :unprocessable_entity
  end

  def fetch_phone_number
    @phone_number = @connection.whatsapp_phone_numbers.find(params[:id])
  end

  def phone_number_response(pn)
    {
      id: pn.id,
      phone_number: pn.phone_number,
      phone_number_id: pn.phone_number_id,
      display_name: pn.display_name,
      status: pn.status,
      provider_info: pn.provider_info,
      inbox_id: pn.inbox_id,
      inbox_name: pn.inbox&.name
    }
  end
end
