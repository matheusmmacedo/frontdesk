# frozen_string_literal: true

# AUTO-ANCHOR AGENT_BOT NA CRIAÇÃO DA CONVERSA
#
# Por que existe: Chatwoot upstream NÃO escreve `assignee_agent_bot_id` na
# conversa quando ela é criada num inbox com agent_bot configurado. O bot
# nativo é roteado via `agent_bot_listener.message_created` (webhook), mas
# a coluna `assignee_agent_bot_id` continua null.
#
# Pra arquitetura KLaOS isso é fatal: o Chatwoot Gate consulta o snapshot
# (via /api/custom/v1/.../gate_snapshot) e vê `agent_bot_id: null` em
# conversas recém-criadas. Como o gate decide "fonte de verdade = Chatwoot",
# null = bot mudo (fail-closed). Resultado prático: cliente novo manda
# "Bom dia" e ninguém responde até alguém clicar "Devolver ao bot".
#
# Esse hook fecha o buraco: assim que a conv é criada e `inbox.agent_bot_inbox`
# existe, escreve a coluna. Snapshot passa a retornar `agent_bot_id` desde
# a primeira mensagem → gate decide `cw_bot_attached` → Lara responde.
#
# Guards (pra não pisar em fluxos legítimos de atribuição manual via API):
#   - skip se já tem assignee_agent_bot_id (idempotente)
#   - skip se assignee_id presente na criação (humano já atribuído)
#   - skip se team_id presente na criação (time já atribuído)
#
# active?: NÃO checamos o flag de active da abi — pelo mesmo motivo do
# transfer_to_bot_controller. KLaOS bypassa o listener nativo (que sim
# respeita active?), e o que importa pro gate é "tem bot configurado pra
# essa inbox?". Em dev as abi ficam status=active por default (não há UI
# de toggle pra deixar inativa sem destruir).

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.method_defined?(:klaos_auto_anchor_agent_bot)

  Conversation.class_eval do
    after_create_commit :klaos_auto_anchor_agent_bot

    def klaos_auto_anchor_agent_bot
      return if assignee_agent_bot_id.present?
      return if assignee_id.present?
      return if team_id.present?

      bot_inbox = inbox&.agent_bot_inbox
      return unless bot_inbox&.agent_bot_id

      # update_columns: já estamos em after_create_commit, broadcasts da
      # criação já saíram. Só persistir a coluna direto, sem refire de
      # callbacks. ActionCable propaga via conversation.updated event.
      update_columns(assignee_agent_bot_id: bot_inbox.agent_bot_id)

      Rails.logger.info(
        "[AutoAnchorBot] conv=#{id} display=#{display_id} inbox=#{inbox_id} " \
        "anchored bot=#{bot_inbox.agent_bot_id}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "[AutoAnchorBot] fail conv=#{id&.inspect}: #{e.class}: #{e.message}"
      )
    end
  end

  Rails.logger.info '[AutoAnchorBot] hook installed on Conversation#after_create_commit'
end
