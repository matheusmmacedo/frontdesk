# frozen_string_literal: true

require 'rails_helper'

# Cobre o initializer custom/config/initializers/klaos_label_change_dispatch.rb
# (fix bug #699 — POST /labels nao dispara CONVERSATION_UPDATED).
#
# Contratos verificados:
#   - label-only update -> UMA dispatch com 'label_list' no changed_attributes
#   - status+label juntos -> UMA dispatch com AMBAS as chaves (dedup topologico)
#   - labels idempotentes (mesma lista) -> ZERO dispatch adicional
#   - status-only (sem label) -> UMA dispatch sem injetar 'label_list'
RSpec.describe 'KlaosLabelChangeDispatch (fix #699)' do
  let!(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account) }

  before do
    create(:inbox_member, inbox: conversation.inbox, user: agent)
    Current.user = agent
    allow(Rails.configuration.dispatcher).to receive(:dispatch)
  end

  after do
    Current.user = nil
    Current.account = nil
  end

  describe 'label-only update via #update_labels' do
    it 'dispatches CONVERSATION_UPDATED exactly once with label_list in changed_attributes' do
      conversation.update_labels(['bug'])

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(
            conversation: conversation,
            changed_attributes: hash_including('label_list' => [[], ['bug']])
          )
        ).once
    end

    it 'reflects add + remove diff via label_list pair when relabeling' do
      conversation.update_labels(['bug'])
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      conversation.update_labels(['urgent'])

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(
            changed_attributes: hash_including('label_list' => [['bug'], ['urgent']])
          )
        ).once
    end
  end

  describe 'status + label_list changing in the same request' do
    it 'dispatches CONVERSATION_UPDATED exactly once with BOTH status and label_list keys' do
      conversation.update!(status: :resolved, label_list: ['bug'])

      # Dedup topologico: um unico CONVERSATION_UPDATED com ambos os deltas.
      # Impede que fix crie evento paralelo alem do que o callback natural
      # ja dispararia (que iria dispatch em cima do status change).
      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(
            conversation: conversation,
            changed_attributes: hash_including('status', 'label_list')
          )
        ).once
    end
  end

  describe 'idempotent label update (same list)' do
    it 'does NOT dispatch a second CONVERSATION_UPDATED when labels are unchanged' do
      # Primeiro update firma as labels — dispatch legitimo aqui.
      conversation.update_labels(['bug'])
      # Reset spy para so contar dispatches DO segundo update.
      allow(Rails.configuration.dispatcher).to receive(:dispatch)

      # Idempotente: cache nao muda, saved_change_to_cached_label_list? false,
      # nosso ramo custom retorna nil -> super -> super nao dispara porque
      # previous_changes nao tem chaves whitelisted.
      conversation.update_labels(['bug'])

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
        .with(Conversation::CONVERSATION_UPDATED, any_args)
    end
  end

  describe 'status-only update (no label change)' do
    it 'dispatches CONVERSATION_UPDATED without injecting label_list synthetically' do
      conversation.update!(status: :resolved)

      # Fix NAO deve inventar chave label_list quando nada mudou.
      # Super lida naturalmente com previous_changes['status'].
      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(
            conversation: conversation,
            changed_attributes: hash_including('status')
          )
        ).once

      # Assercao complementar: nao emitiu label_list.
      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(changed_attributes: hash_including('label_list'))
        )
    end
  end

  # Specs que EXERCITAM o ramo custom (fecha defeito HIGH do critic — sem esses
  # os 4 cenarios acima passavam com OU sem o initializer, tornando a suite
  # inutil como regressao).
  describe 'CUSTOM branch (bug #699 vector — previous_changes SEM label_list)' do
    it 'injects label_list synthetically when acts_as_taggable NAO populou previous_changes' do
      # Forca cenario do bug: cache mudou mas label_list virtual attr NAO entrou.
      allow(conversation).to receive(:previous_changes)
        .and_wrap_original { |m, *args| m.call(*args).except('label_list') }
      allow(conversation).to receive(:saved_change_to_cached_label_list?).and_return(true)
      allow(conversation).to receive(:saved_change_to_cached_label_list).and_return([nil, 'bug'])

      # Trigger callback manual (equivale a after_update_commit).
      conversation.send(:notify_conversation_updation)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          hash_including(
            changed_attributes: hash_including('label_list' => [[], ['bug']])
          )
        ).once
    end

    it 'does NOT leak cached_label_list into payload (RC critic — payload pollution)' do
      allow(conversation).to receive(:previous_changes)
        .and_wrap_original { |m, *args| m.call(*args).except('label_list').merge('cached_label_list' => [nil, 'bug']) }
      allow(conversation).to receive(:saved_change_to_cached_label_list?).and_return(true)
      allow(conversation).to receive(:saved_change_to_cached_label_list).and_return([nil, 'bug'])

      conversation.send(:notify_conversation_updation)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch)
        .with(
          Conversation::CONVERSATION_UPDATED,
          kind_of(Time),
          satisfy { |kw| !kw[:changed_attributes].key?('cached_label_list') }
        )
    end

    it 'does NOT dispatch when labels reorder but set is the same (RC critic — spurious dispatch guard)' do
      allow(conversation).to receive(:saved_change_to_cached_label_list?).and_return(true)
      # sort.uniq de ambos = ['bug','urgent'] — mesmo set, so ordem inverteu.
      allow(conversation).to receive(:saved_change_to_cached_label_list).and_return(['urgent,bug', 'bug,urgent'])
      allow(conversation).to receive(:previous_changes)
        .and_wrap_original { |m, *args| m.call(*args).except('label_list') }

      conversation.send(:notify_conversation_updation)

      expect(Rails.configuration.dispatcher).not_to have_received(:dispatch)
        .with(Conversation::CONVERSATION_UPDATED, any_args)
    end
  end
end
