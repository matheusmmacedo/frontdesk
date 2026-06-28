# frozen_string_literal: true

# KLaOS — Inclui channel_type no Inbox#webhook_data (defesa em profundidade).
#
# Upstream Chatwoot (`app/models/inbox.rb:178-183`) retorna apenas
# `{id, name}` no webhook_data. O KLaOS depende do `channel_type` no
# payload pra montar o prompt do agente IA ([CONTEXTO DE CANAL —
# WHATSAPP] vs [WEB WIDGET]). Quando o campo vem null, o agente cai num
# fallback genérico que pede nome+email+telefone — comportamento errado
# pra WhatsApp.
#
# Causa raiz primária do null em 423 convs prod foi um INSERT no KLaOS
# que esquecia `chatwoot_channel` (fix #437 commit ed2f5a8f no klaos). Esse
# decorator é DEFESA EM PROFUNDIDADE: garante que `payload.inbox.channel_type`
# chegue populado em TODOS os webhooks (account-level + bot webhook),
# inclusive em shapes onde o `EventDataPresenter` da Conversation não
# roda (ex: `webwidget_triggered` que usa `contact_inbox.webhook_data`,
# eventos `contact_*` que não carregam conversation).
#
# Sem impacto pro frontend Chatwoot — campos extras no webhook são ignorados.
# Sem impacto pra clientes Web Widget (Klaus, Alberto) — continuam recebendo
# `Channel::WebWidget` como antes; nada muda na semântica do builder do KLaOS.

module KlaosInboxWebhookData
  def webhook_data
    super.merge(channel_type: channel_type)
  end
end

Rails.application.config.to_prepare do
  # Zeitwerk: força autoload via safe_constantize antes do prepend pra
  # evitar erro silencioso quando o modelo ainda não foi carregado.
  inbox_class = 'Inbox'.safe_constantize
  next unless inbox_class
  next if inbox_class.include?(KlaosInboxWebhookData)

  inbox_class.prepend(KlaosInboxWebhookData)
  Rails.logger.info '[KlaosInboxWebhookData] prepended channel_type into Inbox#webhook_data'
end
