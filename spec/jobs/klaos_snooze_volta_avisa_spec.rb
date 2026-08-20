# frozen_string_literal: true

require 'rails_helper'

# (19/08/2026) A conversa voltava do adiamento em SILÊNCIO.
#
# O aviso saía do servidor e chegava no navegador — o pacote foi capturado ao
# vivo. Só que ele não levava o dono da conversa, e o front tentava descobrir
# quem era procurando a conversa na store. A store não tem conversa adiada
# (os filtros padrão omitem `snoozed`), que é exatamente o motivo deste
# broadcast existir. Sem dono, o filtro "só alerta conversa minha" reprovava
# todas e a função saía antes de tocar o som.
#
# E, quando voltava, não ficava rastro nenhum: quem reabre aqui é o job, não
# uma pessoa, e o upstream só escreve atividade de status quando existe
# `Current.user` (`activity_message_handler.rb:70-79`). A última linha da
# timeline continuava sendo "Conversa foi adiada por Fulano", sem nunca dizer
# que voltou.
RSpec.describe 'KLaOS conversa que volta do adiamento avisa e deixa rastro' do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Cliente Teste') }
  let(:inbox) { create(:inbox, account: account) }
  let(:atendente) { create(:user, account: account) }

  def conversa_adiada(vencida:, dono: nil)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    create(
      :conversation,
      account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
      status: :snoozed, assignee: dono,
      snoozed_until: vencida ? 5.minutes.ago : 1.day.from_now
    )
  end

  # Espia o broadcast em vez de ler a fila: `enqueued_jobs` devolve os
  # argumentos já serializados pelo ActiveJob (chaves viram string, com
  # `_aj_symbol_keys` no meio), e o que interessa aqui é o payload como o
  # navegador recebe.
  let(:broadcasts) { [] }

  before do
    allow(::ActionCableBroadcastJob).to receive(:perform_later) do |tokens, evento, payload|
      broadcasts << { tokens: tokens, evento: evento, payload: payload }
    end
  end

  def pacote_do_broadcast
    envio = broadcasts.find { |b| b[:evento] == KlaosSnoozeNoLimit::KLAOS_SNOOZE_REOPENED_EVENT }
    envio && envio[:payload]
  end

  describe 'o pacote que chega no navegador' do
    it 'leva o DONO da conversa — sem ele o alerta morre antes do som' do
      conversa = conversa_adiada(vencida: true, dono: atendente)

      Conversations::ReopenSnoozedConversationsJob.perform_now

      pacote = pacote_do_broadcast
      expect(pacote).to be_present
      expect(pacote[:assignee_id]).to eq(atendente.id)
      expect(conversa.reload.status).to eq('open')
    end

    it 'leva os dois números: o interno e o público que o front usa' do
      conversa = conversa_adiada(vencida: true, dono: atendente)

      Conversations::ReopenSnoozedConversationsJob.perform_now

      pacote = pacote_do_broadcast
      # O front casa pelo display_id: na store, `c.id` vale o display_id
      # porque a API serializa `display_id` como `id` no JSON.
      expect(pacote[:conversation_display_id]).to eq(conversa.display_id)
      expect(pacote[:conversation_id]).to eq(conversa.id)
    end

    it 'conversa sem dono não quebra o broadcast — só não alerta ninguém' do
      conversa_adiada(vencida: true, dono: nil)

      expect { Conversations::ReopenSnoozedConversationsJob.perform_now }.not_to raise_error

      pacote = pacote_do_broadcast
      expect(pacote).to be_present
      expect(pacote[:assignee_id]).to be_nil
    end
  end

  describe 'o rastro na conversa' do
    it 'escreve na timeline que a conversa voltou' do
      conversa = conversa_adiada(vencida: true, dono: atendente)

      perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
        Conversations::ReopenSnoozedConversationsJob.perform_now
      end

      atividade = conversa.reload.messages.where(message_type: :activity).last
      expect(atividade).to be_present
      expect(atividade.content).to include('adiamento')
    end

    it 'a linha é interna: atividade nunca é entregue ao cliente' do
      conversa = conversa_adiada(vencida: true, dono: atendente)

      perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
        Conversations::ReopenSnoozedConversationsJob.perform_now
      end

      atividade = conversa.reload.messages.where(message_type: :activity).last
      expect(atividade.message_type).to eq('activity')
      expect(conversa.messages.where(message_type: :outgoing)).to be_empty
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # Blindagem do que JÁ funcionava. O motivo deste initializer existir é o
  # limite de 3 dias do upstream, que fazia conversa adiada há muito tempo
  # nunca mais voltar ("a conversa não volta", reportado pelo Gustavo).
  # ─────────────────────────────────────────────────────────────────────────
  describe 'o que já funcionava continua funcionando' do
    it 'adiada há mais de 3 dias volta — é o motivo deste initializer existir' do
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
      antiga = create(
        :conversation,
        account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
        status: :snoozed, assignee: atendente, snoozed_until: 10.days.ago
      )

      Conversations::ReopenSnoozedConversationsJob.perform_now

      expect(antiga.reload.status).to eq('open')
    end

    it 'adiada para o futuro NÃO volta antes da hora' do
      futura = conversa_adiada(vencida: false, dono: atendente)

      Conversations::ReopenSnoozedConversationsJob.perform_now

      expect(futura.reload.status).to eq('snoozed')
    end

    it 'continua carimbando a volta para a Central do agente' do
      conversa = conversa_adiada(vencida: true, dono: atendente)

      Conversations::ReopenSnoozedConversationsJob.perform_now

      extras = conversa.reload.additional_attributes || {}
      expect(extras['klaos_returned_from_snooze_at']).to be_present
    end
  end
end
