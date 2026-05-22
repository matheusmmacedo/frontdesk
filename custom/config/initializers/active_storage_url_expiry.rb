# frozen_string_literal: true

# ACTIVE STORAGE SIGNED URL EXPIRY — 7 dias
#
# Default Rails: 5 min (300s). Cenário ruim na prática:
# atendente abre conversa com anexos → URLs assinadas Supabase carregadas
# no Vue → fica na tela (aba aberta, multitask) → URLs expiram → próximo
# render de <img>/<audio> dá 403/indisponível.
#
# Áudio/vídeo usam modo REDIRECT (precisam do Content-Length do Supabase pro
# player calcular duração). O redirect 302 resolve numa signed URL Supabase
# cujo TTL = este valor, e o browser cacheia o 302 por esse mesmo tempo.
# Com 24h, mídia ficava "indisponível após um tempo" quando a aba passava de
# ~24h. 7 dias (máximo do S3/Supabase) cobre qualquer jornada — na prática
# elimina o problema enquanto o proxy com Content-Length (fix definitivo) não
# entra. Trade-off de segurança: signed URL vale 7d; threat model interno
# (URLs só no app autenticado), aceitável.
#
# Apenas afeta URLs *novas* geradas após o boot.

Rails.application.config.active_storage.service_urls_expire_in = 7.days

# Rails.logger é nil durante rake assets:precompile (build time), então safe-nav.
Rails.logger&.info '[ActiveStorage] service_urls_expire_in = 7 days'
