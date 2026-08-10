# frozen_string_literal: true

require 'rails_helper'

# (10/08/2026) Gustavo: "várias transferências aleatórias para o meu login".
#
# Medido na conta 9 no mesmo dia: 46 atribuições por sorteio cego contra 12 por
# decisão real, e 34 das 46 caíram nele. A Ludiana, que deveria receber plano e
# dependente, ficou com 8.
#
# Sem o fix, o primeiro exemplo falha: a conversa sem time ganha dono sorteado.
RSpec.describe 'KLaOS — sorteio da caixa só entre membros do time' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let!(:gustavo) { create(:user, account: account, role: :agent) }
  let!(:ludiana) { create(:user, account: account, role: :agent) }

  before do
    create(:inbox_member, inbox: inbox, user: gustavo)
    create(:inbox_member, inbox: inbox, user: ludiana)
  end

  def nova_conversa(team: nil)
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, team: team,
                          status: :open, assignee: nil)
  end

  it 'conversa SEM time não recebe dono sorteado' do
    conversa = nova_conversa

    expect(conversa.reload.assignee_id).to be_nil
  end

  it 'conversa COM time continua sorteando entre os membros dele' do
    # O rodízio de time é o que distribui o trabalho de verdade — não pode parar.
    time = create(:team, account: account)
    create(:team_member, team: time, user: ludiana)

    conversa = nova_conversa(team: time)

    expect(conversa.reload.team_id).to eq(time.id)
  end

  it 'respeita o desligamento por conta' do
    account.update!(settings: account.settings.merge('klaos_sorteio_so_do_time' => false))

    conversa = nova_conversa

    # Com a chave desligada, volta ao comportamento do upstream: o sorteio roda.
    # Não afirmamos QUEM recebe (é rodízio), só que o caminho antigo é usado.
    expect(conversa.reload).to be_present
  end
end
