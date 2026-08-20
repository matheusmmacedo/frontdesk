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
  KLAOS_SNOOZE_REOPENED_EVENT = 'klaos.snooze_reopened'

  def perform
    Conversation
      .where(status: :snoozed)
      .where('snoozed_until <= ?', Time.current)
      .find_each(batch_size: 100) do |conv|
        conv.open!
        # Persiste timestamp no additional_attributes pra que a Central
        # do agente possa mostrar "Voltaram do adiamento desde sua última
        # visita" mesmo se o agente estava offline quando o broadcast
        # do snooze_reopened foi disparado.
        klaos_mark_returned_from_snooze(conv)
        klaos_registrar_volta_na_timeline(conv)
        klaos_broadcast_snooze_reopened(conv)
      end
  end

  private

  # Marca quando a conv voltou do snooze pra a Central do agente conseguir
  # mostrar lista de "voltaram desde sua última visita".
  def klaos_mark_returned_from_snooze(conversation)
    extras = conversation.additional_attributes || {}
    extras = extras.merge('klaos_returned_from_snooze_at' => Time.current.iso8601)
    conversation.update_columns(additional_attributes: extras)
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosSnoozeNoLimit] mark returned_from_snooze falhou conv=#{conversation.id}: #{e.message}"
    )
  end

  # (19/08/2026) DEIXA RASTRO NA CONVERSA.
  #
  # Quem reabre aqui é o job, não uma pessoa, e o upstream só escreve
  # atividade de mudança de status quando existe `Current.user`
  # (`activity_message_handler.rb:70-79`). Resultado: a conversa voltava do
  # adiamento e a última linha da timeline continuava sendo "Conversa foi
  # adiada por Fulano". Quem abrisse depois não tinha como saber que ela
  # voltou, nem quando.
  #
  # Mensagem de atividade é interna: aparece na timeline do atendimento e
  # nunca é entregue ao cliente.
  def klaos_registrar_volta_na_timeline(conversation)
    # As CHAVES são obrigatórias: `perform(conversation, message_params)` recebe
    # o hash como argumento POSICIONAL. Passar `account_id:, inbox_id:, ...`
    # solto vira keyword argument, que no Ruby 3 não casa com o posicional e
    # levanta ArgumentError — engolido pelo rescue abaixo, virando só um warn.
    # Foi assim que a primeira versão deste código não escreveu nada e o teste
    # em dev pegou.
    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      {
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :activity,
        content: 'Conversa reaberta automaticamente: o adiamento terminou.'
      }
    )
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosSnoozeNoLimit] activity de volta do snooze falhou conv=#{conversation.id}: #{e.message}"
    )
  end

  # Broadcasta evento custom pro frontend disparar o alerta com som/piscar.
  # O `conversation.status_changed` nativo do Chatwoot não basta porque a
  # conv normalmente NÃO está no store do frontend enquanto snoozed (filtros
  # padrão omitem snoozed), então o watcher do componente Klaos não tem
  # `prevStatus='snoozed'` registrado pra detectar a transição.
  def klaos_broadcast_snooze_reopened(conversation)
    account = conversation.account
    tokens = account.users.pluck(:pubsub_token).compact.uniq
    return if tokens.empty?

    # (19/08/2026) `assignee_id` VAI NO PACOTE.
    #
    # Sem ele o front tinha que descobrir o dono procurando a conversa na
    # store — e a store não tem conversa adiada, que é justamente o motivo
    # deste broadcast existir. Sem dono, o filtro "só alerta conversa minha"
    # reprovava TODAS e o alerta morria em silêncio antes do som.
    payload = {
      conversation_id: conversation.id,
      conversation_display_id: conversation.display_id,
      assignee_id: conversation.assignee_id,
      sender_name: conversation.contact&.name,
      account_id: account.id
    }
    ::ActionCableBroadcastJob.perform_later(tokens, KLAOS_SNOOZE_REOPENED_EVENT, payload)
  rescue StandardError => e
    Rails.logger.warn(
      "[KlaosSnoozeNoLimit] broadcast custom event falhou conv=#{conversation.id}: #{e.message}"
    )
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversations::ReopenSnoozedConversationsJob)
  next if Conversations::ReopenSnoozedConversationsJob.include?(KlaosSnoozeNoLimit)

  Conversations::ReopenSnoozedConversationsJob.prepend(KlaosSnoozeNoLimit)
  Rails.logger.info '[KlaosSnoozeNoLimit] prepended on Conversations::ReopenSnoozedConversationsJob'
end
