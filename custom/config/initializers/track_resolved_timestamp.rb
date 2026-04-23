# frozen_string_literal: true

# TRACK RESOLVED TIMESTAMP
# Grava klaos_resolved_at em conversation.additional_attributes quando conversa
# é resolvida. Remove quando volta pra pending (via transfer_to_bot ou reabertura).
# Consumido pela política de reabertura do KLaOS (ver docs/para-klaos-agent/SDD_REOPEN_POLICY.md).

Rails.application.config.to_prepare do
  if defined?(Conversation) && !Conversation.method_defined?(:klaos_track_resolved_timestamp)
    Conversation.class_eval do
      after_update_commit :klaos_track_resolved_timestamp

      def klaos_track_resolved_timestamp
        return unless saved_change_to_status?

        extras = additional_attributes || {}

        case status
        when 'resolved'
          extras = extras.merge(
            'klaos_resolved_at' => Time.current.iso8601,
            'klaos_last_assignee_id' => assignee_id,
            'klaos_last_team_id' => team_id
          )
          update_column(:additional_attributes, extras)
        when 'pending'
          # Devolvido pro bot — limpa marcadores
          extras = extras.except('klaos_resolved_at')
          update_column(:additional_attributes, extras)
        end
      rescue StandardError => e
        Rails.logger.error("[TrackResolved] error conv=#{id}: #{e.class}: #{e.message}")
      end
    end

    Rails.logger.info '[TrackResolved] Initializer loaded on Conversation model'
  end
end
