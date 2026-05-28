# frozen_string_literal: true

# KLaOS — remove o limite inferior de 3 dias no job de reabrir conversas
# adiadas (snoozed).
#
# Upstream em app/jobs/conversations/reopen_snoozed_conversations_job.rb:
#
#   Conversation.where(status: :snoozed)
#     .where(snoozed_until: 3.days.ago..Time.current)
#     .all.find_each(batch_size: 100, &:open!)
#
# O `3.days.ago..Time.current` é uma **janela**, não uma lista — se o
# Sidekiq cron falhar por > 3 dias OU se uma conversa ficar snoozed por
# mais de 3 dias sem o job rodar, ela nunca mais volta. Sintoma reportado
# pelo Gustavo: "a conversa não volta".
#
# Aqui sobrescrevemos pra usar apenas o teto (Time.current), removendo o
# limite inferior — qualquer conv com snoozed_until <= agora reabre na
# próxima execução do job.
module KlaosSnoozeNoLimit
  def perform
    Conversation
      .where(status: :snoozed)
      .where('snoozed_until <= ?', Time.current)
      .find_each(batch_size: 100, &:open!)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversations::ReopenSnoozedConversationsJob)
  next if Conversations::ReopenSnoozedConversationsJob.include?(KlaosSnoozeNoLimit)

  Conversations::ReopenSnoozedConversationsJob.prepend(KlaosSnoozeNoLimit)
  Rails.logger.info '[KlaosSnoozeNoLimit] prepended on Conversations::ReopenSnoozedConversationsJob'
end
