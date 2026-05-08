# frozen_string_literal: true

# Linha do tempo unificada de um contato — agrega mensagens de TODAS as
# conversas (resolved, open, pending, snoozed) num único feed cronológico.
#
# Por que existe: atendentes (ex: Gustavo no Mais Saúde) precisam ver o
# histórico completo de interação com um cliente sem clicar em cada conv
# separada. Diferente de "Conversas anteriores" do painel direito, que só
# lista convs e exige clique pra abrir, esse endpoint retorna tudo num feed
# tipo WhatsApp (mesma conv contínua), com divisores por boundary de conv.
#
# GET /api/custom/v1/accounts/:account_id/contacts/:contact_id/timeline
#   Query params:
#     before  — id da mensagem mais antiga já carregada (cursor pra paginar pra trás)
#     limit   — máx 100 (default 60)
#
# Retorna:
#   {
#     contact: { id, name, phone_number },
#     messages: [
#       {
#         id, conversation_id, conversation_display_id, conversation_status,
#         message_type, content, content_attributes, content_type, private,
#         created_at, sender_type, sender: { id, name, type, thumbnail },
#         attachments: [{ id, file_type, data_url, thumb_url, file_size, extension }]
#       },
#       ...
#     ],
#     conversations: [
#       { id, display_id, status, created_at, resolved_at, inbox_id, inbox_name }
#     ],
#     has_more: bool
#   }

class Api::Custom::V1::Accounts::Contacts::TimelineController < Api::V1::Accounts::BaseController
  DEFAULT_LIMIT = 60
  MAX_LIMIT = 100

  before_action :set_contact

  def index
    Rails.logger.info("[TimelineCtrl] start contact_id=#{params[:contact_id]} account=#{Current.account&.id}")
    convs = @contact.conversations.where(account_id: Current.account.id).order(:created_at)
    conv_ids = convs.pluck(:id)
    Rails.logger.info("[TimelineCtrl] convs.count=#{conv_ids.size}")

    messages_scope = Message.where(conversation_id: conv_ids).order(created_at: :desc, id: :desc)
    messages_scope = messages_scope.where('messages.id < ?', params[:before]) if params[:before].present?

    limit = [params[:limit].to_i, MAX_LIMIT].min
    limit = DEFAULT_LIMIT if limit <= 0

    page = messages_scope.limit(limit + 1).to_a
    has_more = page.size > limit
    page = page.first(limit).reverse
    Rails.logger.info("[TimelineCtrl] page.size=#{page.size} has_more=#{has_more}")

    serialized_convs = convs.map { |c|
      serialize_conversation(c)
    rescue StandardError => e
      Rails.logger.error("[TimelineCtrl] serialize_conv crash conv=#{c.id}: #{e.class}: #{e.message}")
      { id: c.id, error: e.message }
    }
    Rails.logger.info("[TimelineCtrl] convs serialized")

    serialized_msgs = page.map { |m|
      serialize_message(m)
    rescue StandardError => e
      Rails.logger.error("[TimelineCtrl] serialize_msg crash msg=#{m.id}: #{e.class}: #{e.message} backtrace=#{e.backtrace[0..3].join(' | ')}")
      { id: m.id, error: e.message }
    }
    Rails.logger.info("[TimelineCtrl] msgs serialized")

    render json: {
      contact: {
        id: @contact.id,
        name: @contact.name,
        phone_number: @contact.phone_number,
        thumbnail: @contact.avatar_url
      },
      conversations: serialized_convs,
      messages: serialized_msgs,
      has_more: has_more
    }, status: :ok
  end

  private

  def set_contact
    @contact = Current.account.contacts.find(params[:contact_id])
  end

  def serialize_conversation(conv)
    # Conversation não tem coluna resolved_at no upstream Chatwoot. KLaOS guarda
    # via custom initializer track_resolved_timestamp em
    # additional_attributes['klaos_resolved_at'] (ISO8601). Convertemos pra epoch
    # se existir; senão null. Mantemos a chave 'resolved_at' pra simplificar o
    # consumo no front (formatConvBoundary).
    klaos_resolved = conv.additional_attributes&.[]('klaos_resolved_at')
    resolved_epoch = klaos_resolved.present? ? Time.parse(klaos_resolved).to_i : nil

    {
      id: conv.id,
      display_id: conv.display_id,
      status: conv.status,
      created_at: conv.created_at.to_i,
      inbox_id: conv.inbox_id,
      inbox_name: conv.inbox&.name,
      resolved_at: resolved_epoch,
      cached_label_list: conv.cached_label_list
    }
  rescue ArgumentError
    # data malformada em additional_attributes — não deixa quebrar o request
    {
      id: conv.id,
      display_id: conv.display_id,
      status: conv.status,
      created_at: conv.created_at.to_i,
      inbox_id: conv.inbox_id,
      inbox_name: conv.inbox&.name,
      resolved_at: nil,
      cached_label_list: conv.cached_label_list
    }
  end

  def serialize_message(msg)
    sender = msg.sender
    # ⚠ msg.private (sem `?`) colide com Ruby keyword — Chatwoot usa msg[:private]
    # ou msg.private? em todo lugar. Usar msg.private resolve pra Object#private
    # (visibility modifier) e quebra a serialização. Read via read_attribute pra
    # ser explícito.
    {
      id: msg.id,
      conversation_id: msg.conversation_id,
      message_type: msg.message_type_before_type_cast,
      content: msg.content,
      content_attributes: msg.content_attributes,
      content_type: msg.content_type,
      private: msg.read_attribute(:private),
      status: msg.status,
      source_id: msg.source_id,
      created_at: msg.created_at.to_i,
      sender_type: msg.sender_type,
      sender: sender ? serialize_sender(sender) : nil,
      attachments: msg.attachments.map { |a| serialize_attachment(a) }
    }
  end

  def serialize_sender(sender)
    {
      id: sender.id,
      name: sender.try(:name) || sender.try(:available_name),
      type: sender.class.name,
      thumbnail: sender.try(:avatar_url)
    }
  end

  def serialize_attachment(att)
    {
      id: att.id,
      file_type: att.file_type,
      data_url: att.file_url,
      thumb_url: att.thumb_url,
      file_size: att.file_size,
      extension: att.extension,
      fallback_title: att.fallback_title,
      coordinates_lat: att.coordinates_lat,
      coordinates_long: att.coordinates_long
    }
  end
end
