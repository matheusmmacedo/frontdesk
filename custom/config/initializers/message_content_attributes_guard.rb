# frozen_string_literal: true

# MESSAGE CONTENT_ATTRIBUTES GUARD
# Normaliza content_attributes no setter: se vier uma String contendo JSON
# (caso observado em 311 rows de Mais Saúde dev em 2026-04-23), converte
# pra Hash antes de persistir. Rails Store com coder: JSON espera Hash —
# quando o valor é string, o jbuilder quebra com "no implicit conversion of
# Hash into String" na renderização.
#
# Write path culpado ainda não identificado. Este guard é defesa em
# profundidade até a origem ser encontrada ou upstream corrigir.

module KlaosMessageContentAttributesGuard
  def content_attributes=(value)
    if value.is_a?(String) && value.start_with?('{')
      parsed = JSON.parse(value) rescue nil
      value = parsed if parsed.is_a?(Hash)
    end
    super(value)
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Message)
  next if Message.include?(KlaosMessageContentAttributesGuard)

  Message.prepend(KlaosMessageContentAttributesGuard)
end
