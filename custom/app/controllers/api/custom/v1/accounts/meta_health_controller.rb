# frozen_string_literal: true

# KLaOS — Saúde do WhatsApp por número (Fase 2 do fix de áudio).
#
# Endpoint admin que agrega pra cada inbox WhatsApp Cloud da conta:
#   - Status Meta vivo (quality_rating, throughput, can_send_message)
#   - Counts de mensagens 24h/7d/30d por status (sent/delivered/read/failed)
#   - Top 10 contatos com mais falhas (24h)
#   - Top códigos de erro (24h)
#
# Multi-tenant: serve qualquer conta. Mostra apenas inboxes Channel::Whatsapp
# com provider='whatsapp_cloud'. Outros providers (360dialog) ficam de fora
# por enquanto.
#
# Performance: Meta API chamada com cache de 5min por inbox (evita hammering
# do dashboard). Counts de DB são pesados — uses index em messages(account_id,
# inbox_id, status, created_at) que já existe upstream.

class Api::Custom::V1::Accounts::MetaHealthController < Api::V1::Accounts::BaseController
  META_CACHE_TTL = 5.minutes

  def index
    inboxes = Current.account.inboxes
                     .where(channel_type: 'Channel::Whatsapp')
                     .includes(:channel)

    payload = inboxes.map do |inbox|
      next unless inbox.channel.respond_to?(:provider) && inbox.channel.provider == 'whatsapp_cloud'

      {
        inbox_id: inbox.id,
        inbox_name: inbox.name,
        phone_number: inbox.channel.phone_number,
        phone_number_id: inbox.channel.provider_config&.dig('phone_number_id'),
        meta_status: meta_status_for(inbox),
        counts: counts_for(inbox),
        top_failing_contacts: top_failing_contacts_for(inbox),
        top_error_codes: top_error_codes_for(inbox)
      }
    end.compact

    render json: { inboxes: payload, generated_at: Time.current }
  end

  private

  def meta_status_for(inbox)
    cfg = inbox.channel.provider_config
    return nil unless cfg && cfg['api_key'].present? && cfg['phone_number_id'].present?

    cache_key = "klaos:meta_health:phone:#{cfg['phone_number_id']}"
    Rails.cache.fetch(cache_key, expires_in: META_CACHE_TTL) do
      fetch_meta_phone_status(cfg)
    end
  end

  def fetch_meta_phone_status(cfg)
    url = "https://graph.facebook.com/v18.0/#{cfg['phone_number_id']}" \
          "?fields=quality_rating,throughput,name_status,verified_name,display_phone_number," \
          'status,health_status,messaging_limit_tier'
    response = HTTParty.get(url,
                            headers: { 'Authorization' => "Bearer #{cfg['api_key']}" },
                            timeout: 10)

    if response.success?
      parsed = response.parsed_response
      {
        quality_rating: parsed['quality_rating'],
        throughput_level: parsed.dig('throughput', 'level'),
        status: parsed['status'],
        verified_name: parsed['verified_name'],
        can_send_message: parsed.dig('health_status', 'can_send_message'),
        messaging_limit_tier: parsed['messaging_limit_tier'],
        fetched_ok: true
      }
    else
      { fetched_ok: false, error: response.body.to_s.truncate(200) }
    end
  rescue StandardError => e
    Rails.logger.warn("[MetaHealth] phone status fetch failed: #{e.class}: #{e.message}")
    { fetched_ok: false, error: e.message }
  end

  def counts_for(inbox)
    {
      h24: count_in_window(inbox, 24.hours),
      d7: count_in_window(inbox, 7.days),
      d30: count_in_window(inbox, 30.days)
    }
  end

  def count_in_window(inbox, duration)
    rows = Message
           .where(account_id: Current.account.id, inbox_id: inbox.id, message_type: :outgoing)
           .where('created_at > ?', duration.ago)
           .group(:status).count
    {
      sent: rows[Message.statuses['sent']].to_i,
      delivered: rows[Message.statuses['delivered']].to_i,
      read: rows[Message.statuses['read']].to_i,
      failed: rows[Message.statuses['failed']].to_i
    }
  end

  def top_failing_contacts_for(inbox)
    rows = Message
           .joins(conversation: :contact)
           .where(account_id: Current.account.id, inbox_id: inbox.id,
                  message_type: :outgoing, status: :failed)
           .where('messages.created_at > ?', 24.hours.ago)
           .group('contacts.id', 'contacts.name', 'contacts.phone_number')
           .order(Arel.sql('COUNT(*) DESC'))
           .limit(10)
           .count

    rows.map do |(contact_id, contact_name, phone), failed_count|
      { contact_id: contact_id, name: contact_name, phone_number: phone, failed: failed_count }
    end
  end

  def top_error_codes_for(inbox)
    rows = Message
           .where(account_id: Current.account.id, inbox_id: inbox.id,
                  message_type: :outgoing, status: :failed)
           .where('messages.created_at > ?', 24.hours.ago)
           .where.not(external_error: [nil, ''])
           .pluck(:external_error)

    # Extrai code= ou primeiro código numérico do external_error
    bucket = Hash.new(0)
    rows.each do |err|
      code = err.to_s[/code=(\d+)/, 1] || err.to_s[/^(\d+):/, 1] || 'unknown'
      bucket[code] += 1
    end

    # Inclui também as falhas sem external_error como bucket separado
    no_detail_count = Message
                      .where(account_id: Current.account.id, inbox_id: inbox.id,
                             message_type: :outgoing, status: :failed)
                      .where('messages.created_at > ?', 24.hours.ago)
                      .where(external_error: [nil, ''])
                      .count
    bucket['sem_detalhe'] = no_detail_count if no_detail_count.positive?

    bucket.sort_by { |_k, v| -v }.first(10).map { |code, count| { code: code, count: count } }
  end
end
