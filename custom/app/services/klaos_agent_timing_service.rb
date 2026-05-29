# frozen_string_literal: true

# KLaOS — Service de timing pra Painel de Agentes (O.1).
#
# Wrapper fino sobre KlaosAgentAvailabilityEvent.totals_for_day que:
#   - normaliza tz default (America/Sao_Paulo)
#   - garante chaves pra TODOS os user_ids passados (mesmo sem eventos no dia)
#   - inclui shortcut `attended_today` (count de conversas que o agente
#     resolveu hoje)
#
# Não inclui TMA — esse vem do AgentReportBuilder nativo.

class KlaosAgentTimingService
  TZ = 'America/Sao_Paulo'

  attr_reader :account, :user_ids, :day, :tz

  def initialize(account:, user_ids:, day: nil, tz: TZ)
    @account  = account
    @user_ids = Array(user_ids).map(&:to_i).uniq
    @tz       = tz
    @day      = day || Time.current.in_time_zone(tz).to_date
  end

  # { user_id => { online_s:, busy_s:, offline_s:, attended_today: } }
  def call
    totals = KlaosAgentAvailabilityEvent.totals_for_day(
      account_id: account.id,
      user_ids: user_ids,
      day: day,
      tz: tz
    )
    attended = attended_today_by_user

    user_ids.each_with_object({}) do |uid, acc|
      row = totals[uid] || { 'online' => 0, 'busy' => 0, 'offline' => 0 }
      acc[uid] = {
        online_s: row['online'],
        busy_s: row['busy'],
        offline_s: row['offline'],
        attended_today: attended[uid] || 0
      }
    end
  end

  private

  def attended_today_by_user
    zone = ActiveSupport::TimeZone[tz] || Time.zone
    day_start = zone.local(day.year, day.month, day.day, 0, 0, 0).utc
    day_end   = day_start + 1.day

    account.conversations
           .where(assignee_id: user_ids, status: :resolved)
           .where(updated_at: day_start...day_end)
           .group(:assignee_id)
           .count
  end
end
