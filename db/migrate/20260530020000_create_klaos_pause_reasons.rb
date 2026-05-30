# frozen_string_literal: true

# KLaOS — Motivos de pausa configuráveis por conta (O.19 Pausas Tipadas).
#
# Quando agente clica em "Pausa" no Painel Lateral (O.8), abre modal pra
# escolher MOTIVO (Almoço, Banheiro, Reunião, ...). Esse modelo guarda
# os motivos disponíveis por conta — admin pode customizar via Settings.
#
# Seeder default (Almoço, Banheiro, Reunião, Café, Outro) é executado
# automaticamente no boot pra contas que não têm nenhum motivo.

class CreateKlaosPauseReasons < ActiveRecord::Migration[7.1]
  def change
    create_table :klaos_pause_reasons do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      # Emoji ou char unicode pequeno (default "🟡")
      t.string :icon, default: '🟡', null: false
      t.integer :sort_order, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :klaos_pause_reasons, %i[account_id sort_order],
              name: 'idx_klaos_pause_reasons_account_order'
  end
end
