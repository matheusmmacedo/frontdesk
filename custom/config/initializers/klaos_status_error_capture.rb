# frozen_string_literal: true

# Aplica o prepend de Whatsapp::KlaosStatusErrorCapture em
# Whatsapp::IncomingMessageBaseService — sobrescreve o update_message_with_status
# pra capturar TODOS os formatos de erro que Meta envia em webhooks de status.

Rails.application.config.to_prepare do
  next unless defined?(Whatsapp::IncomingMessageBaseService)
  next if Whatsapp::IncomingMessageBaseService.include?(Whatsapp::KlaosStatusErrorCapture)

  Whatsapp::IncomingMessageBaseService.prepend(Whatsapp::KlaosStatusErrorCapture)
  Rails.logger.info '[KlaosStatusErrorCapture] prepended on Whatsapp::IncomingMessageBaseService'
end
