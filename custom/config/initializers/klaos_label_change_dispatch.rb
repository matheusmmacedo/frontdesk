# frozen_string_literal: true

# KLaOS — Fix bug #699 (P1 BLOQUEIO regua cobranca).
#
# Bug: POST /api/v1/accounts/:acct/conversations/:disp/labels dispara
# `update_labels` -> `update!(label_list: labels)` em Labelable (concern
# compartilhada Contact/AgentBot/Conversation). O gem acts_as_taggable_on 12
# trata `label_list` como VIRTUAL ATTRIBUTE — o dirty tracking do Rails
# (`previous_changes['label_list']`) nao popula de forma consistente em todos
# os cenarios do path HTTP.
#
# Consequencia: em `Conversation#notify_conversation_updation`
# (app/models/conversation.rb:273-277) o guard `previous_changes.keys.present?
# && allowed_keys?` sai cedo -> `dispatch_conversation_updated_event` NUNCA
# eh chamado -> nao ha CONVERSATION_UPDATED -> `WebhookListener` (KLaOS
# HTTP) e `AutomationRuleListener` (regua de automacao) ficam silenciosos.
# Impacto prod: regua de cobranca quebrada.
#
# ============================================================================
# ESTRATEGIA (Rota A — cached_label_list dirty tracking):
# ============================================================================
# `cached_label_list` E COLUNA REAL do schema (db/schema.rb:682, adicionada
# em 20231211010807_add_cached_labels_list.rb) que o acts_as_taggable_on 12
# popula automaticamente quando labels mudam. Como coluna real, o
# `saved_change_to_cached_label_list?` e o `previous_changes['cached_label_list']`
# sao CONFIAVEIS mesmo quando o virtual attr `label_list` nao entra em
# previous_changes.
#
# O patch prependa `Conversation` (nao `Labelable`, pra escopar SOMENTE a
# conversas — Contact/AgentBot ficam intactos) e substitui
# `notify_conversation_updation`. Fluxo:
#
#   1. Consulta `saved_change_to_cached_label_list?` — se falso, delega a
#      super (comportamento upstream inalterado);
#   2. Se `previous_changes['label_list']` JA existir (env dev/happy path
#      do acts_as_taggable), delega a super — evita interferencia;
#   3. Caso contrario (bug #699): reconstroi o par [prev, curr] a partir do
#      cache CSV, faz `previous_changes.merge('label_list' => [prev, curr])`,
#      e chama `dispatch_conversation_updated_event(merged_changes)` UMA vez.
#      NAO chama super — evita dupla emissao quando status+label mudam juntos.
#
# ============================================================================
# COBERTURA DOS CALL-SITES DE `update_labels` (bypass indireto):
# ============================================================================
# O patch fica no callback `notify_conversation_updation` (after_update_commit),
# entao cobre TODAS as chamadas de `update_labels` ou `update!(label_list:)`
# sem precisar interceptar cada call-site. Sitios que se beneficiam:
#   - app/controllers/api/v1/widget/labels_controller.rb:4,13
#   - app/controllers/concerns/label_concern.rb:2-5 (labels_controller HTTP)
#   - app/jobs/bulk_actions_job.rb:57 (bulk label assign)
#   - lib/integrations/openai/conversation_action_service.rb:59 (Captain)
#   - lib/integrations/openai/labels/update_service.rb:7-8 (Captain retag)
#   - qualquer AutomationRule action `add_label`/`remove_label`
#
# ============================================================================
# DEDUPLICACAO (topologia do callback):
# ============================================================================
# `notify_conversation_updation` roda EXATAMENTE UMA VEZ por commit
# (after_update_commit). Nosso override tem dois ramos MUTUAMENTE EXCLUSIVOS:
#   - ramo CUSTOM (label detectada via cache E label_list nao em
#     previous_changes): monta merged_changes e dispara 1 vez — NAO chama
#     super;
#   - ramo SUPER: delega ao original (que decide por conta propria).
# Como ambos os ramos disparam NO MAXIMO 1 CONVERSATION_UPDATED, dedup e
# GARANTIDO por design — nunca 2 dispatches no mesmo commit.
#
# Idempotencia do initializer: `include?` retorna true apos prepend (modulo
# esta no ancestor chain). Segundo run do `to_prepare` (reload dev/asset
# precompile) NAO reprepend.

module KlaosLabelChangeDispatch
  # `notify_conversation_updation` e privado em Conversation. Mantemos
  # a mesma visibilidade aqui — super atravessa a chain independente
  # de visibilidade.
  private

  def notify_conversation_updation
    label_pair = klaos_label_change_from_cache

    # Sem mudanca de label detectada via cache — deixa o fluxo original
    # decidir (pode ter status/assignee change que dispara upstream).
    return super if label_pair.nil?

    # Se `label_list` virtual attr JA esta em previous_changes (env dev
    # onde acts_as_taggable populou corretamente), delega a super. Super
    # dispara com o previous_changes nativo que ja inclui label_list.
    # Nosso ramo custom EXISTE somente pra fechar o gap do bug #699.
    return super if previous_changes.key?('label_list')

    # Bug #699 confirmado: cache mudou mas label_list nao entrou em
    # previous_changes. Injeta a chave e dispara UMA vez com merge —
    # cobre cenario status+label junto sem duplicar (nao chamamos super).
    #
    # `except('cached_label_list')`: evita vazar a coluna cache raw no payload
    # webhook (base_listener#extract_changed_attributes mapeia todas as chaves).
    # Consumer KLaOS espera `label_list` semântico, não `cached_label_list` CSV.
    merged_changes = previous_changes.except('cached_label_list').merge('label_list' => label_pair)

    Rails.logger.info(
      "[KlaosLabelChangeDispatch] fallback triggered conv=#{id} " \
      "prev=#{label_pair[0].inspect} curr=#{label_pair[1].inspect}"
    )

    dispatch_conversation_updated_event(merged_changes)
  end

  # Reconstroi o par [prev_labels_array, curr_labels_array] a partir da
  # coluna cache `cached_label_list` (formato CSV). Retorna nil se:
  #   - a coluna nao existe (merge upstream removeu — guard defensivo);
  #   - nao houve saved_change no cache (nada mudou nesta commit);
  #   - os arrays parseados sao iguais (edge case ordem/whitespace).
  def klaos_label_change_from_cache
    # Defesa contra remocao futura da coluna cache num merge upstream.
    # Deixa de aplicar silenciosamente em vez de crashar.
    return nil unless respond_to?(:saved_change_to_cached_label_list?)
    return nil unless saved_change_to_cached_label_list?

    prev_cached, curr_cached = saved_change_to_cached_label_list
    prev_labels = klaos_parse_cached(prev_cached)
    curr_labels = klaos_parse_cached(curr_cached)

    # No-op safety: se parse retorna arrays iguais (edge case ordem/
    # whitespace/duplicatas em cache historico), aborta em vez de
    # emitir CONVERSATION_UPDATED com delta vazio.
    #
    # Comparação por sort.uniq (não estrita): evita dispatch espúrio quando
    # bulk_action reordena labels (mesmo set, ordem diferente). Sem isso, régua
    # de cobrança do consumer pode disparar em ciclo indevido em cada save.
    return nil if prev_labels.sort.uniq == curr_labels.sort.uniq

    [prev_labels, curr_labels]
  end

  # acts_as_taggable_on 12 serializa em CSV simples. Labels do Chatwoot
  # nao permitem virgula no titulo (validacao no Label model), entao
  # split(',') + strip + reject(&:blank?) e suficiente.
  def klaos_parse_cached(cached)
    return [] if cached.blank?

    cached.to_s.split(',').map(&:strip).reject(&:blank?)
  end
end

Rails.application.config.to_prepare do
  # safe_constantize forca autoload Zeitwerk — `defined?` nao e confiavel
  # em Rails 7 com classes lazy-load.
  conversation_class = 'Conversation'.safe_constantize
  next if conversation_class.nil?
  next if conversation_class.include?(KlaosLabelChangeDispatch)

  conversation_class.prepend(KlaosLabelChangeDispatch)
  Rails.logger.info '[KlaosLabelChangeDispatch] prepended on Conversation (fix #699)'
end
