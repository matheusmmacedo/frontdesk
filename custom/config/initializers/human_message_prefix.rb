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
#   • Aplica em `sender_type == 'User'` (humano) E `'AgentBot'` (bot), outgoing + não-privada
#   • Pro bot, o template usa o nome do bot (ex: "**Atendente LARA:**")
#   • Não toca em notas privadas
#   • Idempotente: se content já começa com o prefix, não duplica
#     (cobre o caso do KLaOS já ter prefixado a mensagem do bot)
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
# ── Opt-out por BOT (klaos_prefix_skip_agent_bot_ids) ──────────────────────────
#
#   Mesma ideia do opt-out por mensagem (content_attributes['skip_klaos_prefix']),
#   só que persistente e por account: os `agent_bots.id` listados aqui NÃO recebem
#   prefixo, e todo o resto da conta (humanos e os outros bots) continua recebendo.
#
#   Caso de uso: a Sofia (agendamento) já se identifica sozinha no próprio texto,
#   então a assinatura do canal ficava em duplicidade. Lara e ANA (cobrança)
#   dependem da assinatura e ficam de fora da lista.
#
#   UPDATE accounts
#   SET custom_attributes = COALESCE(custom_attributes, '{}'::jsonb) ||
#     jsonb_build_object('klaos_prefix_skip_agent_bot_ids', '[15]'::jsonb)
#   WHERE id = 10;  -- Mais Saúde dev; 15 = Sofia
#
#   Pra reverter: SET custom_attributes = custom_attributes - 'klaos_prefix_skip_agent_bot_ids'
#

module KlaosHumanMessagePrefix
  # Chave em accounts.custom_attributes com os agent_bots.id que NÃO recebem prefixo.
  SKIP_BOT_IDS_KEY = 'klaos_prefix_skip_agent_bot_ids'

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
      template: "**Atendente {FIRST_NAME_UPPER}:**\n",
      preview: "**Atendente MATHEUS:**\nOi, tudo bem?",
      note: 'Recomendado — negrito (** = markdown bold, vira **bold** no WhatsApp) + quebra de linha'
    },
    {
      template: "**{NAME}:** ",
      preview: '**Matheus Macedo:** Oi, tudo bem?',
      note: 'Inline, mesmo linha, em negrito. Use ** (duplo asterisco) — Chatwoot converte pro formato WhatsApp.'
    },
    {
      template: "_{FIRST_NAME}_ (Mais Saúde):\n",
      preview: "_Matheus_ (Mais Saúde):\nOi, tudo bem?",
      note: 'Itálico no nome (_) + nome da empresa entre parênteses + quebra de linha'
    }
  ].freeze

  module_function

  # Expande variáveis do template com dados do user. Retorna string pronta pra prepend.
  # Se template/user forem nil/blank, retorna '' (chamador deve tratar como "sem prefix").
  def render(template, user)
    return '' if template.blank? || user.blank?

    name = klaos_clean_name(user.name.to_s)
    first = name.split(/\s+/).first.to_s
    raw_display = (user.respond_to?(:display_name) ? user.display_name.presence : nil) || name
    display = klaos_clean_name(raw_display)

    template
      .gsub('{NAME_UPPER}', name.upcase)
      .gsub('{NAME}', name)
      .gsub('{FIRST_NAME_UPPER}', first.upcase)
      .gsub('{FIRST_NAME}', first)
      .gsub('{DISPLAY_NAME_UPPER}', display.upcase)
      .gsub('{DISPLAY_NAME}', display)
  end

  # O KLaOS registra bots no Chatwoot como "Display | slug"
  # (ex: "Lara | lara", "Qualificador de Leads | qualificador-de-leads"). O slug
  # é interno — tira ele pra assinatura sair limpa em QUALQUER variável
  # ({NAME}, {NAME_UPPER}, {FIRST_NAME}...), não só por sorte com {FIRST_NAME}.
  # Humanos (User) não têm " | " no nome → no-op. Idempotente e seguro.
  def klaos_clean_name(raw)
    str = raw.to_s
    return str unless str.include?(' | ')

    str.split(' | ').first.to_s.strip
  end

  # Normaliza a config bruta do jsonb numa lista de ids em String.
  # Aceita array ([15, "98"]), id solto (15 ou "15") e string com vírgula
  # ("15, 98"), porque essa chave é gravada à mão por SQL e nem sempre chega
  # como array. Qualquer outra coisa (nil, hash, lixo) vira lista vazia — a
  # config ausente/inválida NÃO pode mudar o comportamento de quem já funciona.
  def skip_bot_ids(raw)
    list = case raw
           when Array then raw
           when String then raw.split(',')
           when Integer then [raw]
           else []
           end

    list.map { |id| id.to_s.strip }.reject(&:empty?)
  end

  # true só pra AgentBot cujo id está na lista. Humano (User) nunca é afetado:
  # a lista é de agent_bots.id e um user.id igual não pode desligar a assinatura
  # do atendente por coincidência de número.
  def skip_bot?(raw, sender_type, sender_id)
    return false unless sender_type.to_s == 'AgentBot'

    skip_bot_ids(raw).include?(sender_id.to_s)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.method_defined?(:klaos_apply_human_prefix)

  Message.class_eval do
    before_create :klaos_apply_human_prefix

    define_method :klaos_apply_human_prefix do
      tag = "[KlaosHumanMessagePrefix] conv=#{conversation_id} sender=#{sender_type}/#{sender_id} mt=#{message_type.inspect} priv=#{private}"

      # Aplica em humanos (User) E bots (AgentBot). Pro bot, o template renderiza
      # o nome do bot (ex: "**Atendente LARA:**"). O KLaOS já prefixa ALGUMAS
      # mensagens do bot — o check idempotente abaixo evita duplicar; as que vêm
      # sem prefixo ganham aqui, deixando o bot SEMPRE assinado.
      unless %w[User AgentBot].include?(sender_type)
        Rails.logger.debug("#{tag} skip: sender_type=#{sender_type} (nem User nem AgentBot)")
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

      account_attrs = conversation&.account&.custom_attributes
      template = account_attrs&.[]('klaos_human_message_template')
      if template.blank?
        Rails.logger.info("#{tag} skip: no template configured (acc_id=#{conversation&.account_id})")
        return
      end

      # Per-message opt-out — frontend (composer toggle) marca content_attributes['skip_klaos_prefix']=true
      # quando o atendente quer enviar SEM a assinatura. Permite envio "raw" pontual sem mudar a config da account.
      if content_attributes.is_a?(Hash) && content_attributes['skip_klaos_prefix']
        Rails.logger.info("#{tag} skip: content_attributes.skip_klaos_prefix=true (per-message opt-out)")
        return
      end

      # Opt-out por BOT — mesma ideia do de cima, só que persistente e por account.
      # Só desliga o prefixo do agent_bot cujo id está em
      # custom_attributes['klaos_prefix_skip_agent_bot_ids']; humano e os demais
      # bots da mesma conta seguem assinados.
      skip_ids_raw = account_attrs&.[](KlaosHumanMessagePrefix::SKIP_BOT_IDS_KEY)
      if KlaosHumanMessagePrefix.skip_bot?(skip_ids_raw, sender_type, sender_id)
        Rails.logger.info("#{tag} skip: agent_bot #{sender_id} listado em #{KlaosHumanMessagePrefix::SKIP_BOT_IDS_KEY}=#{skip_ids_raw.inspect}")
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
