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
    {
      template: "*Atendente {FIRST_NAME_UPPER}:*\n",
      preview: "*Atendente MATHEUS:*\nOi, tudo bem?",
      note: 'Recomendado pra WhatsApp — negrito limpo + quebra de linha após o nome'
    },
    {
      template: "*{NAME}*: ",
      preview: '*Matheus Macedo*: Oi, tudo bem?',
      note: 'Inline, mesmo linha. Negrito pode falhar em alguns clientes WhatsApp.'
    },
    {
      template: "_{FIRST_NAME}_ (Mais Saúde):\n",
      preview: "_Matheus_ (Mais Saúde):\nOi, tudo bem?",
      note: 'Itálico no nome + identificador da empresa'
    }
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
      tag = "[KlaosHumanMessagePrefix] conv=#{conversation_id} sender=#{sender_type}/#{sender_id} mt=#{message_type.inspect} priv=#{private}"

      unless sender_type == 'User'
        Rails.logger.debug("#{tag} skip: not User")
        return
      end
      if private
        Rails.logger.debug("#{tag} skip: private")
        return
      end
      # message_type pode ser string 'outgoing' ou integer 1 em before_create
      mt_val = message_type.is_a?(Integer) ? message_type : self.class.message_types[message_type.to_s]
      unless mt_val == 1
        Rails.logger.debug("#{tag} skip: not outgoing (mt_val=#{mt_val.inspect})")
        return
      end
      if content.blank?
        Rails.logger.debug("#{tag} skip: blank content")
        return
      end

      template = conversation&.account&.custom_attributes&.[]('klaos_human_message_template')
      if template.blank?
        Rails.logger.info("#{tag} skip: no template configured (acc_id=#{conversation&.account_id})")
        return
      end

      prefix = KlaosHumanMessagePrefix.render(template, sender)
      if prefix.blank?
        Rails.logger.warn("#{tag} skip: empty prefix rendered (template=#{template.inspect})")
        return
      end
      if content.start_with?(prefix.rstrip)
        Rails.logger.info("#{tag} skip: content already starts with prefix")
        return
      end

      Rails.logger.info("#{tag} applying prefix=#{prefix.inspect}")
      self.content = "#{prefix}#{content}"
    rescue StandardError => e
      Rails.logger.error("[KlaosHumanMessagePrefix] error on message: #{e.class}: #{e.message}")
      # Não propaga — msg segue sem prefix mas não quebra o envio
    end
  end

  Rails.logger.info '[KlaosHumanMessagePrefix] Initializer loaded on Message model'
end
