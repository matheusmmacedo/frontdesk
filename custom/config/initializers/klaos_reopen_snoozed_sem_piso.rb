# frozen_string_literal: true

# (07/08/2026) Conversa adiada que venceu há mais de 3 dias ficava presa pra
# sempre.
#
# O job do upstream é:
#
#   Conversation.where(status: :snoozed)
#               .where(snoozed_until: 3.days.ago..Time.current)
#               .find_each(&:open!)
#
# O `3.days.ago` é um PISO, não um teto: quem venceu antes disso sai da janela e
# nunca mais é reaberto. Basta o worker ficar fora do ar num fim de semana, ou o
# job falhar alguns ciclos, pra conversa sumir da operação em silêncio — não
# aparece em fila nenhuma, porque `snoozed` não é `open` nem `pending`.
#
# Aqui só tiramos o piso: reabre tudo que já passou da hora. Quem tem
# `snoozed_until` nulo (o "adiar até a próxima resposta") continua de fora, que é
# o comportamento correto — esse espera o cliente, não o relógio.
#
# Medido antes de mexer: o mecanismo em si funciona. Marcamos a conv 15 da Blue
# Care como adiada com hora vencida e ela voltou pra `open` em 21 segundos.
# O defeito é só a janela.
#
# Segue o padrão do fork: nada de editar arquivo do upstream, só prepend em
# runtime, pra sobreviver a merge do Chatwoot.

Rails.application.config.to_prepare do
  module KlaosReopenSnoozedSemPiso
    # Reabre TODA conversa adiada cuja hora já passou, sem piso de 3 dias.
    def perform
      Conversation.where(status: :snoozed)
                  .where.not(snoozed_until: nil)
                  .where('snoozed_until <= ?', Time.current)
                  .find_each(batch_size: 100) do |conversation|
        conversation.open!
      rescue StandardError => e
        # Uma conversa problemática não pode impedir as outras de voltar.
        Rails.logger.error(
          "[KlaosReopenSnoozed] falhou ao reabrir conv #{conversation.id}: #{e.message}"
        )
      end
    end
  end

  Conversations::ReopenSnoozedConversationsJob.prepend(KlaosReopenSnoozedSemPiso)
end
