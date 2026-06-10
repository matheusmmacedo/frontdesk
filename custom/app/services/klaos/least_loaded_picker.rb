# frozen_string_literal: true

# KLaOS — Picker que escolhe agente com MENOR carga de convs abertas
# entre os candidatos. Tiebreaker = menor user_id (determinístico).
#
# Substitui o `candidate_ids.sort.first` que era usado em
#   - custom/app/jobs/klaos/auto_assignment_catch_up_job.rb
#   - custom/config/initializers/auto_assignment_offline_fallback.rb
#
# Motivação (bug observado 10/06/2026): quando o catch-up varria 24 convs
# de uma agente offline em rajada, todas caíam no agente de menor ID
# (Yasmin → Ludi) porque o `sort.first` é determinístico mas ignora carga.
# Resultado: 24 convs em uma pessoa só, 0 nos outros candidatos.
#
# Agora distribui pra quem tem menos convs abertas, e quando empata,
# tiebreaker é menor ID (mantém previsibilidade — útil pra teste/log).

module Klaos
  module LeastLoadedPicker
    def self.pick(account_id:, candidate_ids:)
      ids = candidate_ids.map(&:to_i).reject(&:zero?).uniq
      return nil if ids.empty?

      counts = Conversation
               .where(account_id: account_id, assignee_id: ids, status: :open)
               .group(:assignee_id)
               .count

      # min_by retorna o primeiro item com menor valor. Comparando [count, id]
      # garante: (a) menor count vence, (b) empate → menor id.
      ids.min_by { |id| [counts[id] || 0, id] }
    end
  end
end
