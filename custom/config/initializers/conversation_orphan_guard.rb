# frozen_string_literal: true

# CONVERSATION ORPHAN GUARD
# Protect jbuilder rendering when an inbox referenced by a conversation was deleted
# (orphan row). Without this, `conversation.can_reply?` calls
# `MessageWindowService#messaging_window` which does `@conversation.inbox.channel_type`
# and blows up with `undefined method 'channel_type' for nil` — crashing the entire
# conversation index JSON (500).
#
# Happens when an admin deletes an inbox while conversations still exist on it.
# Chatwoot's `dependent: :destroy_async` sometimes leaves rows behind if the job failed.

module KlaosConversationOrphanGuard
  def can_reply?
    return false if inbox.nil?

    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.include?(KlaosConversationOrphanGuard)

  Conversation.prepend(KlaosConversationOrphanGuard)
end
