# frozen_string_literal: true

require 'rails_helper'

# Cobre o incremento ADITIVO em custom/config/initializers/track_resolved_timestamp.rb
# (PASSO 1 / N1 do sticky reopen).
#
# CAUSA: as 3 chaves antigas (klaos_resolved_at / klaos_last_assignee_id /
# klaos_last_team_id) sao gravadas no resolve, mas o ramo 'pending' APAGA
# klaos_resolved_at — e o upstream (app/models/message.rb:397,
# reopen_resolved_conversation) joga a conversa pra 'pending' no instante exato em
# que o cliente volta a escrever. Ou seja: a evidencia de "quem era o dono" morria
# justamente no unico momento em que ela seria consultada.
#
# EFEITO: passa a existir additional_attributes['klaos_last_resolution'], bloco
# unico {resolved_at, assignee_id, team_id, inbox_id} que NUNCA e removido.
#
# CONTRATOS VERIFICADOS:
#   1. resolve grava klaos_last_resolution completo e coerente com a conversa
#   2. resolved_at do bloco == klaos_resolved_at (um relogio so, nao dois)
#   3. pending apaga klaos_resolved_at (comportamento antigo INTACTO) e PRESERVA
#      klaos_last_resolution — este e o contrato que da nome ao arquivo
#   4. as 3 chaves antigas continuam sendo gravadas (regressao da timeline do
#      contato: contact_timeline_controller.rb:100-103)
#   5. um novo resolve sobrescreve o snapshot com o dono da vez
#   6. conversa sem assignee/time grava o bloco com nulos, sem estourar
RSpec.describe 'KlaosLastResolutionSnapshot (track_resolved_timestamp — N1)' do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:team) { create(:team, account: account, allow_auto_assign: false) }
  let!(:conversation) { create(:conversation, account: account) }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
    create(:team_member, team: team, user: agent)
    # assignee + team no mesmo save: ensure_assignee_is_from_team so anula o
    # assignee se ele nao for membro do time — ele e, entao a dupla persiste.
    conversation.update!(assignee: agent, team: team)
  end

  def snapshot
    conversation.reload.additional_attributes['klaos_last_resolution']
  end

  describe 'ao resolver' do
    before { conversation.update!(status: :resolved) }

    it 'grava klaos_last_resolution com dono, time e caixa da conversa' do
      expect(snapshot).to be_a(Hash)
      expect(snapshot['assignee_id']).to eq(agent.id)
      expect(snapshot['team_id']).to eq(team.id)
      expect(snapshot['inbox_id']).to eq(conversation.inbox_id)
      expect(snapshot['resolved_at']).to be_present
    end

    it 'usa o MESMO instante de klaos_resolved_at (um relogio so)' do
      extras = conversation.reload.additional_attributes

      expect(extras['klaos_last_resolution']['resolved_at']).to eq(extras['klaos_resolved_at'])
    end

    it 'mantem as 3 chaves antigas intactas (timeline do contato depende delas)' do
      extras = conversation.reload.additional_attributes

      expect(extras['klaos_resolved_at']).to be_present
      expect(extras['klaos_last_assignee_id']).to eq(agent.id)
      expect(extras['klaos_last_team_id']).to eq(team.id)
    end
  end

  describe 'quando o cliente volta a escrever (conversa vai pra pending)' do
    before do
      conversation.update!(status: :resolved)
      conversation.update!(status: :pending)
    end

    it 'PRESERVA klaos_last_resolution com o dono anterior' do
      # Este e o defeito que o N1 corrige: sem o bloco novo, neste ponto nao
      # sobra NENHUMA memoria de quem atendia a conversa.
      expect(snapshot).to be_a(Hash)
      expect(snapshot['assignee_id']).to eq(agent.id)
      expect(snapshot['team_id']).to eq(team.id)
      expect(snapshot['inbox_id']).to eq(conversation.inbox_id)
    end

    it 'continua apagando klaos_resolved_at (comportamento antigo inalterado)' do
      expect(conversation.reload.additional_attributes).not_to have_key('klaos_resolved_at')
    end
  end

  describe 'segunda resolucao com outro dono' do
    let!(:other_agent) { create(:user, account: account, role: :agent) }

    before do
      conversation.update!(status: :resolved)
      conversation.update!(status: :pending)

      create(:inbox_member, inbox: conversation.inbox, user: other_agent)
      create(:team_member, team: team, user: other_agent)
      conversation.update!(assignee: other_agent)
      conversation.update!(status: :resolved)
    end

    it 'sobrescreve o snapshot com o dono da vez' do
      expect(snapshot['assignee_id']).to eq(other_agent.id)
    end
  end

  describe 'conversa resolvida sem dono e sem time' do
    let!(:orphan) { create(:conversation, account: account) }

    it 'grava o bloco com nulos em vez de estourar' do
      expect { orphan.update!(status: :resolved) }.not_to raise_error

      block = orphan.reload.additional_attributes['klaos_last_resolution']
      expect(block).to be_a(Hash)
      expect(block['assignee_id']).to be_nil
      expect(block['team_id']).to be_nil
      expect(block['inbox_id']).to eq(orphan.inbox_id)
    end
  end
end
