# frozen_string_literal: true

# Prepends `WhatsappTemplateEventsHandler` so `Webhooks::WhatsappEventsJob`
# routes `message_template_*` Meta webhook fields through the handler before
# falling through to upstream message-handling logic.
#
# **Fork-safety:**
# - The handler module lives entirely in `custom/app/jobs/`. Upstream Chatwoot
#   never touches it.
# - We `prepend` rather than reopen — upstream is free to refactor
#   `Webhooks::WhatsappEventsJob#perform` and we still wrap it.
# - We guard with `defined?` and `method_defined?` checks so a future upstream
#   rename of the job/method downgrades to a warning (boot does not fail).
# - `to_prepare` runs on each reload in development and once in production —
#   matches Rails autoloading lifecycle.
Rails.application.config.to_prepare do
  unless defined?(Webhooks::WhatsappEventsJob)
    Rails.logger.warn('[KLaOS] Webhooks::WhatsappEventsJob undefined — template events extension skipped')
    next
  end

  unless Webhooks::WhatsappEventsJob.method_defined?(:perform) ||
         Webhooks::WhatsappEventsJob.private_method_defined?(:perform)
    Rails.logger.warn('[KLaOS] Webhooks::WhatsappEventsJob#perform missing — template events extension skipped')
    next
  end

  unless defined?(WhatsappTemplateEventsHandler)
    Rails.logger.warn('[KLaOS] WhatsappTemplateEventsHandler not loaded — template events extension skipped')
    next
  end

  # Idempotent: prepend twice on reload is a no-op for Ruby.
  Webhooks::WhatsappEventsJob.prepend(WhatsappTemplateEventsHandler)
end
