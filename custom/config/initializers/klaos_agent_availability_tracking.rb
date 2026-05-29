# frozen_string_literal: true

# KLaOS — Tracking de mudanças de availability do agente (O.1 Painel
# de Agentes). Plugado em AccountUser via after_commit (porque é lá
# que o `availability` vive — por-conta, não por-user global).
#
# Fluxo:
#   1) Agente muda status (online → busy, por ex)
#   2) ProfilesController → AccountUser#update!(availability: ...)
#   3) Callback after_commit detecta saved_change_to_availability
#   4) Fecha evento aberto anterior (ended_at = now)
#   5) Abre novo evento (started_at = now, status = nova)
#
# Reset diário NÃO é necessário (eventos persistem; queries clipam).
# Single point of truth: a tabela klaos_agent_availability_events.

module KlaosAgentAvailabilityTracking
  extend ActiveSupport::Concern

  included do
    after_create_commit :klaos_record_initial_availability
    after_update_commit :klaos_record_availability_change, if: :saved_change_to_availability?
  end

  private

  def klaos_record_initial_availability
    klaos_open_event!(availability)
  rescue StandardError => e
    Rails.logger.warn("[KlaosAvailability] initial record failed: #{e.message}")
  end

  def klaos_record_availability_change
    now = Time.current
    klaos_close_open_event!(now)
    klaos_open_event!(availability, at: now)
  rescue StandardError => e
    Rails.logger.warn("[KlaosAvailability] change record failed: #{e.message}")
  end

  def klaos_close_open_event!(at)
    KlaosAgentAvailabilityEvent
      .where(account_id: account_id, user_id: user_id, ended_at: nil)
      .update_all(ended_at: at, updated_at: at)
  end

  def klaos_open_event!(status, at: Time.current)
    return if status.blank?

    KlaosAgentAvailabilityEvent.create!(
      account_id: account_id,
      user_id: user_id,
      status: status,
      started_at: at
    )
  end
end

Rails.application.config.to_prepare do
  next unless defined?(AccountUser)
  next if AccountUser.include?(KlaosAgentAvailabilityTracking)

  AccountUser.include(KlaosAgentAvailabilityTracking)
  Rails.logger.info '[KlaosAgentAvailabilityTracking] included on AccountUser'
end
