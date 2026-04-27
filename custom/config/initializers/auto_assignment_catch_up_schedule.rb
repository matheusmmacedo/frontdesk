# frozen_string_literal: true

# AUTO ASSIGNMENT — CATCH-UP CRON SCHEDULE
#
# Registra o Klaos::AutoAssignmentCatchUpJob no sidekiq-cron, sem modificar
# config/schedule.yml (mantém upstream pristine). Roda só no Sidekiq server,
# nunca no web/process client.
#
# Frequência: */2 * * * * (a cada 2min). Job é barato — query indexada por
# account_id+status+team_id, processa só contas com flag habilitada.

Rails.application.reloader.to_prepare do
  next unless Sidekiq.server?

  job = Sidekiq::Cron::Job.new(
    name: 'klaos_auto_assignment_catch_up',
    cron: '*/2 * * * *',
    class: 'Klaos::AutoAssignmentCatchUpJob',
    queue: 'scheduled_jobs'
  )

  if job.save
    Rails.logger.info '[KlaosCatchUp] cron registered: */2 * * * *'
  else
    Rails.logger.error("[KlaosCatchUp] cron save failed: #{job.errors.inspect}")
  end
end
