# frozen_string_literal: true

# KLaOS — Cobre o gap unidirecional do Whatsapp::PhoneNumberNormalizationService
# vanilla no lado Chatwoot/Frontdesk. Complementa o fix #577 do KLaOS (que trata
# o path KLaOS→API Frontdesk).
#
# ----------------------------------------------------------------------------
# Contexto — dois lados independentes:
#
# 1) KLaOS→API Frontdesk (fix #577 do repo klaos, commit 22fdd4e0):
#    server/src/utils/phoneNormalize.ts + phoneCandidates() cobrem esse path.
#    Já em prod desde 16/07.
#
# 2) Meta webhook→Chatwoot (Whatsapp::IncomingMessageBaseService):
#    Chatwoot upstream JÁ TEM Whatsapp::PhoneNumberNormalizationService que
#    usa Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer pra adicionar o
#    "9" ausente e buscar contact_inbox pelo normalizado. Cobre UMA direção:
#
#      msg SEM 9 chega + contato COM 9 existe
#        → normalize adiciona 9 → find_by(source_id: COM 9) → ACHA → OK ✅
#
#    Mas NÃO cobre a OUTRA direção:
#
#      msg COM 9 chega + contato SEM 9 existe (legado)
#        → normalize retorna igual (já tem 9) → find_by(COM 9) → NÃO ACHA
#        → service retorna raw → cria contact_inbox NOVO com COM 9
#        → DUPLICATA
#
# Evidência empírica prod (Mais Saúde acct 9, invest 2026-07-23):
#   contatos 72631, 72615, 72671 têm source_id SEM 9 → foram criados por
#   webhook Meta em algum momento sem passar por normalization (ou existiam
#   pré-BrazilPhoneNormalizer no upstream).
#
# ----------------------------------------------------------------------------
# Fix (minimal, reusa 100% vanilla):
#
# Prepend em Whatsapp::PhoneNumberNormalizationService#find_existing_contact_inbox
# adicionando fallback: se busca pelo normalizado falhou, tenta variação
# (mesmo número BR sem o "9"). Se ainda não achar, comportamento vanilla
# preservado (retorna nil → service devolve raw → cria contact_inbox novo).
#
# Escopo: SÓ BR (só gera variante se source_id é E.164 BR celular com 9).
# Outros países passam direto pro super — comportamento vanilla intacto.
#
# Zero mudança em app/. Prepend via to_prepare — idempotente.
# ----------------------------------------------------------------------------

module KlaosPhoneNormalizeVariantSearch
  # Regex reusáveis pra detectar formato BR canônico em qualquer provider
  # (Cloud: "5531988862094" | Twilio: "whatsapp:+5531988862094").
  BR_CANONICAL_CELL_RE = /^(?<prefix>whatsapp:\+|\+)?(?<digits>55[1-9][0-9]9\d{8})$/

  # Erro da Meta que significa "esse endereco nao existe no WhatsApp".
  ERRO_ENDERECO_MORTO_RE = /131026/.freeze

  # (18/08/2026) O WA_ID DO WEBHOOK E O ENDERECO QUE FUNCIONA — passa a valer.
  #
  # INCIDENTE — ELLEN, conv 2455 da conta 9 (10/08). A cobranca criou o
  # contact_inbox com o telefone do espelho da Tenex, `5531925348364`. Esse
  # numero nao existe no WhatsApp: TODA mensagem voltou 131026. O template d0,
  # o cobrar-agora, duas saudacoes do Gustavo e — o que dói — os dois blocos com
  # o material do aplicativo que ele mandou as 11:24. Seis mensagens, zero
  # entregues.
  #
  # No meio disso a ELLEN escreveu "Oiii". A mensagem dela chegou: o wa_id real
  # e `553125348364` (sem o nono digito), o BrazilPhoneNormalizer do upstream
  # acrescentou o "9", achou o contact_inbox e a conversa seguiu normal na tela.
  # O que o upstream NAO faz e guardar o wa_id que acabou de provar que funciona
  # — ele devolve o source_id velho e o descarta. A janela de 24h abriu, o
  # atendente respondeu dentro dela, e a resposta foi pro endereco morto de novo.
  #
  # Medido na producao no mesmo dia (45 dias de historico): 46 contatos com
  # 131026; dos 5 que chegaram a escrever, os 5 tinham o mesmo desenho — o
  # source_id gravado com um "9" a mais que o wa_id real. Nenhum se corrigiu
  # sozinho.
  #
  # REGRA: quando a Meta entrega uma mensagem vinda de um wa_id diferente do
  # source_id gravado, e o ULTIMO envio pra esse contact_inbox morreu com 131026,
  # o source_id passa a ser o wa_id do webhook. Quem esta dizendo qual e o
  # endereco certo e o proprio WhatsApp, nao um palpite nosso.
  #
  # TRES TRAVAS, todas fail-closed (na duvida, nao mexe):
  #  1. so quando os dois sao o MESMO numero BR variando o nono digito — nunca
  #     aponta o contact_inbox pra outra pessoa;
  #  2. so quando o ultimo envio falhou com 131026 — contato que entrega hoje
  #     nao e tocado (a Meta resolve a variacao sozinha na maioria dos casos, e
  #     reescrever todo mundo seria trocar um problema medido por um nao medido);
  #  3. so quando nenhum outro contact_inbox da caixa ja ocupa o wa_id real —
  #     senao seria colisao, que e o incidente do klaos_contact_inbox_source_id_fix.
  #
  # Nao ha caminho de volta a percorrer: assim que o source_id certo entra, o
  # envio para de falhar e a trava 2 nunca mais permite mexer.
  def normalize_and_find_contact_by_provider(raw_number, provider)
    escolhido = super
    return escolhido unless provider == :cloud

    begin
      klaos_repontar_para_o_waid_real(raw_number, escolhido) || escolhido
    rescue StandardError => e
      # Falha aqui nao pode derrubar a entrada da mensagem do cliente.
      Rails.logger.error(
        "[KlaosPhoneNormalize] repontar source_id falhou | inbox_id=#{inbox&.id} " \
        "waid=#{raw_number} escolhido=#{escolhido} erro=#{e.class}: #{e.message}"
      )
      escolhido
    end
  end

  def find_existing_contact_inbox(normalized_waid)
    match = super
    return match if match

    variant = klaos_br_variant_without_9(normalized_waid)
    return nil if variant.nil? || variant == normalized_waid

    fallback = inbox.contact_inboxes.find_by(source_id: variant)
    if fallback
      Rails.logger.info(
        "[KlaosPhoneNormalize] contact_inbox matched by legacy no-9 variant | " \
        "inbox_id=#{inbox.id} contact_id=#{fallback.contact_id} " \
        "normalized=#{normalized_waid} matched=#{variant}"
      )
    end
    fallback
  end

  private

  # Devolve o wa_id real quando o repontamento aconteceu; nil quando nao ha o
  # que fazer (que e o caso da esmagadora maioria das mensagens).
  def klaos_repontar_para_o_waid_real(waid_real, escolhido)
    return nil if waid_real.blank? || escolhido.blank? || escolhido == waid_real
    return nil unless klaos_mesmo_numero_variando_o_9?(escolhido, waid_real)

    contact_inbox = inbox.contact_inboxes.find_by(source_id: escolhido)
    return nil if contact_inbox.nil?
    return nil if inbox.contact_inboxes.where(source_id: waid_real).where.not(id: contact_inbox.id).exists?
    return nil unless klaos_ultimo_envio_morreu_131026?(contact_inbox)

    contact_inbox.update!(source_id: waid_real)
    Rails.logger.warn(
      "[KlaosPhoneNormalize] source_id repontado pelo wa_id do webhook | " \
      "inbox_id=#{inbox.id} contact_id=#{contact_inbox.contact_id} " \
      "de=#{escolhido} para=#{waid_real} (ultimo envio 131026)"
    )
    waid_real
  end

  # Mesmo numero BR escrito das duas formas vivas: 12 digitos (sem o nono) e 13
  # (com). Exige pais, DDD e os 8 finais iguais, e que um seja exatamente o
  # outro com o "9" inserido — comparar so o final aprovaria o numero do vizinho.
  def klaos_mesmo_numero_variando_o_9?(um, outro)
    x = um.to_s.gsub(/\D/, '')
    y = outro.to_s.gsub(/\D/, '')
    return false unless x.start_with?('55') && y.start_with?('55')
    return false unless [x.length, y.length].sort == [12, 13]
    return false unless x[2, 2] == y[2, 2]
    return false unless x[-8, 8] == y[-8, 8]

    com9, sem9 = x.length == 13 ? [x, y] : [y, x]
    com9 == "#{sem9[0, 4]}9#{sem9[4..]}"
  end

  # O ultimo que a gente mandou pra esse contato voltou como "endereco nao
  # existe"? Nota privada e atividade (etiqueta, atribuicao) ficam de fora —
  # nenhuma das duas passa pela Meta.
  def klaos_ultimo_envio_morreu_131026?(contact_inbox)
    # `reorder`, nao `order`: Message tem `default_scope { order(created_at: :asc) }`
    # (app/models/message.rb:126), e `order` APENDA — o SQL sairia
    # "ORDER BY created_at ASC, created_at DESC" e o `.first` traria a mensagem
    # MAIS ANTIGA. Com isso, um 131026 velho seguido de entregas normais
    # continuaria autorizando o repontamento para sempre. O proprio Chatwoot usa
    # `reorder` nos scopes dele pelo mesmo motivo.
    ultimo = Message
             .where(conversation_id: contact_inbox.conversations.select(:id))
             .where(message_type: [Message.message_types[:outgoing], Message.message_types[:template]],
                    private: false)
             .reorder(created_at: :desc, id: :desc)
             .first
    return false if ultimo.nil?

    ultimo.failed? && ERRO_ENDERECO_MORTO_RE.match?(ultimo.external_error.to_s)
  end

  # Se normalized_waid é BR celular com "9" (13 dígitos brutos), gera a
  # variação sem "9" no MESMO formato (Cloud ou Twilio) pra query fallback.
  # Retorna nil se não é BR canônico com 9 (ex: fixo BR, outros países,
  # já sem 9) — nesses casos vanilla behavior é suficiente.
  def klaos_br_variant_without_9(waid)
    match = BR_CANONICAL_CELL_RE.match(waid.to_s)
    return nil unless match

    prefix = match[:prefix].to_s # "" | "+" | "whatsapp:+"
    digits = match[:digits]      # "55DDD9XXXXYYYY"
    ddd = digits[2, 2]
    rest = digits[5..] # remove "55" + DDD + "9" primeiro dígito
    "#{prefix}55#{ddd}#{rest}"
  end
end

Rails.application.config.to_prepare do
  service_class = 'Whatsapp::PhoneNumberNormalizationService'.safe_constantize
  if service_class && !service_class.include?(KlaosPhoneNormalizeVariantSearch)
    service_class.prepend(KlaosPhoneNormalizeVariantSearch)
    Rails.logger.info '[KlaosPhoneNormalize] prepended on Whatsapp::PhoneNumberNormalizationService (variant search fix, related #577)'
  end
end
