# frozen_string_literal: true

# KLaOS — Sort LATEST sobe a conv SOMENTE quando o cliente manda mensagem.
#
# Problema reportado pelo Gustavo: "tô conversando com cliente X na 50ª
# posição, mexo na etiqueta ou respondo a mensagem, e a conv sobe pra
# 1ª posição — perco o contexto da lista". Comportamento esperado
# (paridade Kualiz): a atendente deve poder responder, etiquetar e
# transferir sem perder posição.
#
# Causa: `Message#set_conversation_activity` (after_create no Chatwoot
# upstream) atualiza `conversation.last_activity_at` pra QUALQUER tipo
# de mensagem — incoming, outgoing, activity e template.
#
# Solução KLaOS: pular update de last_activity_at para TUDO menos
# `incoming` (mensagem real do cliente). Só msg do cliente sobe a conv.
#
# Tipos que NÃO sobem:
#   - outgoing (resposta do agente)             — mantém posição
#   - template (template WhatsApp enviado pelo agente)
#   - activity (label changed, assignee, status, snooze, ...)
#   - private (qualquer notas privadas internas)
#
# Tipos que SOBEM:
#   - incoming não-privada (cliente mandou msg real)
#
# Efeito colateral consciente: auto_resolve_after vai contar a partir da
# última mensagem DO CLIENTE — uma conv parada (cliente não respondeu)
# pode ser auto-resolvida no prazo normal mesmo se a equipe interagiu
# internamente. Isso É o comportamento desejado.
#
# Multi-tenant nato.

module KlaosSortIgnoreActivities
  def set_conversation_activity
    return unless message_type == 'incoming'
    return if private?

    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosSortIgnoreActivities)

  Message.prepend(KlaosSortIgnoreActivities)
  Rails.logger.info '[KlaosSortIgnoreActivities] prepended on Message'
end
