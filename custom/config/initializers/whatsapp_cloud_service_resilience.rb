# frozen_string_literal: true

# Aplica prepend de Whatsapp::CloudServiceResilience em
# Whatsapp::Providers::WhatsappCloudService.
#
# A lógica de retry/timeout está em
# custom/app/services/whatsapp/cloud_service_resilience.rb.

Rails.application.config.to_prepare do
  Whatsapp::CloudServiceResilience # força autoload do módulo
  Whatsapp::Providers::WhatsappCloudService.prepend(Whatsapp::CloudServiceResilience)
  Rails.logger&.info '[WhatsApp] CloudServiceResilience prepended on WhatsappCloudService'
end
