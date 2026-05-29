# frozen_string_literal: true

# KLaOS — Busca de contato sem acentuação (Item 11 do Gustavo).
#
# Problema original: digitar "cassia" não acha "CÁSSIA". O upstream
# ContactsController#search usa `ILIKE` puro:
#
#   contacts.where(
#     'name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR contacts.identifier LIKE :search',
#     search: "%#{params[:q].strip}%"
#   )
#
# ILIKE é case-insensitive mas NÃO ignora acentos. Pacientes têm nomes com
# acento, recepção digita sem — não acha.
#
# Fix multi-tenant via prepend: override `search` pra usar `unaccent()` em
# ambos lados da comparação. Vale pra qualquer cliente (multi-tenant nato).
#
# Pré-requisito: extensão `unaccent` habilitada no Postgres (rodada
# manualmente via `CREATE EXTENSION IF NOT EXISTS unaccent` em dev e prod
# em 2026-05-29).

module KlaosContactSearchUnaccent
  def search
    if params[:q].blank?
      render json: { error: 'Specify search string with parameter q' },
             status: :unprocessable_entity
      return
    end

    q = params[:q].strip
    contacts = Current.account.contacts.where(
      'unaccent(name) ILIKE unaccent(:search) ' \
      'OR unaccent(email) ILIKE unaccent(:search) ' \
      'OR phone_number ILIKE :search ' \
      "OR contacts.identifier LIKE :search",
      search: "%#{q}%"
    )
    @contacts = fetch_contacts_with_has_more(contacts)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Api::V1::Accounts::ContactsController)
  next if Api::V1::Accounts::ContactsController.include?(KlaosContactSearchUnaccent)

  Api::V1::Accounts::ContactsController.prepend(KlaosContactSearchUnaccent)
  Rails.logger.info '[KlaosContactSearchUnaccent] prepended on ContactsController'
end
