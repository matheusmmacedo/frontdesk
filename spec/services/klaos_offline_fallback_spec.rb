# frozen_string_literal: true

require 'rails_helper'

# Trava as duas metades do fallback de atribuição.
#
# Ele existe pra resolver "ninguém pegou pra mim mesmo eu estando no time":
# o Chatwoot só atribui a quem tem presença no Redis nos últimos 20s, então
# quem está trabalhando sem a aba em foco era pulado.
#
# O que ele NUNCA pode fazer é entregar conversa pra quem se marcou
# indisponível. Em 10/08 fez exatamente isso: a Yasmin recebeu 7 conversas
# de férias, já marcada como offline.
#
# Os dois testes andam juntos de propósito. Consertar um sem o outro leva de
# volta a um dos dois bugs.
RSpec.describe AutoAssignment::AgentAssignmentService do
  let(:account) do
    create(:account).tap do |a|
      a.update!(custom_attributes: { 'klaos_auto_assignment_offline_fallback' => true })
    end
  end
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, team: team) }

  # Ninguém tem presença no Redis nestes testes — é justamente a condição que
  # faz o fallback entrar. O upstream devolve nil e nós assumimos a escolha.
  def escolher
    described_class.new(
      conversation: conversation,
      allowed_agent_ids: [disponivel.id, indisponivel.id]
    ).find_assignee
  end

  let(:disponivel) { create(:user, account: account, role: :agent) }
  let(:indisponivel) { create(:user, account: account, role: :agent) }

  before do
    [disponivel, indisponivel].each do |u|
      create(:inbox_member, user: u, inbox: inbox)
      create(:team_member, user: u, team: team)
    end
    AccountUser.find_by(account: account, user: disponivel).update!(availability: :online)
  end

  it 'distribui pra quem está disponível quando o Redis está vazio' do
    AccountUser.find_by(account: account, user: indisponivel).update!(availability: :offline)

    expect(escolher).to eq(disponivel)
  end

  it 'não entrega conversa pra quem se marcou offline (caso Yasmin, 10/08)' do
    AccountUser.find_by(account: account, user: indisponivel).update!(availability: :offline)

    # Roda várias vezes porque a escolha é por menor carga: com um pool de dois
    # e ambos zerados, um sorteio ingênuo acertaria metade das vezes por acaso.
    10.times { expect(escolher).not_to eq(indisponivel) }
  end

  it 'trata "ocupado" como indisponível, não como disponível' do
    AccountUser.find_by(account: account, user: indisponivel).update!(availability: :busy)

    10.times { expect(escolher).not_to eq(indisponivel) }
  end

  it 'deixa a conversa sem dono quando o time inteiro está indisponível' do
    AccountUser.find_by(account: account, user: disponivel).update!(availability: :offline)
    AccountUser.find_by(account: account, user: indisponivel).update!(availability: :offline)

    # Sem dono é o resultado certo às 3 da manhã. O errado seria acordar alguém.
    expect(escolher).to be_nil
  end

  it 'continua desligado nas contas que não pediram o fallback' do
    account.update!(custom_attributes: {})
    AccountUser.find_by(account: account, user: indisponivel).update!(availability: :offline)

    expect(escolher).to be_nil
  end
end
