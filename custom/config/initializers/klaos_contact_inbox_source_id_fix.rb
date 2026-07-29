# frozen_string_literal: true

# Corrige o caminho de recuperação do ContactInboxBuilder para inbox WhatsApp Cloud.
#
# Bug upstream (Chatwoot): quando um contato NOVO herda um telefone que já está
# mapeado em `contact_inboxes(inbox_id, source_id)` — típico depois de troca de
# número ou merge de contato — o `first_or_create!` estoura RecordNotUnique
# (`app/builders/contact_inbox_builder.rb:68-73`). O rescue tenta liberar o slot
# renomeando o source_id antigo via `new_source_id` (`:94-99`):
#
#     "whatsapp:#{@source_id}#{rand(100)}"
#
# Mas `ContactInbox` valida source_id de `Channel::Whatsapp` contra
# `RegexHelper::WHATSAPP_CHANNEL_REGEX = /^\d{1,15}\z/` (`contact_inbox.rb:69-72`,
# `lib/regex_helper.rb:18`). O prefixo "whatsapp:" só é válido para TWILIO —
# em WhatsApp Cloud o `update!` levanta RecordInvalid e a request morre em 422.
#
# Sintoma em prod (29/07): Gustavo (user 12) tentou enviar template 5x em
# ~2min para a inbox 19 e recebeu 422 em todas — "seleciono o template e não
# envia". 4 contatos da conta 9 estavam nesse estado, cada um travado
# permanentemente (o caminho de recuperação NUNCA consegue completar).
#
# Fix: para Channel::Whatsapp, gerar source_id sintético que satisfaz o regex —
# 15 dígitos com prefixo 9999 (telefone BR real tem 12-13 dígitos com DDI, então
# não colide com número legítimo). Verifica unicidade antes de devolver.
# Twilio/SMS mantêm o comportamento upstream (lá o prefixo é válido).
Rails.application.config.to_prepare do
  ContactInboxBuilder.prepend(Module.new do
    private

    def new_source_id
      return super unless @inbox.channel.is_a?(Channel::Whatsapp)

      10.times do
        candidate = "9999#{SecureRandom.random_number(10**11).to_s.rjust(11, '0')}"
        next if ::ContactInbox.exists?(inbox_id: @inbox.id, source_id: candidate)

        Rails.logger.info(
          "[KlaosContactInboxFix] inbox=#{@inbox.id} source_id antigo=#{@source_id} realocado para #{candidate}"
        )
        return candidate
      end

      # 10 colisões seguidas em espaço de 10^11 é praticamente impossível;
      # se acontecer, deixa o upstream falhar em vez de mascarar.
      Rails.logger.error("[KlaosContactInboxFix] nao consegui gerar source_id livre para inbox=#{@inbox.id}")
      super
    end
  end)
end
