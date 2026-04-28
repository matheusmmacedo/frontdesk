# frozen_string_literal: true

# ACTIVE STATUS FILTER
# Extends ConversationFinder to support status=active (open + pending + snoozed).
# Used by the "Ativas" filter in the conversation list — shows everything except resolved.

module KlaosActiveStatusFilter
  private

  def filter_by_status
    if params[:status] == 'active'
      @conversations = @conversations.where(status: %i[open pending snoozed])
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
