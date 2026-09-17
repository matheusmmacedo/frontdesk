# frozen_string_literal: true

# ENCERRAR AGORA E REABRIR COMIGO NA DATA MARCADA
#
# Gustavo (Mais Saude), 16/09/2026: "A reabertura do contato com data e hora
# prevista depois de encerrar a conversa" nunca funcionou.
#
# O QUE ACONTECIA
#
# Ele adia a conversa (DD/MM HH:MM) e, de 4 a 50 segundos depois, clica
# "Devolver ao bot" ou "Resolver". O upstream apaga o `snoozed_until` sempre
# que o status deixa de ser `snoozed` (conversation.rb, ensure_snooze_until_reset),
# e o job que reabre adiadas so procura `snoozed`. Conta 9, 30 dias: 5
# adiamentos, os 5 desfeitos assim, nenhum voltou. O produto nao tinha
# "encerrar agora e reabrir em DD/MM".
#
# A REGRA
#
# Quando uma PESSOA tira do adiamento uma conversa cuja hora ainda nao chegou,
# levando-a para `resolved` ou `pending`, a hora fica guardada:
#
#   additional_attributes['klaos_reabrir_em']   = snoozed_until anterior (ISO8601 UTC)
#   additional_attributes['klaos_reabrir_para'] = dono antes da mudanca
#                                                 (ou quem mudou, se nao havia dono)
#
# O job de adiadas (klaos_snooze_no_limit.rb) reabre essas conversas `open`,
# com o dono, na hora marcada, e apaga as duas chaves.
#
# As chaves saem sozinhas quando a conversa volta a `open` ou `snoozed` antes
# da hora (cliente escreveu, alguem reabriu, novo adiamento): a volta ja
# aconteceu ou foi remarcada, e uma chave velha reabriria a conversa depois de
# um proximo "resolver".
#
# Fica de fora: requisicao por api_access_token (KLaOS/integracoes), jobs sem
# `Current.user` e adiamento ja vencido.
#
# Sempre MERGE em additional_attributes: outras chaves nossas vivem ali
# (klaos_last_resolution, klaos_returned_from_snooze_at, ...).
#
# Desligavel por conta: accounts.settings['klaos_reabrir_em_data_marcada'] = false.

module KlaosReabrirEmDataMarcada
  extend ActiveSupport::Concern

  CHAVE_EM = 'klaos_reabrir_em'
  CHAVE_PARA = 'klaos_reabrir_para'
  CHAVES = [CHAVE_EM, CHAVE_PARA].freeze

  included do
    before_save :klaos_reabrir_em_data_marcada
  end

  def self.ativo?(account)
    (account&.settings || {})['klaos_reabrir_em_data_marcada'] != false
  end

  # Membro da inbox continua podendo ser dono? Usado pelo job na hora de voltar.
  def self.dono_valido(conversation, user_id)
    return nil if user_id.blank?

    id = user_id.to_i
    return nil unless conversation.inbox.inbox_members.exists?(user_id: id)
    return nil unless conversation.account.account_users.exists?(user_id: id)

    id
  end

  private

  def klaos_reabrir_em_data_marcada
    return unless status_changed?

    if open? || snoozed?
      klaos_limpar_reabertura_marcada
    elsif resolved? || pending?
      klaos_guardar_reabertura_marcada
    end
  rescue StandardError => e
    # Nunca impedir o save por causa disto.
    Rails.logger.warn("[KlaosReabrirEmDataMarcada] conv=#{id}: #{e.class}: #{e.message}")
  end

  def klaos_limpar_reabertura_marcada
    extras = additional_attributes.is_a?(Hash) ? additional_attributes : {}
    return unless CHAVES.any? { |chave| extras.key?(chave) }

    self.additional_attributes = extras.except(*CHAVES)
  end

  def klaos_guardar_reabertura_marcada
    return unless status_was.to_s == 'snoozed'

    marcada = snoozed_until_was
    return if marcada.blank? || marcada <= Time.current
    return unless Current.user.is_a?(User)
    return if KlaosOrigemDaRequisicao.via_token
    return unless KlaosReabrirEmDataMarcada.ativo?(account)

    dono = assignee_id_was.presence || assignee_id.presence || Current.user.id
    extras = additional_attributes.is_a?(Hash) ? additional_attributes : {}
    self.additional_attributes = extras.merge(
      CHAVE_EM => marcada.utc.iso8601,
      CHAVE_PARA => dono
    )
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.include?(KlaosReabrirEmDataMarcada)

  Conversation.include(KlaosReabrirEmDataMarcada)
  Rails.logger.info '[KlaosReabrirEmDataMarcada] included on Conversation'
end
