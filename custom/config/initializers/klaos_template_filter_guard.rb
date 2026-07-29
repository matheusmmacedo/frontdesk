# frozen_string_literal: true

# Guarda de isolamento de templates em WABA COMPARTILHADA.
#
# Contexto: a WABA Klaus (735467396201142) é compartilhada entre Mais Saúde e
# Blue Care. Qualquer sync que leia `/{waba_id}/message_templates` traz os
# templates das DUAS marcas — e o atendente do MS via 15 templates `bluecare_*`
# poluindo a lista de seleção (reportado 29/07 pelo Gustavo).
#
# Por que aqui e não no sync: existem MÚLTIPLOS caminhos que escrevem
# `message_templates`, e filtrar só um deixa os outros repovoando:
#   1. `app/jobs/channels/whatsapp/templates_sync_scheduler_job.rb` (upstream,
#      roda de 3/3h) -> `Channel::Whatsapp#sync_templates` ->
#      `whatsapp_cloud_service.rb:34-38` faz `update(message_templates: ...)`
#      direto da Graph API, SEM filtro. Foi este que repovoou o canal 1.
#   2. `custom/.../meta/template_sync_service.rb#propagate_to_channels` (pool)
#   3. `sync_templates_from_connection` (whatsapp_connection_extensions.rb)
#   4. edição manual / rake / console
#
# O `before_save` cobre os quatro de uma vez: não importa quem escreveu, o que
# fica persistido respeita o filtro. Fail-open: erro no filtro nunca bloqueia o
# save (perder o filtro é ruim; perder o sync inteiro é pior).
#
# Config por canal, em `provider_config['template_filter']` (jsonb):
#   { "prefix_blacklist": ["bluecare_"] }  -> esconde esses prefixos
#   { "prefix_whitelist": ["bluecare_"] }  -> mantém SOMENTE esses prefixos
# Sem config -> passa tudo (backward-compat).
Rails.application.config.after_initialize do
  Channel::Whatsapp.class_eval do
    before_save :klaos_apply_template_filter, if: :will_save_change_to_message_templates?

    private

    def klaos_apply_template_filter
      cfg = provider_config.is_a?(Hash) ? provider_config['template_filter'] : nil
      return if cfg.blank?

      list = message_templates
      return unless list.is_a?(Array) && list.any?

      whitelist = cfg['prefix_whitelist']
      blacklist = cfg['prefix_blacklist']
      filtered = list

      if whitelist.is_a?(Array) && whitelist.any?
        filtered = filtered.select { |t| whitelist.any? { |p| t['name'].to_s.start_with?(p) } }
      end
      if blacklist.is_a?(Array) && blacklist.any?
        filtered = filtered.reject { |t| blacklist.any? { |p| t['name'].to_s.start_with?(p) } }
      end

      return if filtered.size == list.size

      Rails.logger.info(
        "[KlaosTemplateFilter] canal=#{id} #{list.size} -> #{filtered.size} templates " \
        "(removidos: #{(list.map { |t| t['name'] } - filtered.map { |t| t['name'] }).join(', ')})"
      )
      self.message_templates = filtered
    rescue StandardError => e
      # fail-open: nunca impedir o save por causa do filtro
      Rails.logger.error("[KlaosTemplateFilter] falhou no canal=#{id}: #{e.message}")
    end
  end
end
