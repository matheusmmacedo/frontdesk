# frozen_string_literal: true

# KLaOS — Single asterisk = negrito no WhatsApp (Item 6 do Gustavo).
#
# Problema: agentes escrevem `*texto*` esperando NEGRITO (porque é assim que
# WhatsApp interpreta nativamente — quando o CLIENTE final lê no WhatsApp,
# `*texto*` aparece em negrito). Upstream usa markdown CommonMark padrão:
# `*` único = ITÁLICO (emph), `**` = NEGRITO (strong). Daí quando o agente
# digita `*atenção*`, Frontdesk converte pra `_atenção_` antes de mandar, e
# o WhatsApp mostra em itálico — contra a expectativa.
#
# Fix: override do `emph` no WhatsAppRenderer pra emitir `*..*` (negrito)
# em vez de `_.._` (itálico). `strong` continua igual (`**bold**` markdown
# também vira `*bold*`). Resultado: ambos `*texto*` e `**texto**` viram
# negrito no WhatsApp — exatamente o que o cliente final vê quando digita
# direto no WhatsApp dele.
#
# Trade-off: itálico via markdown fica inacessível. Quem quiser itálico
# pode digitar `_texto_` literal (WhatsApp interpreta nativamente, e nosso
# renderer não toca underline).
#
# Multi-tenant nato — vale pra qualquer inbox WhatsApp automaticamente.

module KlaosWhatsAppSingleAsteriskBold
  def emph(_node)
    out('*', :children, '*')
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Messages::MarkdownRenderers::WhatsAppRenderer)
  next if Messages::MarkdownRenderers::WhatsAppRenderer.include?(KlaosWhatsAppSingleAsteriskBold)

  Messages::MarkdownRenderers::WhatsAppRenderer.prepend(KlaosWhatsAppSingleAsteriskBold)
  Rails.logger.info '[KlaosWhatsAppSingleAsteriskBold] prepended on WhatsAppRenderer'
end
