# frozen_string_literal: true

# ACTIVE STATUS FILTER
# Extends ConversationFinder to support status=active (open + pending + snoozed).
# Used by the "Ativas" filter in the conversation list — shows everything except resolved.

Rails.application.config.to_prepare do
  next unless defined?(ConversationFinder)

  ConversationFinder.class_eval do
    unless method_defined?(:filter_by_status_without_active)
      alias_method :filter_by_status_without_active, :filter_by_status

      def filter_by_status
        if params[:status] == 'active'
          @conversations = @conversations.where(status: %i[open pending snoozed])
          return
        end

        filter_by_status_without_active
      end
    end
  end
end
