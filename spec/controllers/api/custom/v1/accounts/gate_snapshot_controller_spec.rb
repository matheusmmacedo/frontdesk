# frozen_string_literal: true

require 'rails_helper'

# (16/09/2026) O gate_snapshot passa a devolver o `source_id` da conversa: o
# numero para onde o WhatsApp dela entrega. O KLaOS confere esse numero com o
# telefone do devedor antes de cobrar. A conv 264 da Blue Care foi aberta a mao
# com um numero errado e recebeu a cobranca de outra pessoa.
RSpec.describe 'GET gate_snapshot', type: :request do
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, :administrator, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:contact) { create(:contact, account: account, phone_number: '+5531983733310') }

  def pedir(conversa)
    get "/api/custom/v1/accounts/#{account.id}/conversations/#{conversa.display_id}/gate_snapshot",
        headers: { api_access_token: admin.access_token.token },
        as: :json
  end

  it 'devolve o source_id do contact_inbox, mesmo quando difere do telefone do contato' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5531920075276')
    conversa = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)

    pedir(conversa)

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['source_id']).to eq('5531920075276')
  end

  it 'vizinho: os campos que o gate ja usava continuam iguais' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5531983733310')
    conversa = create(:conversation, account: account, inbox: inbox, contact: contact,
                                     contact_inbox: contact_inbox, assignee: admin, status: :open)

    pedir(conversa)

    corpo = response.parsed_body
    expect(corpo['conversation_id']).to eq(conversa.display_id)
    expect(corpo['status']).to eq('open')
    expect(corpo['assignee_id']).to eq(admin.id)
    expect(corpo).to include('team_id', 'agent_bot_id', 'assignee_message_count', 'assignee_last_message_at')
  end
end
