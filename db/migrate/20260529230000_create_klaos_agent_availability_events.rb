# frozen_string_literal: true

# KLaOS — Tabela pra trackear mudanças de availability do agente
# (online / busy / offline) com início e fim. Alimenta o Painel de
# Agentes (supervisão em tempo real) com tempos "logado hoje" e
# "pausa hoje" calculados — Chatwoot nativo não persiste isso.
#
# Um evento "aberto" tem ended_at NULL. Quando o agente muda de
# status, o evento corrente é fechado (ended_at = now) e um novo é
# aberto. Reset diário virtual: queries somam por dia ignorando
# eventos cruzando meia-noite (são "split" no SELECT via LEAST/GREATEST).
#
# Multi-tenant nato — account_id na chave.

class CreateKlaosAgentAvailabilityEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :klaos_agent_availability_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      # 0 = offline, 1 = online, 2 = busy (espelha User#availability_status enum)
      t.integer :status, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: true
      t.timestamps
    end

    add_index :klaos_agent_availability_events,
              %i[account_id user_id started_at],
              name: 'idx_klaos_avail_account_user_start'

    add_index :klaos_agent_availability_events,
              %i[account_id user_id ended_at],
              where: 'ended_at IS NULL',
              name: 'idx_klaos_avail_open_events'
  end
end
