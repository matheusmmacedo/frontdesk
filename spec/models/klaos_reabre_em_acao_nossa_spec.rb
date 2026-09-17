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

  def conversa_resolvida(inbox, assignee: nil)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    conv = create(:conversation, account: account, inbox: inbox, contact: contact,
                                 contact_inbox: contact_inbox, status: :resolved, assignee: nil)
    # Na criacao, inbox com bot ativo troca o status por `pending`
    # (determine_conversation_status). O teste precisa partir de `resolved`.
    conv.update_columns(status: Conversation.statuses[:resolved], assignee_id: assignee&.id)
    conv.reload
  end

  def conversa_adiada(inbox, assignee: nil, ate: 3.days.from_now)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    conv = create(:conversation, account: account, inbox: inbox, contact: contact,
                                 contact_inbox: contact_inbox, status: :open, assignee: nil)
    conv.update_columns(status: Conversation.statuses[:snoozed], snoozed_until: ate,
                        assignee_id: assignee&.id)
    conv.reload
  end

  let(:atendente) do
    user = create(:user, account: account, role: :administrator, name: 'Gustavo')
    create(:inbox_member, user: user, inbox: inbox_com_bot)
    user
  end
  let(:usuario_ia) { create(:user, account: account, role: :administrator, name: 'I.A') }

  def template_da_regua(conversa, nome: 'cobr_d0_vencimento_v2')
    create(:message, account: account, inbox: conversa.inbox, conversation: conversa, sender: usuario_ia,
                     message_type: :outgoing, private: false, content: nome,
                     additional_attributes: { 'template_params' => { 'name' => nome, 'language' => 'pt_BR' } })
  end

  def template_cobrar_agora(conversa, nome: 'cobr_cobrar_agora_v2', marca: nil)
    params = { 'name' => nome, 'language' => 'pt_BR' }
    params['klaos_origem'] = marca if marca
    create(:message, account: account, inbox: conversa.inbox, conversation: conversa, sender: usuario_ia,
                     message_type: :outgoing, private: false, content: nome,
                     additional_attributes: { 'template_params' => params })
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

  # (16/09/2026) So PESSOA cancela adiamento: atendente respondendo, sem
  # template.
  it 'resposta do atendente em conversa adiada: volta e perde a hora do adiamento' do
    conversa = conversa_adiada(inbox_com_bot)

    create(:message, account: account, inbox: inbox_com_bot, conversation: conversa, sender: atendente,
                     message_type: :outgoing, private: false, content: 'oi, conseguiu ver o boleto?')

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

  # -------------------------------------------------------------------------
  # (16/09/2026) Gustavo: "reabre aleatoriamente com a propria Lara".
  # O cobrar-agora e pedido de um humano; a regua e do bot.
  # -------------------------------------------------------------------------
  describe 'cobrar-agora' do
    it 'em conversa resolvida com dono: reabre open e mantem o dono' do
      conversa = conversa_resolvida(inbox_com_bot, assignee: atendente)

      template_cobrar_agora(conversa)

      conversa.reload
      expect(conversa.status).to eq('open')
      expect(conversa.assignee_id).to eq(atendente.id)
    end

    it 'reconhece a marca klaos_origem mesmo com outro nome de template' do
      conversa = conversa_resolvida(inbox_com_bot, assignee: atendente)

      template_cobrar_agora(conversa, nome: 'bluecare_cobranca_manual', marca: 'cobrar_agora')

      expect(conversa.reload.status).to eq('open')
    end

    it 'reconhece o clone com prefixo de cliente' do
      conversa = conversa_resolvida(inbox_com_bot, assignee: atendente)

      template_cobrar_agora(conversa, nome: 'bluecare_cobr_cobrar_agora_v2')

      expect(conversa.reload.status).to eq('open')
    end

    it 'sem dono segue o upstream (pending): quem clicar em reabrir fica com ela' do
      conversa = conversa_resolvida(inbox_com_bot)

      template_cobrar_agora(conversa)

      conversa.reload
      expect(conversa.status).to eq('pending')
      expect(conversa.assignee_id).to be_nil
    end

    it 'em conversa adiada com dono: cancela o adiamento e abre com o dono' do
      conversa = conversa_adiada(inbox_com_bot, assignee: atendente)

      template_cobrar_agora(conversa)

      conversa.reload
      expect(conversa.status).to eq('open')
      expect(conversa.snoozed_until).to be_nil
      expect(conversa.assignee_id).to eq(atendente.id)
    end
  end

  describe 'template da regua' do
    it 'em conversa resolvida continua indo para pending (regra de 07/08)' do
      conversa = conversa_resolvida(inbox_com_bot, assignee: atendente)

      template_da_regua(conversa)

      expect(conversa.reload.status).to eq('pending')
    end

    it 'NAO cancela o adiamento' do
      ate = 3.days.from_now
      conversa = conversa_adiada(inbox_com_bot, assignee: atendente, ate: ate)

      template_da_regua(conversa)

      conversa.reload
      expect(conversa.status).to eq('snoozed')
      expect(conversa.snoozed_until).to be_within(1.second).of(ate)
    end
  end

  describe 'quem cancela um adiamento' do
    it 'mensagem do bot (AgentBot) NAO cancela' do
      bot = create(:agent_bot, account: account)
      conversa = conversa_adiada(inbox_com_bot)

      create(:message, account: account, inbox: inbox_com_bot, conversation: conversa, sender: bot,
                       message_type: :outgoing, private: false, content: 'Oi, sou a Lara')

      expect(conversa.reload.status).to eq('snoozed')
    end

    it 'mensagem que entrou por api_access_token NAO cancela' do
      conversa = conversa_adiada(inbox_com_bot)
      KlaosOrigemDaRequisicao.via_token = true

      create(:message, account: account, inbox: inbox_com_bot, conversation: conversa, sender: usuario_ia,
                       message_type: :outgoing, private: false, content: 'texto da integracao')

      expect(conversa.reload.status).to eq('snoozed')
    ensure
      KlaosOrigemDaRequisicao.via_token = nil
    end

    it 'nota interna nao mexe em nada' do
      conversa = conversa_adiada(inbox_com_bot, assignee: atendente)

      create(:message, account: account, inbox: inbox_com_bot, conversation: conversa, sender: atendente,
                       message_type: :outgoing, private: true, content: 'anotacao')

      expect(conversa.reload.status).to eq('snoozed')
    end

    it 'mensagem do cliente continua reabrindo (upstream)' do
      conversa = conversa_adiada(inbox_com_bot)

      create(:message, account: account, inbox: inbox_com_bot, conversation: conversa, sender: contact,
                       message_type: :incoming, private: false, content: 'oi')

      expect(conversa.reload.status).not_to eq('snoozed')
    end
  end
end
