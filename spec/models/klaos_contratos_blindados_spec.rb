# frozen_string_literal: true

require 'rails_helper'

# CONTRATOS BLINDADOS — comportamentos que JA custaram incidente em producao.
#
# Por que este arquivo existe: em 07/08/2026 o auto-resolve passou a fechar toda
# conversa cobrada 1 minuto depois do envio. A causa nao foi um codigo errado —
# foi um fix legitimo de JUNHO (klaos_sort_ignore_activities) que, ao mudar
# quando `last_activity_at` e escrito, mudou junto o relogio de um sistema que
# ninguem estava olhando. Nao havia um unico teste travando nenhum dos dois
# lados, entao a colisao so apareceu quando o cliente reclamou.
#
# Cada exemplo aqui trava UM contrato de operacao. Se um fix futuro reverter
# qualquer um deles, o teste quebra e diz qual incidente vai voltar. Isso e o
# objetivo: nao proteger a implementacao, e sim o comportamento que a operacao
# depende.
#
# Ao mexer em qualquer coisa que toque status de conversa, atribuicao ou
# ordenacao da lista, rode este arquivo ANTES de abrir o PR.

RSpec.describe 'KLaOS — contratos blindados de operacao' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:agente) { create(:user, account: account, role: :agent) }

  def nova_conversa(status: :open, assignee: nil)
    create(:conversation, account: account, inbox: inbox, contact: contact,
                          contact_inbox: contact_inbox, status: status, assignee: assignee)
  end

  # ---------------------------------------------------------------------------
  # CONTRATO 1 — ordenacao da lista
  # Queixa do Gustavo (junho): "estou atendendo o cliente na 50a posicao, mexo na
  # etiqueta e a conversa pula pra 1a — perco o contexto". So mensagem do cliente
  # pode subir a conversa.
  # Protegido por: custom/config/initializers/klaos_sort_ignore_activities.rb
  # ---------------------------------------------------------------------------
  describe 'ordenacao: so o cliente sobe a conversa na lista' do
    it 'resposta do atendente NAO muda a posicao' do
      conversa = nova_conversa
      conversa.update_columns(last_activity_at: 10.days.ago)
      antes = conversa.reload.last_activity_at

      create(:message, account: account, inbox: inbox, conversation: conversa,
                       message_type: :outgoing, private: false, content: 'ja verifiquei aqui')

      expect(conversa.reload.last_activity_at).to be_within(1.second).of(antes)
    end

    it 'etiqueta/atribuicao NAO muda a posicao' do
      conversa = nova_conversa
      conversa.update_columns(last_activity_at: 10.days.ago)
      antes = conversa.reload.last_activity_at

      create(:message, account: account, inbox: inbox, conversation: conversa,
                       message_type: :activity, private: false, content: 'adicionou etiqueta')

      expect(conversa.reload.last_activity_at).to be_within(1.second).of(antes)
    end

    it 'mensagem do cliente SOBE a conversa' do
      conversa = nova_conversa
      conversa.update_columns(last_activity_at: 10.days.ago)

      create(:message, account: account, inbox: inbox, conversation: conversa,
                       message_type: :incoming, private: false, content: 'oi, tudo bem?')

      expect(conversa.reload.last_activity_at).to be > 1.minute.ago
    end
  end

  # ---------------------------------------------------------------------------
  # CONTRATO 2 — auto-resolve nao encosta em conversa com dono
  # Incidente 02/08/2026: o auto-resolve fechou 67 conversas que estavam
  # atribuidas a Gustavo, Yasmin e outros. Do ponto de vista do atendente, a
  # conversa dele sumiu da caixa sozinha.
  # Protegido por: klaos_auto_resolve_skip_assigned.rb
  # ---------------------------------------------------------------------------
  describe 'auto-resolve: quem tem atendente responsavel nao e fechado' do
    before { account.update!(auto_resolve_after: 1440) }

    it 'conversa parada COM atendente continua aberta' do
      conversa = nova_conversa(assignee: agente)
      conversa.update_columns(last_activity_at: 30.days.ago)

      Conversations::ResolutionJob.new.perform(account: account)

      expect(conversa.reload.status).to eq('open')
    end

    it 'conversa parada SEM atendente e fechada — orfa e o alvo legitimo' do
      conversa = nova_conversa
      conversa.update_columns(last_activity_at: 30.days.ago)

      Conversations::ResolutionJob.new.perform(account: account)

      expect(conversa.reload.status).to eq('resolved')
    end
  end

  # ---------------------------------------------------------------------------
  # CONTRATO 3 — conversa cobrada nao pode ser fechada na sequencia
  # Incidente 07/08/2026: 74 de 86 cobrancas do dia fechadas 1 minuto apos o
  # envio, carimbadas "1 days of inactivity". Gustavo: "so tem 6 conversas
  # abertas". Este e o contrato que amarra os CONTRATOS 1 e 3 juntos — dar certo
  # nos dois ao mesmo tempo e o ponto.
  # Protegido por: klaos_auto_resolve_relogio_real.rb
  # ---------------------------------------------------------------------------
  describe 'cobranca recem-enviada sobrevive' do
    before { account.update!(auto_resolve_after: 1440) }

    it 'nao fecha, mesmo com last_activity_at antigo' do
      conversa = nova_conversa
      conversa.update_columns(last_activity_at: 60.days.ago)
      create(:message, account: account, inbox: inbox, conversation: conversa,
                       message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

      Conversations::ResolutionJob.new.perform(account: account)

      expect(conversa.reload.status).to eq('open')
    end
  end

  # ---------------------------------------------------------------------------
  # CONTRATO 4 — reabrir nunca pode sortear atendente
  # Queixa recorrente: "as conversas da Yasmin estao caindo pro Gustavo". Reabrir
  # em `open` com assignee vazio aciona o AutoAssignmentHandler; com 80 cobrancas
  # por dia isso despeja a fila inteira, sorteada, em cima da equipe.
  # Protegido por: klaos_reabre_em_acao_nossa.rb (usa `pending`, nao `open`)
  # ---------------------------------------------------------------------------
  describe 'reabertura por acao nossa nao sorteia ninguem' do
    it 'cobranca em conversa resolvida volta sem dono sorteado' do
      create(:agent_bot_inbox, inbox: inbox, account: account)
      inbox.update!(enable_auto_assignment: true)
      create(:inbox_member, inbox: inbox, user: agente)
      conversa = nova_conversa(status: :resolved)

      create(:message, account: account, inbox: inbox, conversation: conversa,
                       message_type: :outgoing, private: false, content: 'cobr_d0_vencimento_v2')

      conversa.reload
      expect(conversa.status).to eq('pending')
      expect(conversa.assignee_id).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # CONTRATO 5 — conversa adiada sempre volta
  # O job do upstream usa `snoozed_until: 3.days.ago..Time.current`. O `3.days.ago`
  # e PISO, nao teto: quem venceu antes disso nunca mais e reaberto — e `snoozed`
  # nao aparece em fila nenhuma, some da operacao em silencio.
  # Protegido por: klaos_snooze_no_limit.rb
  # ---------------------------------------------------------------------------
  describe 'adiada vencida volta, nao importa ha quanto tempo' do
    it 'volta mesmo tendo vencido ha mais de 3 dias' do
      conversa = nova_conversa(status: :snoozed)
      conversa.update_columns(snoozed_until: 10.days.ago)

      Conversations::ReopenSnoozedConversationsJob.new.perform

      expect(conversa.reload.status).to eq('open')
    end

    it 'adiada "ate o cliente responder" (sem hora) continua adiada' do
      conversa = nova_conversa(status: :snoozed)
      conversa.update_columns(snoozed_until: nil)

      Conversations::ReopenSnoozedConversationsJob.new.perform

      expect(conversa.reload.status).to eq('snoozed')
    end
  end
end
