require 'rails_helper'

RSpec.describe 'Conversation Label API', type: :request do
  let(:account) { create(:account) }

  describe 'GET /api/v1/accounts/{account.id}/conversations/<id>/labels' do
    let(:conversation) { create(:conversation, account: account) }

    before do
      conversation.update_labels('label1, label2')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the conversation' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'returns all the labels for the conversation' do
        get api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('label1')
        expect(response.body).to include('label2')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/labels' do
    let(:conversation) { create(:conversation, account: account) }

    before do
      conversation.update_labels('label1, label2')
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: %w[label3 label4] },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user with access to the conversation' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation.update_labels('label1, label2')
        create(:inbox_member, inbox: conversation.inbox, user: agent)
      end

      it 'creates labels for the conversation' do
        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: %w[label3 label4] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include('label3')
        expect(response.body).to include('label4')
      end

      # Regressao bug #699 (P1 BLOQUEIO regua cobranca):
      # POST /labels deve disparar CONVERSATION_UPDATED via Rails dispatcher
      # pra que WebhookListener (KLaOS HTTP) E AutomationRuleListener recebam
      # o evento com label_list em changed_attributes. Antes do fix
      # (custom/config/initializers/klaos_label_change_dispatch.rb), o virtual
      # attr label_list nao entrava em previous_changes de forma confiavel
      # e o guard em notify_conversation_updation saia cedo — webhook silencioso.
      it 'dispatches CONVERSATION_UPDATED with label_list in changed_attributes (fix #699)' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post api_v1_account_conversation_labels_url(account_id: account.id, conversation_id: conversation.display_id),
             params: { labels: %w[label3 label4] },
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(
            Conversation::CONVERSATION_UPDATED,
            kind_of(Time),
            hash_including(changed_attributes: hash_including('label_list'))
          ).once
      end
    end
  end
end
