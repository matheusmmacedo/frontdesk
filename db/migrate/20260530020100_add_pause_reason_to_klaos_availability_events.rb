# frozen_string_literal: true

# KLaOS — Liga eventos de availability ao motivo de pausa (O.19).
#
# Quando status=busy, evento carrega o pause_reason_id escolhido pelo
# agente. Quando status=online/offline, pause_reason_id fica NULL.
#
# FK nullable (motivo pode ser deletado depois — usa NULLify).

class AddPauseReasonToKlaosAvailabilityEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :klaos_agent_availability_events,
                  :pause_reason,
                  null: true,
                  foreign_key: { to_table: :klaos_pause_reasons, on_delete: :nullify }
  end
end
