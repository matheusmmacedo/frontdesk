# frozen_string_literal: true

# AUDITORIA DE CONTATO APAGADO
#
# Apagar um contato destroi TODAS as conversas dele em cascata
# (`app/models/contact.rb`, `dependent: :destroy_async`). O upstream audita
# Conversation no destroy (`enterprise/app/models/enterprise/audit/conversation.rb`),
# mas NAO audita Contact — entao a conversa apagada por cascata fica com
# `user_id` NULL, porque quem destroi e o job, nao a pessoa. Resultado: some
# conversa de paciente e nao ha linha nenhuma dizendo quem mandou apagar.
#
# Medido em 29/08/2026 nos dois bancos:
#   producao  -> 57 destroys de Conversation com user_id NULL, entre 04/03 e
#                14/08. Dois deles sao conversa de paciente real (conta 9 em
#                02/08, conta 12 em 14/08).
#   dev       -> 230 no mesmo padrao.
# Em nenhum desses casos da para saber quem apagou o contato, porque `Contact`
# nao esta no conjunto auditado. Nao existe
# `enterprise/app/models/enterprise/audit/contact.rb`.
#
# Isto NAO recupera o que ja foi. Faz a proxima deixar rastro.
#
# `only: []` de proposito, igual ao concern de Conversation: nao guardamos
# NENHUMA coluna do contato. Nome, telefone, e-mail e identifier sao PII de
# paciente, e o audit ja responde o que interessa sem eles — `auditable_id` diz
# QUAL contato, `user_id` diz QUEM, `created_at` diz QUANDO. Guardar o resto
# seria criar um deposito de PII numa tabela que ninguem trata como tal.
#
# Vive em custom/ porque nao pode morrer em merge do Chatwoot. O upstream nunca
# vai adicionar este arquivo, e mexer em `app/models/contact.rb` seria conflito
# garantido no proximo merge.

Rails.application.config.to_prepare do
  next unless defined?(Contact)
  # `audited` define este metodo de classe. Se ja responde, o modelo ja foi
  # auditado — por este initializer numa recarga, ou pelo upstream, se um dia
  # ele passar a auditar Contact. Nos dois casos, nao registrar de novo.
  next if Contact.respond_to?(:auditing_enabled)

  begin
    Contact.audited only: [], on: [:destroy]
    Rails.logger.info('[KLaOS] Contact passou a ser auditado no destroy')
  rescue StandardError => e
    # De proposito NAO propaga: initializer que levanta derruba o boot inteiro
    # da aplicacao, e ficar sem atendimento e muito pior que ficar sem esta
    # linha de auditoria. Se a gem mudar de API num merge do Chatwoot, o log
    # avisa e o Frontdesk sobe igual.
    Rails.logger.error("[KLaOS] falhou ao auditar Contact no destroy: #{e.class}: #{e.message}")
  end
end
