# frozen_string_literal: true

# KLaOS — Motivo de pausa configurável (O.19 Pausas Tipadas).
#
# Cada conta tem sua lista de motivos (Almoço, Banheiro, Reunião, ...).
# Admin pode customizar via Settings > Motivos de Pausa.
#
# Seeder default popula uma conta nova com 5 motivos padrão (ver
# klaos_pause_reasons_seeder.rb initializer).

class KlaosPauseReason < ApplicationRecord
  self.table_name = 'klaos_pause_reasons'

  belongs_to :account
  has_many :klaos_agent_availability_events,
           foreign_key: :pause_reason_id,
           dependent: :nullify

  validates :name, presence: true, length: { maximum: 50 }
  validates :icon, length: { maximum: 10 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }

  DEFAULTS = [
    { name: 'Almoço',   icon: '🍽️', sort_order: 10 },
    { name: 'Banheiro', icon: '🚻', sort_order: 20 },
    { name: 'Reunião',  icon: '👥', sort_order: 30 },
    { name: 'Café',     icon: '☕', sort_order: 40 },
    { name: 'Outro',    icon: '🟡', sort_order: 99 }
  ].freeze
end
