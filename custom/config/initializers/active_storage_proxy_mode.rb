# frozen_string_literal: true

# ACTIVE STORAGE — PROXY MODE
#
# Default Rails: `url_for(blob)` generates redirect URLs
#   (/rails/active_storage/blobs/redirect/:signed_id/:filename)
# que retornam 302 pra signed URL do Supabase. Problemas:
#   1. signed_id no path tem TTL (service_urls_expire_in). Após 24h dá 404.
#   2. signed URL Supabase tem TTL. Após 24h dá 403.
#   3. Browser não consegue cachear (URL muda a cada render).
#   4. Single point of failure: se Supabase trava, imagem some.
#
# PROXY mode: `url_for(blob)` gera proxy URLs
#   (/rails/active_storage/blobs/proxy/:signed_id/:filename)
# que fazem o RAILS baixar do Supabase e streamar pro browser.
#   1. URL estável (signed_id permanente).
#   2. Browser cacheia (Rails seta Cache-Control adequado).
#   3. Pode meter CDN/Cloudflare na frente.
#   4. Retry e tratamento de erro centralizados no Rails (próx. iteração).
#
# Trade-off: Web service consome banda fazendo o stream. Aceitável pq:
#   - File é baixado 1x e o browser cacheia (resto = 304)
#   - Rails 7 streama (não buffera tudo em memória)
#   - Eventualmente migramos pra R2 + CDN (issue #93)
#
# Aplica APENAS a url_for(blob)/url_for(representation), que é o que
# o Attachment#file_url e Attachment#thumb_url usam.
#
# Attachment#download_url continua direto pra Supabase (sem proxy) —
# é usado pelo Meta WhatsApp pra fetchar mídia; nessa direção precisa
# da URL direta pq Meta não passa pelo nosso proxy.

Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

Rails.logger&.info '[ActiveStorage] resolve_model_to_route = :rails_storage_proxy'
