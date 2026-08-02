# frozen_string_literal: true

# TRACK RESOLVED TIMESTAMP
# Grava klaos_resolved_at em conversation.additional_attributes quando conversa
# é resolvida. Remove quando volta pra pending (via transfer_to_bot ou reabertura).
# Consumido pela política de reabertura do KLaOS (ver docs/para-klaos-agent/SDD_REOPEN_POLICY.md).
#
# ADITIVO (PASSO 1 / N1 do sticky reopen): além das 3 chaves acima — que são
# EFÊMERAS por desenho, porque o ramo 'pending' apaga klaos_resolved_at e o
# upstream (app/models/message.rb:397 reopen_resolved_conversation) empurra a
# conversa pra 'pending' ANTES de qualquer lógica nossa rodar — grava também
# klaos_last_resolution: um bloco único {resolved_at, assignee_id, team_id,
# inbox_id} que NUNCA é removido. É a memória estável de "quem era o dono"
# no instante exato em que o cliente volta a escrever.
#
# NÃO mexer nas 3 chaves antigas: custom/app/controllers/api/custom/v1/accounts/
# contact_timeline_controller.rb:100-103 lê klaos_resolved_at e a timeline do
# contato quebra calada se a semântica mudar.

Rails.application.config.to_prepare do
  if defined?(Conversation) && !Conversation.method_defined?(:klaos_track_resolved_timestamp)
    Conversation.class_eval do
      after_update_commit :klaos_track_resolved_timestamp

      def klaos_track_resolved_timestamp
        return unless saved_change_to_status?

        extras = additional_attributes || {}

        case status
        when 'resolved'
          resolved_at = Time.current.iso8601

          extras = extras.merge(
            'klaos_resolved_at' => resolved_at,
            'klaos_last_assignee_id' => assignee_id,
            'klaos_last_team_id' => team_id,
            # Snapshot estável — mesmo instante das chaves acima, um relógio só.
            'klaos_last_resolution' => {
              'resolved_at' => resolved_at,
              'assignee_id' => assignee_id,
              'team_id' => team_id,
              'inbox_id' => inbox_id
            }
          )
          update_column(:additional_attributes, extras)
        when 'pending'
          # Devolvido pro bot — limpa marcadores
          # ATENÇÃO: klaos_last_resolution NÃO entra neste except. É justamente
          # ele que precisa sobreviver ao retorno do cliente.
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
