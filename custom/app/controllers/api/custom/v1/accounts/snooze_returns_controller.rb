# frozen_string_literal: true

# KLaOS — convs que voltaram do adiamento desde a última visita do agente.
#
# Problema: o `SnoozeReopenAlert` (frontend) só dispara enquanto o agente
# está com o navegador aberto. Quando o cron `KlaosSnoozeNoLimit` reabre
# a conv durante a madrugada ou enquanto o agente está offline, ele perde
# o aviso e a conv aparece "do nada" na lista. Reportado pelo Gustavo
# (15/06/2026): "some e aparece, porra".
#
# Solução: persistir no `conversations.additional_attributes` o timestamp
# de quando a conv voltou do snooze (gravado no
# klaos_snooze_no_limit.rb). A Central do agente consulta este endpoint
# no mount mostrando as convs que voltaram DESDE A ÚLTIMA VEZ que o user
# clicou em "ciente" — armazenado em `users.ui_settings`.
#
# Endpoints:
#   GET  /api/custom/v1/accounts/:account_id/snooze_returns
#        → lista convs com klaos_returned_from_snooze_at > last_seen_at,
#          filtrado por assignee_id = current_user
#   POST /api/custom/v1/accounts/:account_id/snooze_returns/dismiss
#        → atualiza ui_settings['klaos_snooze_returns_seen_at'] = now
#
# Auth: header `api_access_token` (mesma da API V1).

class Api::Custom::V1::Accounts::SnoozeReturnsController < Api::V1::Accounts::BaseController
  def index
    last_seen_at = klaos_last_seen_at

    convs = Current.account.conversations
                   .where(assignee_id: Current.user.id)
                   .where(status: :open)
                   .where("additional_attributes->>'klaos_returned_from_snooze_at' IS NOT NULL")
                   .where("(additional_attributes->>'klaos_returned_from_snooze_at')::timestamptz > ?", last_seen_at)
                   .order(Arel.sql("(additional_attributes->>'klaos_returned_from_snooze_at')::timestamptz DESC"))
                   .limit(50)

    render json: {
      last_seen_at: last_seen_at.iso8601,
      count: convs.count,
      items: convs.map { |c| klaos_serialize(c) }
    }, status: :ok
  end

  def dismiss
    user = Current.user
    settings = user.ui_settings || {}
    settings = settings.merge('klaos_snooze_returns_seen_at' => Time.current.iso8601)
    user.update!(ui_settings: settings)
    render json: { last_seen_at: settings['klaos_snooze_returns_seen_at'] }, status: :ok
  end

  private

  def klaos_last_seen_at
    raw = Current.user.ui_settings&.dig('klaos_snooze_returns_seen_at')
    return 7.days.ago if raw.blank?

    Time.zone.parse(raw)
  rescue StandardError
    7.days.ago
  end

  def klaos_serialize(conv)
    {
      conversation_id: conv.id,
      display_id: conv.display_id,
      contact_name: conv.contact&.name,
      contact_phone: conv.contact&.phone_number,
      returned_at: conv.additional_attributes['klaos_returned_from_snooze_at'],
      inbox_name: conv.inbox&.name,
      last_activity_at: conv.last_activity_at&.iso8601
    }
  end
end
