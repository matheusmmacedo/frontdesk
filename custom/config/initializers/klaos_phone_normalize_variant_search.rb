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
