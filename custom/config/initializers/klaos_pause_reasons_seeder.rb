# frozen_string_literal: true

# KLaOS — Seeder dos motivos de pausa default (O.19).
#
# Roda lazy quando a conta acessar a feature pela primeira vez (via
# request HTTP). Cria os 5 motivos padrão se a conta não tiver nenhum.
#
# Por que não no migration: migration roda uma vez no deploy mas contas
# NOVAS criadas depois precisam ter os defaults também. Solução: hook
# em Account#after_create + safety net no controller GET (cria se vazio).
#
# A lógica fica no model via método de classe.

module KlaosPauseReasonSeeding
  extend ActiveSupport::Concern

  def klaos_ensure_pause_reasons!
    return unless KlaosPauseReason.where(account_id: id).empty?

    KlaosPauseReason::DEFAULTS.each do |attrs|
      KlaosPauseReason.create!(attrs.merge(account_id: id))
    end
  rescue StandardError => e
    Rails.logger.warn("[KlaosPauseReasons] seed failed for account=#{id}: #{e.message}")
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Account)
  next if Account.include?(KlaosPauseReasonSeeding)

  Account.include(KlaosPauseReasonSeeding)
  Rails.logger.info '[KlaosPauseReasonSeeding] included on Account'
end
