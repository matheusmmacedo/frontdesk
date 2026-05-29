# frozen_string_literal: true

# KLaOS — Cron de 1 min só pra reabrir conversas adiadas (snoozed).
#
# Por que: o cron upstream `trigger_scheduled_items_job` roda */5 min e
# dispara 5 jobs em sequência (incluindo sync de templates Meta que tem
# rate limit). Reabertura de snooze precisa ser mais ágil pra UX boa,
# mas trocar o cron geral pra */1 quintuplicaria load no Meta API e
# outros side effects.
#
# Solução cirúrgica: adicionar UM novo cron entry rodando apenas
# Conversations::ReopenSnoozedConversationsJob a cada 1 min, sem mexer
# no upstream. Resultado: agente que adiou conv pra 16:07 vê alerta
# disparar até 16:08 BR (em vez de até 16:10).
#
# Usa Sidekiq::Cron::Job.create que é idempotente — se rodar duas vezes
# no boot, mantém um único job registrado.

Rails.application.config.after_initialize do
  next unless defined?(Sidekiq) && Sidekiq.server?

  begin
    require 'sidekiq/cron/job'
    Sidekiq::Cron::Job.create(
      name: 'klaos_reopen_snoozed_conversations_1min',
      cron: '*/1 * * * *',
      class: 'Conversations::ReopenSnoozedConversationsJob',
      queue: 'low'
    )
    Rails.logger.info '[KlaosSnoozeReopen1min] cron */1 min registrado'
  rescue StandardError => e
    Rails.logger.warn "[KlaosSnoozeReopen1min] falha ao registrar cron: #{e.class}: #{e.message}"
  end
end
