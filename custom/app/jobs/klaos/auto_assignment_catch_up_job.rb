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
#   - existe outro membro do (inbox.members ∩ team.members) que ESTÁ online
#
# Rate limit: cada conv pode ser re-atribuída no máximo uma vez a cada 5min
# (Redis SETEX). Evita ping-pong se múltiplos agentes ficam alternando estado.
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

    RATE_LIMIT_TTL_SECONDS = 300 # 5 min
    RATE_LIMIT_KEY = 'klaos:catchup:conv:%<conv_id>d'

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

      new_user_id = candidate_ids.sort.first
      new_user = User.find_by(id: new_user_id)
      return unless new_user

      old_assignee_id = conv.assignee_id
      Current.executed_by = inbox
      conv.update!(assignee: new_user)
      mark_rate_limit(conv.id)

      Rails.logger.info(
        "[KlaosCatchUp] promoted conv=#{conv.id} team=#{team.id} " \
        "from offline_user=#{old_assignee_id} to online_user=#{new_user_id}"
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
  end
end
