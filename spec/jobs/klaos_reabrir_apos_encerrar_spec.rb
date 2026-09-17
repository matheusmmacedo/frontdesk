# frozen_string_literal: true

require 'rails_helper'

# (16/09/2026) Gustavo, Mais Saude: "A reabertura do contato com data e hora
# prevista depois de encerrar a conversa" nunca funcionou.
#
# Ele adia e, segundos depois, resolve ou devolve ao bot. O upstream apaga o
# `snoozed_until` quando o status deixa de ser `snoozed`, e o job so procura
# `snoozed`. Conta 9, 30 dias: 5 adiamentos, os 5 perdidos assim.
#
# Protegido por:
#   custom/config/initializers/klaos_reabrir_em_data_marcada.rb (guarda a hora)
#   custom/config/initializers/klaos_snooze_no_limit.rb (volta na hora)
RSpec.describe 'KLaOS encerrar e reabrir na data marcada' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:gustavo) { create(:user, account: account, role: :administrator, name: 'Gustavo') }
  let(:ludiana) { create(:user, account: account, role: :agent, name: 'Ludiana') }
  let(:broadcasts) { [] }

  before do
    create(:inbox_member, user: gustavo, inbox: inbox)
    create(:inbox_member, user: ludiana, inbox: inbox)
    allow(::ActionCableBroadcastJob).to receive(:perform_later) do |tokens, evento, payload|
      broadcasts << { tokens: tokens, evento: evento, payload: payload }
    end
  end

  after do
    Current.reset
    KlaosOrigemDaRequisicao.via_token = nil
  end

  def conversa_adiada(ate:, dono: nil, extras: {})
    contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
    conv = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
    conv.update_columns(status: Conversation.statuses[:snoozed], snoozed_until: ate,
                        assignee_id: dono&.id, additional_attributes: extras)
    conv.reload
  end

  # Mesma coisa que o painel faz: Current.user e a pessoa logada.
  def como(usuario)
    Current.user = usuario
    yield
  ensure
    Current.user = nil
  end

  def rodar_job
    Conversations::ReopenSnoozedConversationsJob.perform_now
  end

  def voltas_avisadas
    broadcasts.count { |b| b[:evento] == KlaosSnoozeNoLimit::KLAOS_SNOOZE_REOPENED_EVENT }
  end

  describe 'guardar a hora' do
    it 'resolver uma adiada antes da hora guarda a hora e o dono' do
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)

      como(gustavo) { conv.update!(status: :resolved) }

      extras = conv.reload.additional_attributes
      expect(Time.zone.parse(extras['klaos_reabrir_em'])).to be_within(1.second).of(ate)
      expect(extras['klaos_reabrir_para']).to eq(ludiana.id)
    end

    it 'sem dono, guarda quem resolveu' do
      conv = conversa_adiada(ate: 2.hours.from_now)

      como(gustavo) { conv.update!(status: :resolved) }

      expect(conv.reload.additional_attributes['klaos_reabrir_para']).to eq(gustavo.id)
    end

    it 'devolver ao bot (pending) tambem guarda o dono anterior' do
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana)

      como(gustavo) { conv.update!(status: :pending, assignee_id: nil) }

      expect(conv.reload.additional_attributes['klaos_reabrir_para']).to eq(ludiana.id)
    end

    it 'o merge preserva as outras chaves' do
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana,
                             extras: { 'klaos_returned_from_snooze_at' => '2026-09-01T10:00:00Z',
                                       'klaos_last_resolution' => { 'assignee_id' => 1 },
                                       'browser_language' => 'pt-BR' })

      como(gustavo) { conv.update!(status: :resolved) }

      extras = conv.reload.additional_attributes
      expect(extras['klaos_returned_from_snooze_at']).to eq('2026-09-01T10:00:00Z')
      expect(extras['browser_language']).to eq('pt-BR')
      expect(extras['klaos_reabrir_em']).to be_present
      # klaos_last_resolution e reescrito pelo track_resolved_timestamp; a chave continua la.
      expect(extras).to have_key('klaos_last_resolution')
    end

    it 'adiamento ja vencido nao agenda nada' do
      conv = conversa_adiada(ate: 5.minutes.ago, dono: ludiana)

      como(gustavo) { conv.update!(status: :resolved) }

      expect(conv.reload.additional_attributes).not_to have_key('klaos_reabrir_em')
    end

    it 'sem pessoa (job, sistema) nao agenda nada' do
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana)

      conv.update!(status: :resolved)

      expect(conv.reload.additional_attributes).not_to have_key('klaos_reabrir_em')
    end

    it 'por api_access_token nao agenda nada' do
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana)
      KlaosOrigemDaRequisicao.via_token = true

      como(gustavo) { conv.update!(status: :resolved) }

      expect(conv.reload.additional_attributes).not_to have_key('klaos_reabrir_em')
    end

    it 'respeita o desligamento por conta' do
      account.update!(settings: account.settings.merge('klaos_reabrir_em_data_marcada' => false))
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana)

      como(gustavo) { conv.update!(status: :resolved) }

      expect(conv.reload.additional_attributes).not_to have_key('klaos_reabrir_em')
    end

    it 'a marca sai quando a conversa volta antes da hora (ninguem reabre depois por engano)' do
      conv = conversa_adiada(ate: 2.hours.from_now, dono: ludiana)
      como(gustavo) { conv.update!(status: :resolved) }

      como(gustavo) { conv.reload.update!(status: :open) }

      expect(conv.reload.additional_attributes).not_to have_key('klaos_reabrir_em')
      expect(conv.additional_attributes).not_to have_key('klaos_reabrir_para')
    end
  end

  describe 'voltar na hora' do
    it 'adiar, resolver e, na hora, volta aberta com o dono' do
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) { conv.update!(status: :resolved) }

      travel_to(ate + 1.minute) do
        perform_enqueued_jobs(only: Conversations::ActivityMessageJob) { rodar_job }
      end

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(ludiana.id)
      expect(conv.additional_attributes).not_to have_key('klaos_reabrir_em')
      expect(conv.additional_attributes).not_to have_key('klaos_reabrir_para')
      expect(conv.additional_attributes['klaos_returned_from_snooze_at']).to be_present
      # a volta tambem e merge: a memoria do ultimo encerramento fica
      expect(conv.additional_attributes).to have_key('klaos_last_resolution')
      expect(conv.messages.where(message_type: :activity).pluck(:content))
        .to include('Conversa reaberta automaticamente: chegou a data marcada ao encerrar.')
      expect(voltas_avisadas).to eq(1)
    end

    it 'antes da hora nao volta' do
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) { conv.update!(status: :resolved) }

      rodar_job

      expect(conv.reload.status).to eq('resolved')
      expect(conv.additional_attributes['klaos_reabrir_em']).to be_present
    end

    it 'devolvida ao bot volta aberta com o dono e sem a Lara atrelada' do
      bot = create(:agent_bot, account: account)
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) { conv.update!(status: :pending, assignee_id: nil, assignee_agent_bot_id: bot.id) }

      travel_to(ate + 1.minute) { rodar_job }

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(ludiana.id)
      expect(conv.assignee_agent_bot_id).to be_nil
    end

    it 'reabre uma vez so, mesmo com o job rodando duas vezes' do
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) { conv.update!(status: :resolved) }
      marca = conv.reload.additional_attributes.slice('klaos_reabrir_em', 'klaos_reabrir_para')

      travel_to(ate + 1.minute) do
        perform_enqueued_jobs(only: Conversations::ActivityMessageJob) do
          rodar_job
          # Segunda execucao concorrente que ainda enxergou a conversa marcada.
          conv.reload.update_columns(status: Conversation.statuses[:resolved],
                                     additional_attributes: conv.additional_attributes.merge(marca))
          rodar_job
        end
      end

      atividades = conv.reload.messages.where(message_type: :activity)
                       .where(content: 'Conversa reaberta automaticamente: chegou a data marcada ao encerrar.')
      expect(atividades.count).to eq(1)
      expect(voltas_avisadas).to eq(1)
    end

    it 'dono que saiu da caixa nao e atribuido; a conversa volta assim mesmo' do
      ate = 2.hours.from_now
      conv = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) { conv.update!(status: :resolved) }
      InboxMember.where(inbox: inbox, user: ludiana).destroy_all
      conv.update_columns(assignee_id: nil)

      travel_to(ate + 1.minute) { rodar_job }

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to be_nil
    end

    it 'data mal formada nao derruba o laco: as outras voltam' do
      ate = 2.hours.from_now
      ruim = conversa_adiada(ate: ate, dono: ludiana)
      boa = conversa_adiada(ate: ate, dono: ludiana)
      como(gustavo) do
        ruim.update!(status: :resolved)
        boa.update!(status: :resolved)
      end
      ruim.reload.update_columns(additional_attributes: ruim.additional_attributes.merge('klaos_reabrir_em' => 'amanha'))

      travel_to(ate + 1.minute) { expect { rodar_job }.not_to raise_error }

      expect(boa.reload.status).to eq('open')
      expect(ruim.reload.status).to eq('resolved')
    end

    it 'resolvida sem a marca nao e tocada' do
      contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox)
      conv = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
      conv.update_columns(status: Conversation.statuses[:resolved])

      rodar_job

      expect(conv.reload.status).to eq('resolved')
    end
  end

  describe 'o vizinho: adiada comum continua voltando' do
    it 'adiada vencida volta pelo laco de sempre, com aviso' do
      conv = conversa_adiada(ate: 5.minutes.ago, dono: ludiana)

      rodar_job

      expect(conv.reload.status).to eq('open')
      expect(conv.assignee_id).to eq(ludiana.id)
      expect(voltas_avisadas).to eq(1)
    end
  end
end
