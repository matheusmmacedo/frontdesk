# frozen_string_literal: true

# KLaOS — Busca GLOBAL sem acentuação.
#
# (18/09/2026) O cliente mandou o vídeo: buscou "Édson AndrE da Silva" e não
# achou nada; tirou o acento do É, buscou "Edson AndrE da Silva" e apareceu
# "Contatos (2) — EDSON ANDRE DA SILVA". Palavras dele: "lá no Qualizap
# funciona, aqui no seu não tá funcionando (...) tem que achar com acento ou
# sem acento". E disse que é pedido repetido: "já te fiz esse pedido algumas
# vezes".
#
# POR QUE O FIX ANTIGO NÃO PEGAVA ESTE CASO.
#
# `klaos_contact_search_unaccent.rb` (29/05) já resolve `ContactsController#search`,
# que é a busca da TELA DE CONTATOS. O vídeo mostra a URL `/search?q=...`, que é
# a BUSCA GLOBAL da lupa: outro caminho, `SearchService`, nunca tratado. Por
# isso o cliente continuou vendo o defeito mesmo depois do fix de maio.
#
# O QUE MUDA AQUI.
#
# Só os campos onde cabe acento — nome e e-mail do contato, e o conteúdo da
# mensagem. Telefone e identifier ficam com `ILIKE` puro de propósito: são
# dígitos/códigos, `unaccent` neles só gastaria CPU. A comparação é feita sem
# acento NOS DOIS LADOS, então funciona nas duas direções: cadastro com acento
# e busca sem, e cadastro sem acento e busca com (que é o caso do vídeo).
#
# Pré-requisito: extensão `unaccent` no Postgres, já habilitada em dev e prod
# em 2026-05-29 pelo fix anterior.
#
# CUSTO: `unaccent(coluna)` não usa índice comum. A busca global já era
# `ILIKE '%...%'`, que também não usa, então não há regressão de plano — o
# upstream já varria a tabela. Se um dia virar problema, a saída é índice
# funcional em `unaccent(name)`, e não voltar a comparar com acento.

module KlaosGlobalSearchUnaccent
  private

  def filter_contacts
    contacts_query = current_account.contacts.where(
      'unaccent(name) ILIKE unaccent(:search) ' \
      'OR unaccent(email) ILIKE unaccent(:search) ' \
      'OR phone_number ILIKE :search ' \
      'OR identifier ILIKE :search',
      search: "%#{search_query}%"
    )

    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    @contacts = contacts_query.resolved_contacts(
      use_crm_v2: current_account.feature_enabled?('crm_v2')
    ).order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def filter_conversations
    conversations_query = current_account.conversations.where(inbox_id: accessable_inbox_ids)
                                         .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                                         .where(
                                           'cast(conversations.display_id as text) ILIKE :search ' \
                                           'OR unaccent(contacts.name) ILIKE unaccent(:search) ' \
                                           'OR unaccent(contacts.email) ILIKE unaccent(:search) ' \
                                           'OR contacts.phone_number ILIKE :search ' \
                                           'OR contacts.identifier ILIKE :search',
                                           search: "%#{search_query}%"
                                         )

    if current_account.feature_enabled?('advanced_search')
      conversations_query = apply_time_filter(conversations_query, 'conversations.last_activity_at')
    end

    @conversations = conversations_query.order('conversations.created_at DESC')
                                        .page(params[:page])
                                        .per(15)
  end

  def filter_messages_with_like
    base_query = message_base_query
    base_query = apply_message_filters(base_query)
    base_query.where('unaccent(messages.content) ILIKE unaccent(:search)', search: "%#{search_query}%")
              .reorder('created_at DESC')
              .page(params[:page])
              .per(15)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(SearchService)
  next if SearchService.include?(KlaosGlobalSearchUnaccent)

  SearchService.prepend(KlaosGlobalSearchUnaccent)
  Rails.logger.info '[KlaosGlobalSearchUnaccent] prepended on SearchService'
end
