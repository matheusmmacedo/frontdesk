# frozen_string_literal: true

# KLaOS — Evento de mudança de availability do agente.
#
# Cada linha = um intervalo contínuo em UM status (online / busy /
# offline). O evento "aberto" tem ended_at NULL — é o status atual
# do agente. Quando muda, fecha (ended_at = now) e abre novo.
#
# Alimenta o Painel de Agentes (O.1) com "tempo logado hoje" e
# "tempo em pausa hoje". Reset diário é virtual: queries somam
# por dia clipando eventos que cruzam meia-noite.
#
# Multi-tenant nato — account_id obrigatório.

class KlaosAgentAvailabilityEvent < ApplicationRecord
  self.table_name = 'klaos_agent_availability_events'

  belongs_to :account
  belongs_to :user
  belongs_to :pause_reason, class_name: 'KlaosPauseReason', optional: true

  enum status: { offline: 0, online: 1, busy: 2 }

  scope :open, -> { where(ended_at: nil) }
  scope :for_user_account, ->(account_id, user_id) { where(account_id: account_id, user_id: user_id) }

  # Soma de duração (segundos) por status no dia indicado para
  # uma lista de user_ids. Clipa o início/fim de cada evento ao
  # dia para lidar com eventos que cruzam meia-noite.
  #
  # Retorna: { user_id => { 'online' => Integer, 'busy' => Integer, 'offline' => Integer } }
  def self.totals_for_day(account_id:, user_ids:, day: Date.current, tz: 'America/Sao_Paulo')
    return {} if user_ids.blank?

    zone = ActiveSupport::TimeZone[tz] || Time.zone
    day_start = zone.local(day.year, day.month, day.day, 0, 0, 0)
    day_end   = day_start + 1.day

    # Pega TODOS os eventos que tocam o dia (started_at < day_end E (ended_at IS NULL OU ended_at > day_start))
    scope = where(account_id: account_id, user_id: user_ids)
            .where('started_at < ?', day_end)
            .where('ended_at IS NULL OR ended_at > ?', day_start)

    result = Hash.new { |h, k| h[k] = { 'online' => 0, 'busy' => 0, 'offline' => 0 } }

    scope.find_each do |ev|
      clip_start = [ev.started_at, day_start].max
      clip_end   = [ev.ended_at || Time.current, day_end].min
      seconds    = (clip_end - clip_start).to_i
      next if seconds <= 0

      result[ev.user_id][ev.status] += seconds
    end

    result
  end
end
