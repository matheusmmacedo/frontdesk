# frozen_string_literal: true

# KLaOS — Auto-offline override por conta (multi-tenant).
#
# Quando `account.settings['auto_offline_default'] == false`, todos os
# AccountUsers daquela conta passam a se comportar como `auto_offline=false` —
# ou seja, agentes não vão pra offline automaticamente por inatividade. O valor
# per-user no DB é preservado e volta a valer se o admin desligar o toggle.
#
# Usado pra paridade com Kualiz (ponto 9 do Gustavo). Modular e multi-tenant:
# - Funciona pra qualquer conta que ligue o toggle.
# - Não exige migration (settings é jsonb que já existe).
# - Não muta DB (override em runtime no reader).
# - Usa `account.settings` (não custom_attributes) porque settings já é
#   exposto integralmente no _account.json.jbuilder — frontend lê direto.
module KlaosAutoOfflineOverride
  def auto_offline
    return false if account&.settings&.dig('auto_offline_default') == false

    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(AccountUser)
  next if AccountUser.include?(KlaosAutoOfflineOverride)

  AccountUser.prepend(KlaosAutoOfflineOverride)
  Rails.logger.info '[KlaosAutoOfflineOverride] prepended on AccountUser'
end
