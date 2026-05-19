# frozen_string_literal: true

# Aplica prepend de ActiveStorageProxyWithContentLength em
# ActiveStorage::Blobs::ProxyController.
#
# Fix do "Infinity:NaN" no player <audio>/<video> quando proxy mode
# está ativo. Detalhes em
# custom/app/controllers/active_storage/proxy_with_content_length_patch.rb

require Rails.root.join('custom/lib/active_storage_proxy_with_content_length.rb')

Rails.application.config.to_prepare do
  ActiveStorage::Blobs::ProxyController.prepend(ActiveStorageProxyWithContentLength)
  Rails.logger&.info '[ActiveStorage] ProxyController patched with Content-Length'
end
