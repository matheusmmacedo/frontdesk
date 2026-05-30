# frozen_string_literal: true

# KLaOS — Tempo limite por motivo de pausa (O.19 controle).
#
# Cada motivo pode ter uma duração máxima esperada (minutos). Painel de
# Agentes marca "overtime" quando agente passa do limite. Default NULL
# (sem limite). Ex.: Banheiro=10min, Almoço=60min, Reunião=NULL.

class AddMaxMinutesToKlaosPauseReasons < ActiveRecord::Migration[7.1]
  def change
    add_column :klaos_pause_reasons, :max_minutes, :integer
  end
end
