# frozen_string_literal: true

require 'rails_helper'

# (16/09/2026) Gustavo, Mais Saude: "Se abriu pelo meu usuario,
# obrigatoriamente tem que vir para mim."
#
# O upstream so atribui a quem reabre se o papel for `agent`, e faz isso num
# segundo save, depois do rodizio e dos webhooks. Gustavo e administrador:
# reabria e a conversa ficava sem dono, com a Lara atrelada.
#
# Protegido por: custom/config/initializers/klaos_reabrir_atribui_quem_reabriu.rb
RSpec.describe 'KLaOS reabrir fica com quem reabriu', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator, name: 'Gustavo') }
  let(:agente) { create(:user, account: account, role: :agent, name: 'Ludiana') }
  let(:outra) { create(:user, account: account, role: :agent, name: 'Yasmin') }

  before do
    create(:inbox_member, user: admin, inbox: inbox)
    create(:inbox_member, user: agente, inbox: inbox)
    create(:inbox_member, user: outra, inbox: inbox)
  end

  # Cria e SO DEPOIS acerta status e dono: na criacao, `determine_conversation_status`
  # troca o status por `pending` quando a inbox tem bot ativo, e o time/rodizio
  # pode escolher um dono. O teste precisa partir do estado exato.
  def conversa(status:, assignee: nil, bot: nil, team: nil, snoozed_until: nil)
    conv = create(:conversation, account: account, inbox: inbox, team: team)
    conv.update_columns(status: Conversation.statuses[status], assignee_id: assignee&.id,
                        assignee_agent_bot_id: bot&.id, snoozed_until: snoozed_until)
    conv.reload
  end

  def reabrir(conv, headers)
    post "/api/v1/accounts/#{account.id}/conversations/#{conv.display_id}/toggle_status",
         headers: headers, params: { status: 'open' }, as: :json
  end

  def mudar_status(conv, headers, status, snoozed_until: nil)
    params = { status: status }
    params[:snoozed_until] = snoozed_until if snoozed_until
    post "/api/v1/accounts/#{account.id}/conversations/#{conv.display_id}/toggle_status",
         headers: headers, params: params, as: :json
  end

  describe 'pessoa reabrindo pelo painel' do
    it 'admin reabre conversa resolvida com a Lara atrelada: fica com ele e a Lara sai' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :resolved, bot: agent_bot)

      reabrir(conv, admin.create_new_auth_token)

      expect(response).to have_http_status(:success)
      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(admin.id)
      expect(conv.assignee_agent_bot_id).to be_nil
    end

    it 'admin reabre conversa pendente (territorio do bot): fica com ele' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :pending, bot: agent_bot)

      reabrir(conv, admin.create_new_auth_token)

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(admin.id)
      expect(conv.assignee_agent_bot_id).to be_nil
    end

    it 'admin reabre conversa adiada: fica com ele' do
      conv = conversa(status: :snoozed, snoozed_until: 1.day.from_now)

      reabrir(conv, admin.create_new_auth_token)

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(admin.id)
    end

    it 'admin reabre conversa que era de outra atendente: passa a ser dele' do
      conv = conversa(status: :resolved, assignee: outra)

      reabrir(conv, admin.create_new_auth_token)

      expect(conv.reload.assignee_id).to eq(admin.id)
    end

    it 'agent reabre e fica com ela (o que o upstream ja fazia)' do
      conv = conversa(status: :resolved)

      reabrir(conv, agente.create_new_auth_token)

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(agente.id)
    end

    it 'o evento de mudanca de status ja sai com o dono (o KLaOS decide por ele)' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :resolved, bot: agent_bot)
      donos_no_evento = []
      allow(Rails.configuration.dispatcher).to receive(:dispatch) do |*args, **kw|
        dados = kw.presence || args[2] || {}
        donos_no_evento << dados[:conversation]&.assignee_id if args[0] == Events::Types::CONVERSATION_STATUS_CHANGED
      end

      reabrir(conv, admin.create_new_auth_token)

      expect(donos_no_evento).to eq([admin.id])
    end

    context 'conversa com time e rodizio ligado' do
      let(:time) { create(:team, account: account, allow_auto_assign: true) }

      before do
        create(:team_member, team: time, user: outra)
        create(:team_member, team: time, user: agente)
      end

      it 'o rodizio nao sorteia ninguem: fica com quem reabriu' do
        conv = conversa(status: :resolved, team: time)
        expect(AutoAssignment::AgentAssignmentService).not_to receive(:new)

        reabrir(conv, admin.create_new_auth_token)

        conv.reload
        expect(conv.status).to eq('open')
        expect(conv.assignee_id).to eq(admin.id)
        expect(conv.team_id).to eq(time.id)
      end

      # A notificacao de atribuicao nasce do evento ASSIGNEE_CHANGED. Se o
      # unico evento desses aponta para quem reabriu, ninguem mais foi avisado.
      it 'nenhuma outra atendente e avisada: o unico evento de atribuicao e de quem reabriu' do
        conv = conversa(status: :resolved, team: time)
        donos_avisados = []
        allow(Rails.configuration.dispatcher).to receive(:dispatch) do |*args, **kw|
          dados = kw.presence || args[2] || {}
          donos_avisados << dados[:conversation]&.assignee_id if args[0] == Events::Types::ASSIGNEE_CHANGED
        end

        reabrir(conv, admin.create_new_auth_token)

        expect(donos_avisados).to eq([admin.id])
      end
    end
  end

  describe 'o que NAO atribui' do
    it 'requisicao por api_access_token (KLaOS / I.A) nao vira dona' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :resolved, bot: agent_bot)

      reabrir(conv, { api_access_token: admin.access_token.token })

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to be_nil
      expect(conv.assignee_agent_bot_id).to eq(agent_bot.id)
    end

    it 'AgentBot pending -> open continua sendo handoff do upstream' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :pending, bot: agent_bot)

      reabrir(conv, { api_access_token: agent_bot.access_token.token })

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to be_nil
    end

    it 'resolver nao atribui' do
      conv = conversa(status: :open)

      mudar_status(conv, admin.create_new_auth_token, 'resolved')

      conv.reload
      expect(conv.status).to eq('resolved')
      expect(conv.assignee_id).to be_nil
    end

    it 'adiar nao atribui' do
      conv = conversa(status: :open)

      mudar_status(conv, admin.create_new_auth_token, 'snoozed', snoozed_until: 2.days.from_now.to_i)

      conv.reload
      expect(conv.status).to eq('snoozed')
      expect(conv.assignee_id).to be_nil
    end

    it 'admin que nao e membro da inbox nao vira dono' do
      de_fora = create(:user, account: account, role: :administrator, name: 'Marta')
      conv = conversa(status: :resolved)

      reabrir(conv, de_fora.create_new_auth_token)

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to be_nil
    end

    it 'respeita o desligamento por conta' do
      account.update!(settings: account.settings.merge('klaos_reabrir_atribui_quem_reabriu' => false))
      conv = conversa(status: :resolved)

      reabrir(conv, admin.create_new_auth_token)

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to be_nil
    end
  end

  describe 'o vizinho: auto-resolve nao fecha a conversa que acabou de ser reaberta' do
    it 'reaberta por humano ganha dono e o ResolutionJob pula' do
      account.update!(auto_resolve_after: 1440)
      conv = conversa(status: :resolved)

      reabrir(conv, admin.create_new_auth_token)
      conv.reload.update_columns(last_activity_at: 30.days.ago)
      Conversations::ResolutionJob.new.perform(account: account)

      expect(conv.reload.status).to eq('open')
    end
  end

  describe 'encerrar e reabrir na data marcada, pelo painel' do
    it 'adiar, resolver e, na hora, volta aberta com quem adiou' do
      conv = conversa(status: :open)
      volta = 2.hours.from_now

      mudar_status(conv, admin.create_new_auth_token, 'snoozed', snoozed_until: volta.to_i)
      mudar_status(conv, admin.create_new_auth_token, 'resolved')

      conv.reload
      expect(conv.status).to eq('resolved')
      expect(conv.additional_attributes['klaos_reabrir_em']).to be_present
      expect(conv.additional_attributes['klaos_reabrir_para']).to eq(admin.id)

      travel_to(volta + 1.minute) do
        Conversations::ReopenSnoozedConversationsJob.perform_now
      end

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(admin.id)
      expect(conv.additional_attributes).not_to have_key('klaos_reabrir_em')
    end

    it 'adiar e devolver ao bot: na hora, volta aberta com o dono anterior' do
      create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
      conv = conversa(status: :open, assignee: agente)
      volta = 3.hours.from_now

      mudar_status(conv, agente.create_new_auth_token, 'snoozed', snoozed_until: volta.to_i)
      post "/api/v1/accounts/#{account.id}/conversations/#{conv.display_id}/transfer_to_bot",
           headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)

      conv.reload
      expect(conv.status).to eq('pending')
      expect(conv.assignee_id).to be_nil
      expect(conv.additional_attributes['klaos_reabrir_para']).to eq(agente.id)

      travel_to(volta + 1.minute) do
        Conversations::ReopenSnoozedConversationsJob.perform_now
      end

      conv.reload
      expect(conv.status).to eq('open')
      expect(conv.assignee_id).to eq(agente.id)
    end

    it 'por api_access_token nao agenda nada' do
      conv = conversa(status: :snoozed, snoozed_until: 2.hours.from_now)

      mudar_status(conv, { api_access_token: admin.access_token.token }, 'resolved')

      conv.reload
      expect(conv.status).to eq('resolved')
      expect(conv.additional_attributes || {}).not_to have_key('klaos_reabrir_em')
    end
  end
end
