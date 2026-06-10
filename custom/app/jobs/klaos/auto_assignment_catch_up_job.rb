# frozen_string_literal: true

# AUTO ASSIGNMENT — CATCH-UP JOB (Bug F1, parte B)
#
# Complementa o offline-fallback (auto_assignment_offline_fallback.rb): após
# uma conversa ser atribuída a um agente *offline* (porque ninguém do time
# estava online no momento do handoff), este job promove a atribuição para
# um agente *online* assim que algum membro do time entra online.
#
# Critério de re-assign:
#   - team_id IS NOT NULL
#   - assignee_id IS NOT NULL  (passou pelo fallback A)
#   - status open
#   - assignee atual NÃO está online (Redis)
#   - last_activity_at < 4h (só convs recentes — não move estoque velho)
#   - existe outro membro do (inbox.members ∩ team.members) que ESTÁ online
#
# Rate limit (DOIS níveis pra evitar rajada):
#   - Por conv: 5min (Redis SETEX) — evita ping-pong
#   - Por conta: 5 reatribuições/minuto (Redis INCR + TTL 120s) — evita
#     que TODA a fila de um agente offline caia em rajada num agente só
#
# Bug histórico (10/06/2026): sem o rate limit por conta + sem o load
# balancing do LeastLoadedPicker, quando Yasmin saiu offline 24 convs
# foram pra Ludi em 6 segundos (catch-up usava sort.first e processava
# tudo num tick só). Ver custom/app/services/klaos/least_loaded_picker.rb
#
# Roda a cada 2min via sidekiq-cron (registrado em
# auto_assignment_catch_up_schedule.rb).
#
# Habilitado per-account via accounts.custom_attributes:
#   { "klaos_auto_assignment_offline_fallback": true }
# (mesma flag do A — quem quer fallback quer também o catch-up)

module Klaos
  class AutoAssignmentCatchUpJob < ApplicationJob
    queue_as :scheduled_jobs

    RATE_LIMIT_TTL_SECONDS = 300 # 5 min por conv
    RATE_LIMIT_KEY = 'klaos:catchup:conv:%<conv_id>d'

    ACCOUNT_RATE_PER_MIN     = 5     # max reatribuições por conta por minuto
    ACCOUNT_RATE_TTL_SECONDS = 120   # janela com folga (2min p/ cobrir borda)
    ACCOUNT_RATE_KEY         = 'klaos:catchup:acct:%<account_id>d:%<minute>s'

    SCOPE_RECENT_HOURS = 4 # só catch-up em convs com last_activity_at < 4h

    def perform
      enabled_accounts.each do |account|
        process_account(account)
      end
    end

    private

    def enabled_accounts
      Account.where("custom_attributes->>'klaos_auto_assignment_offline_fallback' = 'true'")
    end

    def process_account(account)
      online_user_ids = fetch_online_user_ids(account.id)
      return if online_user_ids.empty?

      candidate_conversations(account).find_each do |conv|
        next if rate_limited?(conv.id)
        next if assignee_online?(conv, online_user_ids)
        next if account_rate_limited?(account.id) # global cap atingido — para esse tick

        promote_to_online_member(conv, online_user_ids)
      end
    rescue StandardError => e
      Rails.logger.error(
        "[KlaosCatchUp] account=#{account.id} error: #{e.class} #{e.message} | " \
        "#{e.backtrace.first(5).join(' | ')}"
      )
    end

    def candidate_conversations(account)
      account.conversations
             .where(status: :open)
             .where.not(team_id: nil)
             .where.not(assignee_id: nil)
             .where('last_activity_at > ?', SCOPE_RECENT_HOURS.hours.ago)
    end

    def fetch_online_user_ids(account_id)
      OnlineStatusTracker.get_available_users(account_id)
                         .select { |_k, v| v == 'online' }
                         .keys
                         .map(&:to_i)
    end

    def assignee_online?(conv, online_user_ids)
      online_user_ids.include?(conv.assignee_id)
    end

    def promote_to_online_member(conv, online_user_ids)
      team = conv.team
      inbox = conv.inbox
      return if team.nil? || inbox.nil?
      return if team.allow_auto_assign.blank?

      candidate_ids = (inbox.member_ids_with_assignment_capacity & team.members.ids) & online_user_ids
      candidate_ids -= [conv.assignee_id]
      return if candidate_ids.empty?

      # Load balancing: escolhe agente com MENOR número de convs abertas.
      # Substitui o antigo `candidate_ids.sort.first` que sempre pegava
      # o menor ID (bug do 10/06: rajada inteira pra mesma pessoa).
      new_user_id = Klaos::LeastLoadedPicker.pick(
        account_id: conv.account_id,
        candidate_ids: candidate_ids
      )
      return unless new_user_id

      new_user = User.find_by(id: new_user_id)
      return unless new_user

      old_assignee_id = conv.assignee_id
      Current.executed_by = inbox
      conv.update!(assignee: new_user)
      mark_rate_limit(conv.id)
      mark_account_rate_limit(conv.account_id)

      Rails.logger.info(
        "[KlaosCatchUp] promoted conv=#{conv.id} team=#{team.id} " \
        "from offline_user=#{old_assignee_id} to online_user=#{new_user_id} " \
        "(picked via least_loaded among #{candidate_ids.inspect})"
      )
    ensure
      Current.executed_by = nil
    end

    def rate_limit_key(conv_id)
      format(RATE_LIMIT_KEY, conv_id: conv_id)
    end

    def rate_limited?(conv_id)
      ::Redis::Alfred.get(rate_limit_key(conv_id)).present?
    end

    def mark_rate_limit(conv_id)
      ::Redis::Alfred.setex(rate_limit_key(conv_id), '1', RATE_LIMIT_TTL_SECONDS)
    end

    def account_rate_key(account_id)
      # Bucket por minuto. Garante cap deterministico por janela.
      minute = Time.current.strftime('%Y%m%d%H%M')
      format(ACCOUNT_RATE_KEY, account_id: account_id, minute: minute)
    end

    def account_rate_limited?(account_id)
      ::Redis::Alfred.get(account_rate_key(account_id)).to_i >= ACCOUNT_RATE_PER_MIN
    end

    def mark_account_rate_limit(account_id)
      key = account_rate_key(account_id)
      ::Redis::Alfred.incr(key)
      ::Redis::Alfred.expire(key, ACCOUNT_RATE_TTL_SECONDS)
    end
  end
end
