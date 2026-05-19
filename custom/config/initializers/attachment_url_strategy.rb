# frozen_string_literal: true

# Aplica prepend de AttachmentUrlStrategy em Attachment.
# Detalhes em custom/lib/attachment_url_strategy.rb.

require Rails.root.join('custom/lib/attachment_url_strategy.rb')

Rails.application.config.to_prepare do
  Attachment.prepend(AttachmentUrlStrategy)
  Rails.logger&.info '[Attachment] AttachmentUrlStrategy prepended (audio/video use redirect URL)'
end
