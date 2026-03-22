# frozen_string_literal: true

class Api::V1::Accounts::WhatsappConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection, only: [:show, :update, :destroy, :sync_numbers, :sync_templates]

  def index
    @connections = Current.account.whatsapp_connections.includes(:whatsapp_phone_numbers)
    render json: connections_response(@connections)
  end

  def show
    render json: connection_response(@connection)
  end

  def create
    case params[:provider]
    when 'meta_cloud'
      @connection = WhatsappConnections::Meta::ConnectionService.new(
        account: Current.account,
        code: params[:code],
        waba_id: params[:waba_id],
        business_id: params[:business_id]
      ).perform
    when 'evolution'
      @connection = WhatsappConnections::Evolution::ConnectionService.new(
        account: Current.account,
        name: params[:name]
      ).perform
    else
      render json: { error: 'Invalid provider. Must be meta_cloud or evolution.' }, status: :unprocessable_entity
      return
    end

    render json: connection_response(@connection), status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    @connection.update!(permitted_params)
    render json: connection_response(@connection)
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @connection.destroy!
    head :no_content
  end

  def sync_numbers
    if @connection.meta_cloud?
      WhatsappConnections::Meta::PhoneSyncService.new(@connection).perform
    else
      WhatsappConnections::Evolution::InstanceSyncService.new(@connection).perform
    end

    render json: connection_response(@connection.reload)
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_templates
    unless @connection.meta_cloud?
      render json: { error: 'Template sync is only available for Meta Cloud connections' }, status: :unprocessable_entity
      return
    end

    templates = WhatsappConnections::Meta::TemplateSyncService.new(@connection).perform
    render json: { templates: templates, synced_at: @connection.message_templates_last_updated }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_connection
    @connection = Current.account.whatsapp_connections.find(params[:id])
  end

  def permitted_params
    params.permit(:name, :status)
  end

  def connections_response(connections)
    connections.map { |c| connection_response(c) }
  end

  def connection_response(connection)
    {
      id: connection.id,
      account_id: connection.account_id,
      provider: connection.provider,
      name: connection.name,
      status: connection.status,
      message_templates_last_updated: connection.message_templates_last_updated,
      phone_numbers_count: connection.whatsapp_phone_numbers.count,
      linked_count: connection.whatsapp_phone_numbers.where(status: 'linked').count,
      available_count: connection.whatsapp_phone_numbers.where(status: 'available').count,
      created_at: connection.created_at,
      updated_at: connection.updated_at
    }
  end
end
