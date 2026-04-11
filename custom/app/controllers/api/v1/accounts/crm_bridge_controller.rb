# frozen_string_literal: true

# CRM Bridge Controller
# Allows KLaOS to push deal data into Chatwoot conversations.
# Deal info is stored as custom_attributes and displayed in the conversation sidebar natively.
#
# Endpoints:
#   PUT /api/v1/accounts/:account_id/crm_bridge/conversations/:conversation_id/deal
#   DELETE /api/v1/accounts/:account_id/crm_bridge/conversations/:conversation_id/deal
#   POST /api/v1/accounts/:account_id/crm_bridge/contacts/:contact_id/deal
module Api::V1::Accounts
  class CrmBridgeController < Api::V1::Accounts::BaseController
    before_action :set_conversation, only: %i[update_deal remove_deal]
    before_action :set_contact, only: [:create_deal_for_contact]

    # PUT /api/v1/accounts/:account_id/crm_bridge/conversations/:conversation_id/deal
    # KLaOS pushes deal data to a specific conversation
    def update_deal
      deal_attrs = deal_params
      crm_data = {
        'crm_deal_id' => deal_attrs[:deal_id],
        'crm_deal_name' => deal_attrs[:deal_name],
        'crm_deal_value' => deal_attrs[:deal_value],
        'crm_deal_stage' => deal_attrs[:deal_stage],
        'crm_deal_owner' => deal_attrs[:deal_owner],
        'crm_lead_score' => deal_attrs[:lead_score],
        'crm_pipeline' => deal_attrs[:pipeline_name],
        'crm_deal_url' => deal_attrs[:deal_url]
      }.compact

      @conversation.update!(
        custom_attributes: (@conversation.custom_attributes || {}).merge(crm_data)
      )

      render json: { success: true, custom_attributes: @conversation.custom_attributes }
    end

    # DELETE /api/v1/accounts/:account_id/crm_bridge/conversations/:conversation_id/deal
    # Remove deal data from conversation
    def remove_deal
      crm_keys = @conversation.custom_attributes.keys.select { |k| k.start_with?('crm_') }
      cleaned = @conversation.custom_attributes.except(*crm_keys)
      @conversation.update!(custom_attributes: cleaned)

      render json: { success: true }
    end

    # POST /api/v1/accounts/:account_id/crm_bridge/contacts/:contact_id/deal
    # Create a deal in KLaOS from a Frontdesk contact (stores deal ref in contact custom_attributes)
    def create_deal_for_contact
      deal_attrs = deal_params
      crm_data = {
        'crm_deal_id' => deal_attrs[:deal_id],
        'crm_deal_name' => deal_attrs[:deal_name],
        'crm_deal_value' => deal_attrs[:deal_value],
        'crm_deal_stage' => deal_attrs[:deal_stage]
      }.compact

      @contact.update!(
        custom_attributes: (@contact.custom_attributes || {}).merge(crm_data)
      )

      render json: { success: true, custom_attributes: @contact.custom_attributes }
    end

    private

    def set_conversation
      @conversation = Current.account.conversations.find_by!(display_id: params[:conversation_id])
    end

    def set_contact
      @contact = Current.account.contacts.find(params[:contact_id])
    end

    def deal_params
      params.permit(:deal_id, :deal_name, :deal_value, :deal_stage, :deal_owner,
                    :lead_score, :pipeline_name, :deal_url)
    end
  end
end
