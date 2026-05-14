# frozen_string_literal: true

# ACTIVE STORAGE SIGNED URL EXPIRY — 24h
#
# Default Rails: 5 min (300s). Cenário ruim na prática:
# atendente abre conversa com anexos → URLs assinadas Supabase carregadas
# no Vue → fica > 5 min na tela (longa conversa, multitask) → URLs expiram
# → próximo render de <img>/<audio> dá 403 → aparece quebrado.
#
# 24h cobre uma jornada inteira de atendente sem precisar recarregar a
# página. Trade-off de segurança: signed URL vaza, vale por 24h em vez
# de 5 min. Pro nosso threat model (URLs ficam só no app autenticado, não
# são compartilhadas externamente) é aceitável.
#
# Apenas afeta URLs *novas* geradas após o boot. URLs antigas mantém o
# expiry com que foram assinadas.

Rails.application.config.active_storage.service_urls_expire_in = 24.hours

# Rails.logger é nil durante rake assets:precompile (build time), então safe-nav.
# No runtime (web/worker boot) o logger existe e a linha aparece.
Rails.logger&.info '[ActiveStorage] service_urls_expire_in = 24h'
