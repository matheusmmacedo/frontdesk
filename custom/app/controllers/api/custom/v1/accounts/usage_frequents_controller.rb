# frozen_string_literal: true

# KLaOS — Global usage frequents
#
# Agrega ranking de uso da CONTA INTEIRA pra servir como ordenação fallback
# quando o atendente ainda não tem preferência pessoal coletada
# (user.ui_settings.X_frequents). Atendente novo entra com ranking decente
# e à medida que usa o app, suas preferências pessoais sobrescrevem o global.
#
# Hierarquia no frontend:
#   personal[key] || global[key] || 0  → alfabético como desempate final
#
# Origem dos counters:
#   - labels    → derivado de taggings (ground truth, sempre fresh)
#   - templates → derivado de messages humanos (sender_type='User', exclui bot)
#   - emojis    → account.custom_attributes.emoji_frequents (dual-write na seleção)
#   - canned    → account.custom_attributes.canned_frequents (dual-write na seleção)
#
# Cache 10min nos derivados pra evitar count() repetido por user em accs maiores.
#
# Endpoints:
#   GET  /api/custom/v1/accounts/:account_id/usage_frequents
#         → { labels:{}, templates:{}, emojis:{}, canned:{} }
#   POST /api/custom/v1/accounts/:account_id/usage_frequents/track
#         body: { type: 'emoji'|'canned', key: '...' }
#         → 200 ok (incrementa o counter global da conta)

class Api::Custom::V1::Accounts::UsageFrequentsController < Api::V1::Accounts::BaseController
  CACHE_TTL = 10.minutes
  MAX_ENTRIES = 128

  def index
    render json: {
      labels: cached(:labels) { top_labels },
      templates: cached(:templates) { top_templates },
      emojis: from_account('emoji_frequents'),
      canned: from_account('canned_frequents')
    }
  end

  def track
    type = params[:type].to_s
    key = params[:key].to_s
    return head :bad_request unless %w[emoji canned].include?(type) && key.present?

    column = "#{type}_frequents"

    # Lock pra evitar perda de increment em concurrent writes (vários
    # atendentes clicando ao mesmo tempo). update_columns pula validations
    # e callbacks — só persiste a coluna JSONB direto.
    Current.account.with_lock do
      attrs = (Current.account.custom_attributes || {}).dup
      freq = (attrs[column] || {}).dup
      freq[key] = (freq[key] || 0) + 1
      # cap por count desc pra não inflar o JSONB
      capped = freq.sort_by { |_, v| -v }.first(MAX_ENTRIES).to_h
      attrs[column] = capped
      Current.account.update_columns(custom_attributes: attrs)
    end

    head :ok
  rescue StandardError => e
    Rails.logger.error("[UsageFrequents] track fail type=#{type} key=#{key.inspect}: #{e.class}: #{e.message}")
    head :internal_server_error
  end

  private

  def cached(kind, &block)
    Rails.cache.fetch(
      "klaos:usage_frequents:#{Current.account.id}:#{kind}",
      expires_in: CACHE_TTL,
      &block
    )
  end

  def top_labels
    ActsAsTaggableOn::Tagging
      .joins('JOIN tags ON tags.id = taggings.tag_id')
      .joins('JOIN conversations ON conversations.id = taggings.taggable_id')
      .where(taggings: { taggable_type: 'Conversation', context: 'labels' })
      .where(conversations: { account_id: Current.account.id })
      .group('tags.name')
      .count
      .sort_by { |_, v| -v }
      .first(MAX_ENTRIES)
      .to_h
  rescue StandardError => e
    Rails.logger.error("[UsageFrequents] top_labels: #{e.class}: #{e.message}")
    {}
  end

  def top_templates
    # Só conta uso humano (sender_type='User'). Bot/automação envia template
    # via API direto (sender_type='AgentBot') e fica fora do ranking — atende
    # ao pedido "considera humano, não bot".
    Message
      .joins(:conversation)
      .where(conversations: { account_id: Current.account.id })
      .where(message_type: :outgoing)
      .where(sender_type: 'User')
      .where("messages.additional_attributes->'template_params' ? 'name'")
      .group("messages.additional_attributes->'template_params'->>'name'")
      .count
      .sort_by { |_, v| -v }
      .first(MAX_ENTRIES)
      .to_h
  rescue StandardError => e
    Rails.logger.error("[UsageFrequents] top_templates: #{e.class}: #{e.message}")
    {}
  end

  def from_account(key)
    (Current.account.custom_attributes || {})[key] || {}
  end
end
