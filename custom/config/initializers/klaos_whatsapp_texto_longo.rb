# frozen_string_literal: true

# KLaOS — TEXTO LONGO NO WHATSAPP CLOUD VIRA VARIAS MENSAGENS, NA ORDEM
#
# Regra de divisao e o porque: custom/app/services/klaos/whatsapp_texto_longo.rb
#
# Tres pecas, todas por prepend (nenhum arquivo upstream editado):
#
# 1. Messages::MessageBuilder#perform — o ponto unico por onde passa a mensagem
#    do atendente (composer), de macro, de automacao e do bot pela API. Se a
#    mensagem e de saida, nao privada, sem anexo, sem template, de texto, numa
#    inbox Channel::Whatsapp com provider whatsapp_cloud, e passa do limite,
#    cria N mensagens numa transacao so:
#      - parte 1: a mensagem "de verdade" (echo_id, resposta citando, prefixo
#        do atendente aplicado pelo human_message_prefix.rb);
#      - partes 2..N: so o texto, sem citacao, com skip_klaos_prefix (prefixo
#        so na primeira).
#    Devolve a parte 1, que e o que o controller renderiza e o front casa pelo
#    echo_id; as outras chegam no front pelo ActionCable como qualquer mensagem.
#
# 2. Message#send_reply — parte 2..N NAO entra na fila ao ser criada.
#
# 3. SendReplyJob#perform — depois que a Meta aceita a parte k (source_id
#    gravado), libera a parte k+1 e enfileira com ESPERA_ENTRE_PARTES. Se a
#    parte k falhou, as seguintes ficam como falha com o motivo, em vez de
#    sairem fora de ordem. Parte 2..N que nao foi liberada e ignorada pelo job
#    (cobre o caso de alguem enfileirar direto, como o envio sequencial de
#    macro em klaos_macro_sequenced_send.rb).
#
# Nota privada, mensagem curta, anexo e qualquer outro canal: nada muda.
# Reenviar uma parte que falhou (botao de retry) limpa o content_attributes no
# upstream, entao ela sai como mensagem comum e nao puxa as seguintes.

module KlaosWhatsappTextoLongoBuilder
  def perform
    partes = klaos_partes_texto_longo
    return super if partes.nil?

    grupo = SecureRandom.uuid
    total = partes.size
    Rails.logger.info("[KlaosTextoLongo] conv=#{@conversation.id} dividindo em #{total} partes grupo=#{grupo} " \
                      "tamanhos=#{partes.map { |p| Klaos::WhatsappTextoLongo.tamanho(p) }.inspect}")

    ActiveRecord::Base.transaction do
      @klaos_parte_um = { conteudo: partes.first, marca: klaos_marca(grupo, 1, total) }
      primeira = super
      @klaos_parte_um = nil

      partes.drop(1).each.with_index(2) do |texto, numero|
        @conversation.messages.create!(
          account_id: primeira.account_id,
          inbox_id: primeira.inbox_id,
          message_type: primeira.message_type,
          private: false,
          sender: primeira.sender,
          content_type: primeira.content_type,
          content: texto,
          # created_at e gravado em segundos; todas as partes nascem no mesmo
          # segundo e a lista (reorder created_at) poderia embaralhar. Um
          # segundo a mais por parte deixa a ordem fixa na tela e na API.
          created_at: primeira.created_at + (numero - 1).seconds,
          content_attributes: {
            'skip_klaos_prefix' => true,
            Klaos::WhatsappTextoLongo::CHAVE => klaos_marca(grupo, numero, total)
          }
        )
      end
      primeira
    end
  ensure
    @klaos_parte_um = nil
  end

  private

  def message_params
    base = super
    return base if @klaos_parte_um.nil?

    atributos = (base[:content_attributes] || {}).to_h.merge(Klaos::WhatsappTextoLongo::CHAVE => @klaos_parte_um[:marca])
    base.merge(content: @klaos_parte_um[:conteudo], content_attributes: atributos)
  end

  def klaos_marca(grupo, parte, total)
    { 'grupo' => grupo, 'parte' => parte, 'total' => total, 'liberada' => parte == 1 }
  end

  # nil = segue o fluxo normal do Chatwoot.
  def klaos_partes_texto_longo
    return nil unless klaos_texto_longo_aplica?

    conteudo = @params[:content].to_s
    reserva = Klaos::WhatsappTextoLongo.reserva_para(klaos_prefixo_previsto)
    return nil unless Klaos::WhatsappTextoLongo.precisa_dividir?(conteudo, reserva)

    partes = Klaos::WhatsappTextoLongo.dividir(conteudo, reserva)
    partes.size > 1 ? partes : nil
  rescue StandardError => e
    Rails.logger.error("[KlaosTextoLongo] falha ao avaliar divisao, segue normal: #{e.class}: #{e.message}")
    nil
  end

  def klaos_texto_longo_aplica?
    return false if ActiveModel::Type::Boolean.new.cast(@private)
    return false unless @message_type.to_s == 'outgoing'
    return false if @attachments.present?
    return false if @params[:template_params].present?
    return false if @params[:content_type].present? && @params[:content_type].to_s != 'text'

    inbox = @conversation.inbox
    inbox&.channel_type == 'Channel::Whatsapp' && inbox.channel&.provider == 'whatsapp_cloud'
  end

  # O prefixo e aplicado depois, no before_create (human_message_prefix.rb).
  # Aqui so medimos o tamanho dele pra reservar espaco na 1a parte.
  def klaos_prefixo_previsto
    return '' unless defined?(KlaosHumanMessagePrefix)

    template = @account&.custom_attributes&.[]('klaos_human_message_template')
    return '' if template.blank?

    KlaosHumanMessagePrefix.render(template, sender)
  rescue StandardError
    ''
  end
end

module KlaosWhatsappTextoLongoEnvio
  module_function

  def marca(mensagem)
    attrs = mensagem&.content_attributes
    return nil unless attrs.is_a?(Hash)

    valor = attrs[Klaos::WhatsappTextoLongo::CHAVE]
    valor.is_a?(Hash) ? valor : nil
  end

  # Parte 2..N ainda nao liberada pela anterior.
  def aguardando_vez?(mensagem)
    m = marca(mensagem)
    m.present? && m['parte'].to_i > 1 && !m['liberada']
  end

  def partes_seguintes(mensagem)
    m = marca(mensagem)
    return [] if m.nil?

    Message.where(conversation_id: mensagem.conversation_id)
           .where('id > ?', mensagem.id)
           .where('content_attributes::text LIKE ?', "%#{m['grupo']}%")
           .order(:id)
           .select { |x| marca(x)&.dig('grupo') == m['grupo'] && marca(x)['parte'].to_i > m['parte'].to_i }
           .sort_by { |x| marca(x)['parte'].to_i }
  end

  def seguir_depois_de(mensagem)
    mensagem.reload
    m = marca(mensagem)
    return if m.nil?
    return interromper_depois_de(mensagem) if mensagem.status.to_s == 'failed' || mensagem.source_id.blank?

    proxima = partes_seguintes(mensagem).first
    return if proxima.nil? || proxima.source_id.present? || proxima.status.to_s == 'failed'

    attrs = proxima.content_attributes.to_h
    attrs[Klaos::WhatsappTextoLongo::CHAVE] = marca(proxima).merge('liberada' => true)
    proxima.update!(content_attributes: attrs)
    Rails.logger.info("[KlaosTextoLongo] parte #{m['parte']}/#{m['total']} aceita (msg=#{mensagem.id}), " \
                      "liberando msg=#{proxima.id}")
    ::SendReplyJob.set(wait: Klaos::WhatsappTextoLongo::ESPERA_ENTRE_PARTES.seconds).perform_later(proxima.id)
  end

  def interromper_depois_de(mensagem)
    m = marca(mensagem)
    return if m.nil?

    partes_seguintes(mensagem).each do |parte|
      next if parte.source_id.present? || parte.status.to_s == 'failed'

      parte.external_error = "Nao enviada: a parte #{m['parte']} de #{m['total']} falhou antes. " \
                             'Reenvie as partes na ordem.'
      parte.status = :failed
      parte.save!
    end
    Rails.logger.warn("[KlaosTextoLongo] parte #{m['parte']}/#{m['total']} falhou (msg=#{mensagem.id}); seguintes marcadas como falha")
  rescue StandardError => e
    Rails.logger.error("[KlaosTextoLongo] interromper_depois_de: #{e.class}: #{e.message}")
  end
end

module KlaosWhatsappTextoLongoSendReply
  def send_reply
    return if KlaosWhatsappTextoLongoEnvio.aguardando_vez?(self)

    super
  end
end

module KlaosWhatsappTextoLongoJob
  def perform(message_id)
    mensagem = Message.find_by(id: message_id)
    return super if KlaosWhatsappTextoLongoEnvio.marca(mensagem).nil?
    return if KlaosWhatsappTextoLongoEnvio.aguardando_vez?(mensagem)
    # Ja saiu (job duplicado): nao reenvia e nao libera a proxima de novo.
    return if mensagem.source_id.present?

    begin
      super
    rescue StandardError
      KlaosWhatsappTextoLongoEnvio.interromper_depois_de(mensagem)
      raise
    end
    KlaosWhatsappTextoLongoEnvio.seguir_depois_de(mensagem)
  end
end

# Mesmo mecanismo do klaos_macro_sequenced_send.rb. Este arquivo carrega depois
# dele (ordem alfabetica), entao o send_reply daqui fica por fora e decide
# primeiro; e o guard do job cobre qualquer outra ordem.
Rails.application.reloader.to_prepare do
  Messages::MessageBuilder.prepend(KlaosWhatsappTextoLongoBuilder) unless Messages::MessageBuilder <= KlaosWhatsappTextoLongoBuilder
  Message.prepend(KlaosWhatsappTextoLongoSendReply) unless Message <= KlaosWhatsappTextoLongoSendReply
  SendReplyJob.prepend(KlaosWhatsappTextoLongoJob) unless SendReplyJob <= KlaosWhatsappTextoLongoJob
end
