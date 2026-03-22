# frozen_string_literal: true

class Api::V1::Accounts::WhatsappConnections::PhoneNumbersController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_connection
  before_action :fetch_phone_number, only: [:link, :unlink]

  def index
    @phone_numbers = @connection.whatsapp_phone_numbers
    render json: @phone_numbers.map { |pn| phone_number_response(pn) }
  end

  def link
    linker = if @connection.meta_cloud?
               WhatsappConnections::Meta::PhoneLinkerService.new(@phone_number)
             else
               WhatsappConnections::Evolution::PhoneLinkerService.new(@phone_number)
             end

    result = if @connection.meta_cloud?
               linker.perform
             else
               linker.link
             end
    render json: {
      phone_number: phone_number_response(@phone_number.reload),
      inbox: { id: result[:inbox].id, name: result[:inbox].name }
    }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def unlink
    if @connection.meta_cloud?
      WhatsappConnections::Meta::PhoneUnlinkerService.new(@phone_number).perform
    else
      WhatsappConnections::Evolution::PhoneLinkerService.new(@phone_number).unlink
    end

    render json: phone_number_response(@phone_number.reload)
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_connection
    @connection = Current.account.whatsapp_connections.find(params[:whatsapp_connection_id])
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
      inbox_name: pn.inbox&.name,
      created_at: pn.created_at,
      updated_at: pn.updated_at
    }
  end
end
