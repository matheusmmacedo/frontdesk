# frozen_string_literal: true

# HUMAN MESSAGE PREFIX
# Prepend um texto configurável no início de toda mensagem outgoing enviada por
# um atendente humano (sender_type == 'User'). Usado pra padronizar identificação
# ("*Atendente GUSTAVO*: ...") e manter consistência com o padrão que o bot usa.
#
# Config é **por account** em `accounts.custom_attributes.klaos_human_message_template`.
# Multi-tenant: cada account tem seu próprio template, ou nenhum (comportamento
# default do Chatwoot preservado).
#
# ── Variáveis disponíveis no template ──────────────────────────────────────────
#
#   {NAME}               — nome como salvo no user (ex: "Matheus Macedo")
#   {NAME_UPPER}         — nome em MAIÚSCULO (ex: "MATHEUS MACEDO")
#   {FIRST_NAME}         — primeiro nome (ex: "Matheus")
#   {FIRST_NAME_UPPER}   — primeiro nome MAIÚSCULO (ex: "MATHEUS")
#   {DISPLAY_NAME}       — display_name do perfil se houver, senão cai pro name
#   {DISPLAY_NAME_UPPER} — display_name MAIÚSCULO
#
# ── Exemplos de template ───────────────────────────────────────────────────────
#
#   "*Atendente {FIRST_NAME_UPPER}*: "
#     → "*Atendente MATHEUS*: Oi, tudo bem?"
#
#   "_{NAME}_\n"
#     → "_Matheus Macedo_\nOi, tudo bem?"
#
#   "*{FIRST_NAME}* (Mais Saúde): "
#     → "*Matheus* (Mais Saúde): Oi, tudo bem?"
#
# ── Comportamento ──────────────────────────────────────────────────────────────
#
#   • Só aplica em `sender_type == 'User'` + outgoing + não-privada
#   • Não toca em mensagens do bot (sender_type == 'AgentBot')
#   • Não toca em notas privadas
#   • Idempotente: se content já começa com o prefix, não duplica
#   • Se template estiver vazio/null → comportamento default do Chatwoot (sem prefix)
#
# ── Config via SQL (até UI estar pronta) ───────────────────────────────────────
#
#   UPDATE accounts
#   SET custom_attributes = COALESCE(custom_attributes, '{}'::jsonb) ||
#     jsonb_build_object('klaos_human_message_template', '*Atendente {FIRST_NAME_UPPER}*: ')
#   WHERE id = 10;  -- Mais Saúde dev
#
#   Pra desativar: SET custom_attributes = custom_attributes - 'klaos_human_message_template'
#

module KlaosHumanMessagePrefix
  AVAILABLE_VARIABLES = {
    '{NAME}' => 'Nome completo como salvo no perfil',
    '{NAME_UPPER}' => 'Nome completo em MAIÚSCULO',
    '{FIRST_NAME}' => 'Primeiro nome',
    '{FIRST_NAME_UPPER}' => 'Primeiro nome em MAIÚSCULO',
    '{DISPLAY_NAME}' => 'display_name do perfil (cai pro name se vazio)',
    '{DISPLAY_NAME_UPPER}' => 'display_name em MAIÚSCULO'
  }.freeze

  EXAMPLES = [
    { template: '*Atendente {FIRST_NAME_UPPER}*: ', preview: '*Atendente MATHEUS*: Oi, tudo bem?' },
    { template: '*{NAME}*: ', preview: '*Matheus Macedo*: Oi, tudo bem?' },
    { template: '_{FIRST_NAME}_ (Mais Saúde): ', preview: '_Matheus_ (Mais Saúde): Oi, tudo bem?' }
  ].freeze

  module_function

  # Expande variáveis do template com dados do user. Retorna string pronta pra prepend.
  # Se template/user forem nil/blank, retorna '' (chamador deve tratar como "sem prefix").
  def render(template, user)
    return '' if template.blank? || user.blank?

    name = user.name.to_s
    first = name.split(/\s+/).first.to_s
    display = (user.respond_to?(:display_name) ? user.display_name.presence : nil) || name

    template
      .gsub('{NAME_UPPER}', name.upcase)
      .gsub('{NAME}', name)
      .gsub('{FIRST_NAME_UPPER}', first.upcase)
      .gsub('{FIRST_NAME}', first)
      .gsub('{DISPLAY_NAME_UPPER}', display.upcase)
      .gsub('{DISPLAY_NAME}', display)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.method_defined?(:klaos_apply_human_prefix)

  Message.class_eval do
    before_create :klaos_apply_human_prefix

    define_method :klaos_apply_human_prefix do
      return unless sender_type == 'User'
      return if private
      return unless outgoing?
      return if content.blank?

      template = conversation&.account&.custom_attributes&.[]('klaos_human_message_template')
      return if template.blank?

      prefix = KlaosHumanMessagePrefix.render(template, sender)
      return if prefix.blank?
      return if content.start_with?(prefix.rstrip)

      self.content = "#{prefix}#{content}"
    rescue StandardError => e
      Rails.logger.error("[KlaosHumanMessagePrefix] error on message: #{e.class}: #{e.message}")
      # Não propaga — msg segue sem prefix mas não quebra o envio
    end
  end

  Rails.logger.info '[KlaosHumanMessagePrefix] Initializer loaded on Message model'
end
