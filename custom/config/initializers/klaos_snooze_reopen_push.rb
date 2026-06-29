# frozen_string_literal: true

# KLaOS — Push notification quando conv reabre do snooze (fix queixa Gustavo).
#
# Bug original: agente "adia" conv. Job ReopenSnoozedConversationsJob reabre
# a conv (snoozed → open) corretamente, mas Chatwoot vanilla NÃO gera
# Notification do tipo "snooze_reopen" — só pra assignment/mention/new_msg.
# Agente só vê se tiver tela aberta + WebSocket conectado.
#
# Fix: hook after_update_commit em Conversation detecta status_change
# snoozed→open e enfileira Klaos::SnoozeReopenPushJob que envia Web Push
# direto pro assignee (sem Notification model — bypassa porque enum upstream
# não tem o tipo certo).
#
# Service Worker do Chatwoot já intercepta push e mostra notification do SO
# mesmo com navegador fechado / tela em outro tab.
#
# Job em custom/app/jobs/klaos/snooze_reopen_push_job.rb (Zeitwerk
# autoload — não definir aqui no initializer porque ApplicationJob ainda
# não está carregado durante rake assets:precompile do build).
#
# Dedup: 5min por conv via Redis::Alfred.

module KlaosSnoozeReopenPush
  extend ActiveSupport::Concern

  REOPEN_COOLDOWN_KEY = 'klaos:snooze_reopen_push:conv:%<id>d'
  REOPEN_COOLDOWN_SECONDS = 300

  included do
    after_update_commit :klaos_dispatch_snooze_reopen_push, if: :klaos_just_reopened_from_snooze?
  end

  private

  def klaos_just_reopened_from_snooze?
    return false unless saved_change_to_status?

    old_status, new_status = saved_change_to_status
    old_status.to_s == 'snoozed' && new_status.to_s == 'open'
  end

  def klaos_dispatch_snooze_reopen_push
    return if assignee_id.blank?

    cache_key = format(REOPEN_COOLDOWN_KEY, id: id)
    return if ::Redis::Alfred.get(cache_key).present?

    ::Redis::Alfred.setex(cache_key, true, REOPEN_COOLDOWN_SECONDS)

    Klaos::SnoozeReopenPushJob.perform_later(id, assignee_id)
  rescue StandardError => e
    Rails.logger.warn "[KlaosSnoozeReopenPush] dispatch falhou conv=#{id}: #{e.class}: #{e.message}"
  end
end

Rails.application.config.to_prepare do
  conversation_class = 'Conversation'.safe_constantize
  if conversation_class && !conversation_class.include?(KlaosSnoozeReopenPush)
    conversation_class.include(KlaosSnoozeReopenPush)
    Rails.logger.info '[KlaosSnoozeReopenPush] included on Conversation'
  end
end
