# frozen_string_literal: true

# ACTIVE STATUS FILTER
# Extends ConversationFinder to support status=active (open + pending only).
# Used by the "Ativas" filter na lista de conversas. Mostra tudo que precisa de
# atenção AGORA — NÃO inclui snoozed (adiadas).
#
# Por quê excluir snoozed:
#   Gustavo reportou: "conversa adiada não some da lista". A ideia do Adiar
#   é a conv FICAR OCULTA até a data programada, e voltar piscando com
#   alerta escandaloso (SnoozeReopenAlert) quando reabrir.
#   Antes 'active' incluía snoozed → conv adiada continuava aparecendo na
#   lista misturada com as ativas. Agora some, e só volta quando o cron
#   reabre (status muda pra open) — daí o SnoozeReopenAlert dispara.

module KlaosActiveStatusFilter
  private

  def filter_by_status
    if params[:status] == 'active'
      @conversations = @conversations.where(status: %i[open pending])
      return
    end

    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(ConversationFinder)
  next if ConversationFinder.include?(KlaosActiveStatusFilter)

  ConversationFinder.prepend(KlaosActiveStatusFilter)
end
