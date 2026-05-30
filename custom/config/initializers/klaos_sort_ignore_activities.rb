# frozen_string_literal: true

# KLaOS — Sort LATEST ignora mensagens "activity".
#
# Problema: agente arruma uma etiqueta numa conversa antiga e ela "sobe"
# pro topo da lista de conversas (sort=latest). Isso polui a ordem com
# conversas que NÃO tiveram interação real do cliente nem resposta do
# agente — só auditoria interna.
#
# Causa: `Message#set_conversation_activity` (chamado em after_create no
# Chatwoot upstream) atualiza `conversation.last_activity_at` pra QUALQUER
# tipo de mensagem, incluindo:
#   - activity (label changed, assignee changed, status changed, snooze, ...)
#   - notas privadas (private = true)
#
# Solução KLaOS: prepend `set_conversation_activity` pra pular a atualização
# se a mensagem é activity OU é privada. Mensagem real do cliente
# (incoming) ou resposta do agente (outgoing não-privada) continuam
# subindo a conv normalmente. Sort LATEST reflete interação real.
#
# Efeito colateral consciente: auto_resolve_after vai contar a partir da
# última mensagem REAL — uma conv com só atividades internas recentes
# pode ser auto-resolvida. Isso é o comportamento DESEJADO (conv parada
# do cliente = abandonada, atividade interna não muda isso).
#
# Multi-tenant nato.

module KlaosSortIgnoreActivities
  def set_conversation_activity
    return if message_type == 'activity'
    return if private? && %w[outgoing template].include?(message_type)

    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosSortIgnoreActivities)

  Message.prepend(KlaosSortIgnoreActivities)
  Rails.logger.info '[KlaosSortIgnoreActivities] prepended on Message'
end
