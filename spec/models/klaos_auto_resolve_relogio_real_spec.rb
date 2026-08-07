# frozen_string_literal: true

require 'rails_helper'

# Incidente 07/08/2026 — a cobranca saia e o auto-resolve fechava a conversa 3
# minutos depois, carimbando "1 days of inactivity". Causa: `last_activity_at`
# so registra a ultima fala do CLIENTE (klaos_sort_ignore_activities.rb), entao
# a conversa recem-cobrada nascia ja vencida para o job.
#
# Sem o fix, o primeiro exemplo falha: a conversa cobrada agora e resolvida.
RSpec.describe 'KLaOS auto-resolve conta o relogio pela ultima mensagem real' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  before { account.update!(auto_resolve_after: 1440) }

  # O `last_activity_at` velho e o coracao do caso: e ele que engana o job.
  def conversa_parada_ha_muito
    conversa = create(:conversation, account: account, inbox: inbox,
                                     contact: contact, contact_inbox: contact_inbox,
                                     status: :open, assignee: nil)
    conversa.update_columns(last_activity_at: 60.days.ago)
    conversa
  end

  it 'nao encerra conversa que acabou de receber cobranca' do
    conversa = conversa_parada_ha_muito
    create(:message, account: account, inbox: inbox, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    described_job = Conversations::ResolutionJob.new
    described_job.perform(account: account)

    expect(conversa.reload.status).to eq('open')
  end

  it 'encerra conversa realmente parada — nenhuma mensagem na janela' do
    conversa = conversa_parada_ha_muito
    mensagem = create(:message, account: account, inbox: inbox, conversation: conversa,
                                message_type: :outgoing, private: false, content: 'cobranca antiga')
    mensagem.update_columns(created_at: 60.days.ago)
    conversa.update_columns(last_activity_at: 60.days.ago)

    Conversations::ResolutionJob.new.perform(account: account)

    expect(conversa.reload.status).to eq('resolved')
  end

  it 'nota interna nao segura a conversa — nota nao e conversa com o cliente' do
    conversa = conversa_parada_ha_muito
    create(:message, account: account, inbox: inbox, conversation: conversa,
                     message_type: :outgoing, private: true, content: 'anotacao do atendente')

    Conversations::ResolutionJob.new.perform(account: account)

    expect(conversa.reload.status).to eq('resolved')
  end

  it 'mensagem do cliente tambem segura' do
    conversa = conversa_parada_ha_muito
    create(:message, account: account, inbox: inbox, conversation: conversa,
                     message_type: :incoming, private: false, content: 'oi')

    Conversations::ResolutionJob.new.perform(account: account)

    expect(conversa.reload.status).to eq('open')
  end

  it 'respeita o desligamento por conta' do
    account.update!(settings: account.settings.merge('klaos_auto_resolve_relogio_real' => false))
    conversa = conversa_parada_ha_muito
    create(:message, account: account, inbox: inbox, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    Conversations::ResolutionJob.new.perform(account: account)

    expect(conversa.reload.status).to eq('resolved')
  end
end
