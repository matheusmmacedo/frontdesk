# frozen_string_literal: true

# MESSAGE PUSH EVENT GUARD
# Protect against the upstream crash:
#
#   ActionView::Template::Error (no implicit conversion of Hash into String):
#   app/models/message.rb:147:in 'Message#push_event_data'
#
# Observed in Mais Saúde dev when rendering conversations whose latest
# message has `content_attributes = {external_error: "..."}` (standard format
# for failed-send messages — no string-wrapping bug). Root cause in upstream
# serialization path not yet identified. This prepend catches the error,
# logs the message id / conversation / fields so we can hunt the real cause,
# and returns nil — the jbuilder `try(:push_event_data)` handles nil fine,
# so the list renders instead of 500-ing the whole endpoint.

module KlaosMessagePushEventGuard
  def push_event_data(*args)
    super
  rescue TypeError => e
    if e.message.include?('implicit conversion of Hash into String')
      Rails.logger.error(
        "[KlaosMessagePushEventGuard] caught upstream TypeError on msg=#{id} " \
        "conv=#{conversation_id} sender=#{sender_type}/#{sender_id} status=#{status} " \
        "content_attributes_class=#{content_attributes.class} " \
        "additional_attributes_class=#{additional_attributes.class} " \
        "sentiment_class=#{sentiment.class} " \
        "msg=#{e.message}"
      )
      nil
    else
      raise
    end
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosMessagePushEventGuard)

  Message.prepend(KlaosMessagePushEventGuard)
  Rails.logger.info '[KlaosMessagePushEventGuard] Initializer loaded'
end
