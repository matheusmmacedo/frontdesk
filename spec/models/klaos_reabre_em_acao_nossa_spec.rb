# frozen_string_literal: true

require 'rails_helper'

# Regra 07/08/2026: acao nossa numa conversa resolvida tem que reabrir, com o
# bot como responsavel. O upstream so reabre por mensagem do cliente
# (`return unless incoming?`), entao a cobranca saia e a conversa continuava
# `resolved` — invisivel para quem acompanha a fila.
RSpec.describe 'KLaOS acao nossa reabre conversa resolvida' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }

  # Inbox COM bot: e o caso da cobranca. O upstream escolhe `pending` aqui, que
  # e o estado "o bot esta cuidando" — e o unico que nao dispara o rodizio.
  let(:inbox_com_bot) do
    inbox = create(:inbox, account: account)
    create(:agent_bot_inbox, inbox: inbox, account: account)
    inbox
  end

  def conversa_resolvida(inbox)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, status: :resolved, assignee: nil)
  end

  it 'cobranca em conversa resolvida reabre como pending, sem sortear atendente' do
    conversa = conversa_resolvida(inbox_com_bot)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    conversa.reload
    expect(conversa.status).to eq('pending')
    # o ponto do `pending`: rodizio nao pega, a conversa nao cai em cima de
    # ninguem sorteado.
    expect(conversa.assignee_id).to be_nil
  end

  it 'nota interna nao reabre — anotar nao e falar com o cliente' do
    conversa = conversa_resolvida(inbox_com_bot)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :outgoing, private: true, content: 'anotacao')

    expect(conversa.reload.status).to eq('resolved')
  end

  it 'atividade (etiqueta, atribuicao) nao reabre' do
    conversa = conversa_resolvida(inbox_com_bot)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :activity, private: false, content: 'adicionou cobranca-0d')

    expect(conversa.reload.status).to eq('resolved')
  end

  it 'conversa adiada volta e perde a hora do adiamento' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox_com_bot)
    conversa = create(:conversation, account: account, inbox: inbox_com_bot, contact: contact,
                                     contact_inbox: contact_inbox, status: :snoozed,
                                     snoozed_until: 3.days.from_now, assignee: nil)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    conversa.reload
    expect(conversa.status).to eq('pending')
    expect(conversa.snoozed_until).to be_nil
  end

  it 'conversa ja aberta continua aberta' do
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox_com_bot)
    conversa = create(:conversation, account: account, inbox: inbox_com_bot, contact: contact,
                                     contact_inbox: contact_inbox, status: :open, assignee: nil)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    expect(conversa.reload.status).to eq('open')
  end

  it 'respeita o desligamento por conta' do
    account.update!(settings: account.settings.merge('klaos_reabre_em_acao_nossa' => false))
    conversa = conversa_resolvida(inbox_com_bot)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa,
                     message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

    expect(conversa.reload.status).to eq('resolved')
  end
end
