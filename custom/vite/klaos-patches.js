/**
 * KLaOS custom patches — Vite transform plugin
 *
 * Aplica patches cirúrgicos em arquivos upstream do Chatwoot sem modificar
 * os arquivos. Mantém o diff do fork mínimo e detectável em merges.
 *
 * Cada patch é um par `[from, to]` de strings literais. Se `from` não
 * aparecer exatamente no arquivo-alvo, o build **falha** — sinal claro de
 * que o upstream mudou a linha e o patch precisa ser atualizado.
 *
 * Uso: importado no vite.config.ts e registrado em `plugins`.
 */

/**
 * @typedef {Object} Patch
 * @property {string} id — substring que identifica o arquivo-alvo (match por id.endsWith)
 * @property {string} from — string literal a ser encontrada (deve ser única no arquivo)
 * @property {string} to — substituição
 * @property {string} reason — motivo humano (aparece no log)
 */

/** @type {Patch[]} */
const PATCHES = [
  {
    id: '/components-next/filter/provider.js',
    from: "['open', 'resolved', 'pending', 'snoozed', 'all']",
    to: "['active', 'open', 'resolved', 'pending', 'snoozed', 'all']",
    reason: 'expose "Ativas" pseudo-status in advanced filter modal',
  },
  {
    id: '/components/ChatList.vue',
    from: 'const activeStatus = ref(wootConstants.STATUS_TYPE.OPEN);',
    to: 'const activeStatus = ref(wootConstants.STATUS_TYPE.ACTIVE);',
    reason: 'default chat status filter to ACTIVE on first mount',
  },
  {
    id: '/components/ChatList.vue',
    from: 'activeStatus.value = status || wootConstants.STATUS_TYPE.OPEN;',
    to: 'activeStatus.value = status || wootConstants.STATUS_TYPE.ACTIVE;',
    reason: 'default chat status filter to ACTIVE when uiSettings empty',
  },
  {
    id: '/widgets/conversation/ConversationBasicFilter.vue',
    from: 'return chatStatusFilter.value || wootConstants.STATUS_TYPE.OPEN;',
    to: 'return chatStatusFilter.value || wootConstants.STATUS_TYPE.ACTIVE;',
    reason: 'default basic filter to ACTIVE when no saved filter',
  },
  {
    id: '/widgets/conversation/ConversationBasicFilter.vue',
    from: `const chatStatusOptions = computed(() => [
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
    value: 'open',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
    value: 'resolved',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
    value: 'pending',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
    value: 'snoozed',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'),
    value: 'all',
  },
]);`,
    to: `const chatStatusOptions = computed(() => [
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.active.TEXT'),
    value: 'active',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT'),
    value: 'open',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT'),
    value: 'pending',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT'),
    value: 'snoozed',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.resolved.TEXT'),
    value: 'resolved',
  },
  {
    label: t('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.all.TEXT'),
    value: 'all',
  },
]);`,
    reason: 'prepend "Ativas" and reorder basic filter options',
  },
  {
    id: '/settings/settings.routes.js',
    from: "import whatsappConnections from './whatsappConnections/whatsappConnections.routes';",
    to: "import whatsappConnections from './whatsappConnections/whatsappConnections.routes';\nimport klaosMessagePrefix from './klaosMessagePrefix/klaosMessagePrefix.routes';",
    reason: 'register KLaOS message prefix settings route import',
  },
  {
    id: '/settings/settings.routes.js',
    from: '...whatsappConnections.routes,\n  ],\n};',
    to: '...whatsappConnections.routes,\n    ...klaosMessagePrefix.routes,\n  ],\n};',
    reason: 'register KLaOS message prefix routes in settings route array',
  },
  {
    id: '/sidebar/Sidebar.vue',
    from: `        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },`,
    to: `        {
          name: 'Settings Account Settings',
          label: t('SIDEBAR.ACCOUNT_SETTINGS'),
          icon: 'i-lucide-briefcase',
          to: accountScopedRoute('general_settings_index'),
        },
        {
          name: 'Settings KLaOS Message Prefix',
          label: 'Formato do Nome',
          icon: 'i-lucide-id-card',
          to: accountScopedRoute('klaos_message_prefix_index'),
        },`,
    reason: 'add Formato do Nome (KLaOS message prefix) entry in settings sidebar',
  },

  // === KLaOS — "Devolver ao bot" como botão visível + visibilidade correta ===
  // Por que existe: o estado pré-session (b8ecaf61f) deixava o botão dentro do
  // dropdown e usava só `meta.assignee?.id` como gate. Faltava: (a) sair do
  // dropdown pra UX visível, (b) checar se a inbox tem agent_bot configurado
  // (sem isso o clique deixa a conv órfã em pending), (c) cobrir atribuição
  // só-pra-time (chat.team_id) e variantes (assignee_id top-level).
  {
    id: '/components/buttons/ResolveAction.vue',
    from: "import { ref, computed } from 'vue';",
    to: "import { ref, computed, watch } from 'vue';",
    reason: 'devolver-ao-bot: import watch para reagir a inbox change',
  },
  {
    id: '/components/buttons/ResolveAction.vue',
    from: `// KLaOS custom — botão "Devolver ao bot" aparece em convs com humano atribuído.
// Backend valida se faz sentido de fato devolver (inbox com bot). Se não tem bot,
// conv fica pending e o admin resolve manualmente.
const showTransferToBot = computed(
  () => currentChat.value?.meta?.assignee?.id != null
);`,
    to: `// KLaOS custom — "Devolver ao bot" aparece quando a inbox tem agent_bot
// configurado E há atribuição manual (assignee, team via meta, ou team_id no
// top-level). Atribuição-só-pra-time (sem assignee) também conta — admin
// pode atribuir só pro time e ainda querer devolver pro bot. Inbox sem bot
// esconde o botão pra evitar conv órfã em pending.
const inboxId = computed(() => currentChat.value?.inbox_id);

// Lazy fetch — agentBotInbox só é populado sob demanda. Dispara quando a
// conversa selecionada muda de inbox.
watch(
  inboxId,
  newId => {
    if (newId) store.dispatch('agentBots/fetchAgentBotInbox', newId);
  },
  { immediate: true }
);

// Checa o map agentBotInbox direto via store.state. fetchAgentBotInbox popula
// só este map (inbox_id → bot_id), NÃO carrega a lista completa de bots em
// records. getActiveAgentBot depende de records (que pode estar vazio em
// fluxos onde a tela de settings de bots nunca foi visitada), então retornava
// {} mesmo com a inbox tendo bot. Aqui basta saber que o id existe — não
// precisamos dos detalhes do bot.
const inboxHasBot = computed(() => {
  const id = inboxId.value;
  if (!id) return false;
  const map = store.state.agentBots?.agentBotInbox || {};
  return Boolean(map[Number(id)]);
});

const hasManualAssignment = computed(() => {
  const chat = currentChat.value;
  return (
    Boolean(chat?.meta?.assignee?.id) ||
    Boolean(chat?.assignee_id) ||
    Boolean(chat?.meta?.team?.id) ||
    Boolean(chat?.team_id)
  );
});

const showTransferToBot = computed(
  () => inboxHasBot.value && hasManualAssignment.value
);`,
    reason: 'devolver-ao-bot: visibility gate amplo (inbox bot + atribuição manual)',
  },
  {
    // Tira a entrada do dropdown — botão agora vive visível ao lado do Resolver.
    id: '/components/buttons/ResolveAction.vue',
    from: `        <WootDropdownItem v-if="showTransferToBot">
          <Button
            :label="t('CONVERSATION.RESOLVE_DROPDOWN.TRANSFER_TO_BOT')"
            ghost
            slate
            sm
            start
            icon="i-lucide-bot"
            class="w-full"
            @click="transferToBot"
          />
        </WootDropdownItem>
`,
    to: '',
    reason: 'devolver-ao-bot: remove do dropdown (vai virar botão visível)',
  },
  {
    // Adiciona botão visível ANTES do ButtonGroup, dentro do mesmo container flex.
    id: '/components/buttons/ResolveAction.vue',
    from: `  <div class="flex relative justify-end items-center resolve-actions">
    <ButtonGroup`,
    to: `  <div class="flex relative justify-end items-center resolve-actions">
    <Button
      v-if="showTransferToBot"
      :label="t('CONVERSATION.RESOLVE_DROPDOWN.TRANSFER_TO_BOT')"
      icon="i-lucide-bot"
      size="sm"
      color="slate"
      class="mr-3 outline outline-1 outline-n-container shadow rounded-lg"
      :is-loading="isLoading"
      :disabled="isLoading"
      @click="transferToBot"
    />
    <ButtonGroup`,
    reason: 'devolver-ao-bot: botão visível ao lado do Resolver',
  },

  // === KLaOS — "Minhas" sticky contra broadcasts transientes do bot ===
  // Sintoma: durante o sequenciamento KLaOS (assign user → reopen → bot reply
  // → team change), a conv aparecia/sumia da aba "Minhas" do agente. Causa:
  // o backend EventDataPresenter#push_meta usa `assigned_entity = assignee_agent_bot
  // || assignee` (BOT-first). Se o broadcast carrega `meta.assignee = AgentBot`
  // mesmo por um instante (cache de associação ou estado intermediário), o
  // getter compara `assignee.id` (do bot) com `currentUserID` (do agente) e
  // o conv sai da Minhas. Quando próximo broadcast traz user, volta.
  //
  // Fix defensivo: na "Minhas", só conta atribuição quando assignee_type === 'User'.
  // Se vier um broadcast com assignee_type='AgentBot' (transiente do bot), a conv
  // permanece com o estado cached do store — não é removida por causa de um flash.
  // Combina com a lógica existente: o reducer já ignora out-of-order via updated_at.
  {
    id: '/store/modules/conversations/getters.js',
    from: `      const { assignee } = conversation.meta;
      const isAssignedToMe = assignee && assignee.id === currentUserID;`,
    to: `      const { assignee, assignee_type: assigneeType } = conversation.meta;
      const isAssignedToMe =
        assignee && assignee.id === currentUserID && assigneeType !== 'AgentBot';`,
    reason: 'minhas-sticky: ignora broadcasts transientes com assignee_type=AgentBot',
  },

  // === KLaOS — "Não atribuídas" considera AgentBot como unassigned ===
  // Sintoma: aba "Não atribuídas" trava em "Carregando conversas" e dispara
  // loop infinito de fetches `?assignee_type=unassigned` (centenas/segundo).
  //
  // Causa: o backend filtra unassigned por `assignee_id IS NULL` (sem humano),
  // mas o EventDataPresenter#push_meta popula `meta.assignee` com o BOT da
  // inbox quando não há humano (BOT-first). Frontend `getUnAssignedChats` usa
  // `!conversation.meta.assignee` — como tem bot, filtra fora → chatsOnView=[].
  // O `conversationListPagination` vê lista vazia + count>0 → retorna page=1
  // perpetuamente. IntersectionObserver no sentinel detecta vazio → dispara
  // loadMoreConversations → fetchConversations → loop infinito.
  //
  // Fix: tratar conversa com assignee_type='AgentBot' como unassigned (porque
  // pra todos os efeitos do dashboard humano, é). Espelha o conceito do backend.
  {
    id: '/store/modules/conversations/getters.js',
    from: `  getUnAssignedChats: _state => activeFilters => {
    return _state.allConversations.filter(conversation => {
      const isUnAssigned = !conversation.meta.assignee;
      const shouldFilter = applyPageFilters(conversation, activeFilters);
      return isUnAssigned && shouldFilter;
    });
  },`,
    to: `  getUnAssignedChats: _state => activeFilters => {
    return _state.allConversations.filter(conversation => {
      const { assignee, assignee_type: assigneeType } = conversation.meta;
      const isUnAssigned = !assignee || assigneeType === 'AgentBot';
      const shouldFilter = applyPageFilters(conversation, activeFilters);
      return isUnAssigned && shouldFilter;
    });
  },`,
    reason: 'unassigned-treat-bot-as-unassigned: backend filtra unassigned por assignee_id IS NULL mas meta.assignee vem com bot — sem isso list fica vazia e UI loopa fetch infinito',
  },

  // === KLaOS — Toggle "assinatura do atendente" (prefixo *Atendente NOME*:) no composer ===
  // Backend `klaos_apply_human_prefix` (custom/config/initializers/human_message_prefix.rb)
  // prepende a string configurada em accounts.custom_attributes.klaos_human_message_template
  // em toda mensagem outgoing humana. Esse toggle permite ao atendente DESLIGAR o prefixo
  // numa mensagem específica sem alterar a config da account — útil quando o agente vai
  // copiar/colar texto formatado, mandar link cru, ou se identificar de forma diferente.
  //
  // Estado: per-component (data() em ReplyBox), default ON, ephemeral (reseta ao navegar).
  // Quando OFF, getMessagePayload injeta `contentAttributes: { skip_klaos_prefix: true }`
  // no payload — o initializer lê isso no before_create e pula o prepend.
  //
  // Botão fica ao lado do signature toggle no ReplyBottomPanel. Solid quando ON, faded OFF.
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: [
    'replaceText',
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'toggleQuotedReply',
  ],`,
    to: `    isEditorDisabled: {
      type: Boolean,
      default: false,
    },
    klaosPrefixEnabled: {
      type: Boolean,
      default: true,
    },
  },
  emits: [
    'replaceText',
    'toggleInsertArticle',
    'selectWhatsappTemplate',
    'selectContentTemplate',
    'toggleQuotedReply',
    'toggleKlaosPrefix',
  ],`,
    reason: 'klaos-prefix-toggle: registra prop klaosPrefixEnabled + emit toggleKlaosPrefix no ReplyBottomPanel',
  },
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `      <NextButton
        v-if="showMessageSignatureButton"
        v-tooltip.top-end="signatureToggleTooltip"
        icon="i-ph-signature"
        slate
        faded
        sm
        @click="toggleMessageSignature"
      />`,
    to: `      <NextButton
        v-if="showMessageSignatureButton"
        v-tooltip.top-end="signatureToggleTooltip"
        icon="i-ph-signature"
        slate
        faded
        sm
        @click="toggleMessageSignature"
      />
      <NextButton
        v-if="!isOnPrivateNote && !isEditorDisabled"
        v-tooltip.top-end="klaosPrefixEnabled ? 'Desativar assinatura *Atendente NOME*' : 'Ativar assinatura *Atendente NOME*'"
        icon="i-ph-user-bold"
        :variant="klaosPrefixEnabled ? 'solid' : 'faded'"
        color="slate"
        sm
        :aria-pressed="klaosPrefixEnabled"
        @click="$emit('toggleKlaosPrefix')"
      />`,
    reason: 'klaos-prefix-toggle: botão do toggle ao lado do signature button',
  },
  {
    id: '/components/widgets/conversation/ReplyBox.vue',
    from: `      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
    };
  },`,
    to: `      newConversationModalActive: false,
      showArticleSearchPopover: false,
      hasRecordedAudio: false,
      copilotAcceptedMessages: {},
      // KLaOS — per-message toggle pro prefixo "*Atendente NOME*: ". Default ON.
      // Quando OFF, getMessagePayload injeta content_attributes.skip_klaos_prefix=true
      // e o initializer human_message_prefix.rb pula o prepend.
      klaosPrefixEnabled: true,
    };
  },`,
    reason: 'klaos-prefix-toggle: state local em ReplyBox.data()',
  },
  {
    id: '/components/widgets/conversation/ReplyBox.vue',
    from: `        :is-editor-disabled="isEditorDisabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"`,
    to: `        :is-editor-disabled="isEditorDisabled"
        :klaos-prefix-enabled="klaosPrefixEnabled"
        :on-file-upload="onFileUpload"
        :on-send="onSendReply"`,
    reason: 'klaos-prefix-toggle: passa state como prop pro ReplyBottomPanel',
  },
  {
    id: '/components/widgets/conversation/ReplyBox.vue',
    from: `        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @replace-text="replaceText"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
      />`,
    to: `        @select-whatsapp-template="openWhatsappTemplateModal"
        @select-content-template="openContentTemplateModal"
        @replace-text="replaceText"
        @toggle-insert-article="toggleInsertArticle"
        @toggle-quoted-reply="toggleQuotedReply"
        @toggle-klaos-prefix="klaosPrefixEnabled = !klaosPrefixEnabled"
      />`,
    reason: 'klaos-prefix-toggle: listener que flipa o state local',
  },
  {
    // Patcheia o chokepoint sendMessage — cobre TODOS os caminhos que constroem
    // payload (getMessagePayload pra email/non-WA, getMultipleMessagesPayload pra
    // WhatsApp/IG/Tiktok). Sem isso, no caminho WA o flag nunca é injetado.
    id: '/components/widgets/conversation/ReplyBox.vue',
    from: `    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );`,
    to: `    async sendMessage(
      messagePayload,
      editorMessage = '',
      copilotAcceptedMessage = ''
    ) {
      // KLaOS — quando o toggle de "assinatura do atendente" está OFF, sinaliza
      // pro backend (klaos_apply_human_prefix) pular o prepend. Aqui é o
      // chokepoint comum a todos os caminhos (WA, IG, Tiktok, email, multi-msg).
      // Mensagens privadas não recebem prefix de qualquer forma — não precisa
      // setar o flag, mas não atrapalha (initializer trata).
      if (!this.klaosPrefixEnabled && !messagePayload.private) {
        messagePayload.contentAttributes = {
          ...(messagePayload.contentAttributes || {}),
          skip_klaos_prefix: true,
        };
      }
      try {
        await this.$store.dispatch(
          'createPendingMessageAndSend',
          messagePayload
        );`,
    reason: 'klaos-prefix-toggle: injeta skip_klaos_prefix no chokepoint sendMessage (cobre WA/IG/Tiktok/email)',
  },

  // === KLaOS — alerta sonoro quando conv eh atribuida ao agente logado ===
  // Hoje o som só toca em mensagem nova; quando uma conv é atribuída sem msg
  // nova (ex: bot transferiu, time auto-assignou, outro atendente moveu), o
  // atendente não tinha sinal sonoro de "tem uma conv pra você".
  {
    id: '/helper/actionCable.js',
    from: `  onAssigneeChanged = payload => {
    const { id } = payload;
    if (id) {
      this.app.$store.dispatch('updateConversation', payload);
    }
    this.fetchConversationStats();
  };`,
    to: `  onAssigneeChanged = payload => {
    const { id } = payload;
    if (id) {
      this.app.$store.dispatch('updateConversation', payload);
      DashboardAudioNotificationHelper.onAssigneeChanged(payload);
    }
    this.fetchConversationStats();
  };`,
    reason: 'audio-assignee: dispara handler de som no evento assignee.changed',
  },
  {
    id: '/AudioAlerts/DashboardAudioNotificationHelper.js',
    from: `  onNewMessage = message => {`,
    to: `  // KLaOS custom: toca som quando uma conversa é atribuída ao agente logado
  // (independente de quem fez a atribuição — bot, auto-assign, outro humano).
  // Respeita o toggle geral (audioAlertType !== 'none') e o "only when hidden"
  // pra não bombar o atendente quando ele está olhando o dashboard.
  onAssigneeChanged = payload => {
    if (!this.currentUser) return;

    const { audioAlertType, playAlertOnlyWhenHidden } = this.notificationConfig;
    if (audioAlertType.includes('none')) return;

    const newAssigneeId = payload?.meta?.assignee?.id;
    if (!newAssigneeId || newAssigneeId !== this.currentUser.id) return;

    if (
      WindowVisibilityHelper.isWindowVisible() &&
      playAlertOnlyWhenHidden
    ) {
      return;
    }

    this.playAudioAlert();
    showBadgeOnFavicon();
  };

  onNewMessage = message => {`,
    reason: 'audio-assignee: handler que toca som quando assignee.id == currentUser.id',
  },
  {
    id: '/whatsappConnections/components/TemplateManager.vue',
    from: `                <span
                  class="text-xs text-n-slate-9 bg-n-alpha-1 px-1.5 py-0.5 rounded"
                >
                  {{ tmpl.category }}
                </span>`,
    to: `                <span
                  class="text-xs px-1.5 py-0.5 rounded"
                  :class="{
                    'text-n-blue-11 bg-n-blue-3': tmpl.category === 'UTILITY',
                    'text-n-amber-11 bg-n-amber-3 font-semibold': tmpl.category === 'MARKETING',
                    'text-n-teal-11 bg-n-teal-3': tmpl.category === 'AUTHENTICATION',
                    'text-n-slate-9 bg-n-alpha-1': !['UTILITY','MARKETING','AUTHENTICATION'].includes(tmpl.category),
                  }"
                  :title="tmpl.category === 'MARKETING' ? 'MARKETING: requer opt-in. Risco de bloqueio da WABA se enviado em régua de cobrança.' : tmpl.category"
                >
                  <span v-if="tmpl.category === 'MARKETING'">⚠ </span>{{ tmpl.category }}
                </span>`,
    reason: 'template-category-badge: cor distinta UTILITY (n-blue) vs MARKETING (n-amber+aviso); usa tokens n-* do design system Chatwoot pra Tailwind JIT gerar CSS',
  },
  {
    id: '/store/modules/labels.js',
    from: `  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isDeleting: false,
  },`,
    to: `  uiFlags: {
    isFetching: false,
    isFetchingItem: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },`,
    reason: 'labels-store: adiciona isUpdating no state inicial (usado em EditLabel.vue, ausente fazia binding ficar undefined)',
  },
  {
    id: '/settings/labels/Index.vue',
    from: `import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';`,
    to: `import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { picoSearch } from '@scmmishra/pico-search';`,
    reason: 'labels-admin-only: importa useAdmin pra esconder edit/delete pra agente comum',
  },
  {
    id: '/settings/labels/Index.vue',
    from: `const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();`,
    to: `const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();`,
    reason: 'labels-admin-only: instancia composable useAdmin no setup',
  },
  {
    id: '/settings/labels/Index.vue',
    from: `              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('LABEL_MGMT.FORM.EDIT')"`,
    to: `              <BaseTableCell align="end">
                <div v-if="isAdmin" class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('LABEL_MGMT.FORM.EDIT')"`,
    reason: 'labels-admin-only: esconde botões edit/delete pra não-admin (LabelPolicy backend exige administrator)',
  },

  // === KLaOS — Labels coloridas em ContactsCard (lista /contacts) ===
  // Backend: custom/app/views/api/v1/models/_contact.json.jbuilder expõe `labels`
  // (label_list do acts_as_taggable). camelcaseKeys do store mantém como `labels`.
  // Aqui passamos pra ContactsCard, que renderiza as chips coloridas cruzando
  // com o store de account labels (cor + título).
  {
    id: '/Contacts/Pages/ContactsList.vue',
    from: `        :additional-attributes="contact.additionalAttributes"
        :availability-status="contact.availabilityStatus"`,
    to: `        :additional-attributes="contact.additionalAttributes"
        :availability-status="contact.availabilityStatus"
        :labels="contact.labels || []"`,
    reason: 'contact-labels: passa labels do contato pro ContactsCard',
  },
  {
    id: '/Contacts/ContactsCard/ContactsCard.vue',
    from: `import countries from 'shared/constants/countries';`,
    to: `import countries from 'shared/constants/countries';
import { useMapGetter } from 'dashboard/composables/store';`,
    reason: 'contact-labels: import store getter pra resolver cor das labels',
  },
  {
    id: '/Contacts/ContactsCard/ContactsCard.vue',
    from: `  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});`,
    to: `  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
  labels: { type: Array, default: () => [] },
});

// KLaOS — resolve cor + title das labels do contato cruzando com o store de
// account labels. Se a label estiver no contato mas não no account (label deletada),
// renderiza fallback cinza com o nome bruto pra não esconder informação.
const accountLabels = useMapGetter('labels/getLabels');
const klaosResolvedLabels = computed(() => {
  const titles = props.labels || [];
  const all = accountLabels.value || [];
  return titles.map(title => {
    const match = all.find(l => l.title === title);
    return match
      ? { title: match.title, color: match.color }
      : { title, color: '#94a3b8' };
  });
});`,
    reason: 'contact-labels: prop labels + resolução de cor pelo store',
  },
  {
    id: '/Contacts/ContactsCard/ContactsCard.vue',
    from: `            <Button
              :label="t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS')"
              variant="link"
              size="xs"
              @click="onClickViewDetails"
            />
          </div>
        </div>`,
    to: `            <Button
              :label="t('CONTACTS_LAYOUT.CARD.VIEW_DETAILS')"
              variant="link"
              size="xs"
              @click="onClickViewDetails"
            />
          </div>
          <div
            v-if="klaosResolvedLabels.length"
            class="flex flex-wrap items-center gap-1.5 mt-1.5"
          >
            <span
              v-for="lbl in klaosResolvedLabels"
              :key="lbl.title"
              class="inline-flex items-center gap-1 px-2 h-5 rounded-md text-xs font-medium bg-n-alpha-1 text-n-slate-12"
            >
              <span
                class="size-2 rounded-sm flex-shrink-0"
                :style="{ background: lbl.color }"
              />
              {{ lbl.title }}
            </span>
          </div>
        </div>`,
    reason: 'contact-labels: chips coloridas (dot + título) abaixo do email/phone',
  },

  // === KLaOS — Labels da conversa + link editar contato no ConversationHeader ===
  // No header da conversa (topo do painel central), exibe:
  //   1. Nome do contato como link → /contacts/:id (página de edição completa)
  //   2. Chips coloridas das labels da conversa (chat.labels) ao lado do InboxName
  //
  // Cor resolvida cruzando chat.labels (array de strings) com store labels/getLabels
  // (lista de account labels com {title, color}). Fallback cinza se label foi removida.
  {
    id: '/widgets/conversation/ConversationHeader.vue',
    from: `import { useInbox } from 'dashboard/composables/useInbox';
import { useI18n } from 'vue-i18n';`,
    to: `import { useInbox } from 'dashboard/composables/useInbox';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';`,
    reason: 'conv-header-labels: import store getter pra resolver cor das labels',
  },
  {
    id: '/widgets/conversation/ConversationHeader.vue',
    from: `const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);
</script>`,
    to: `const hasSlaPolicyId = computed(() => props.chat?.sla_policy_id);

// KLaOS — link "editar contato" no nome do contato + chips coloridas das labels da conv
const klaosContactEditRoute = computed(() => ({
  name: 'contacts_edit',
  params: {
    accountId: accountId.value,
    contactId: props.chat?.meta?.sender?.id,
  },
}));

const klaosAccountLabels = useMapGetter('labels/getLabels');
const klaosConversationLabels = computed(() => {
  const titles = Array.isArray(props.chat?.labels) ? props.chat.labels : [];
  const all = klaosAccountLabels.value || [];
  return titles.map(title => {
    const match = all.find(l => l.title === title);
    return match
      ? { title: match.title, color: match.color }
      : { title, color: '#94a3b8' };
  });
});
</script>`,
    reason: 'conv-header-labels: computed pra rota de edição + labels resolvidas',
  },
  {
    id: '/widgets/conversation/ConversationHeader.vue',
    from: `        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <span
            class="text-sm font-medium truncate leading-tight text-n-slate-12"
          >
            {{ currentContact.name }}
          </span>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
        </div>`,
    to: `        <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
          <router-link
            v-tooltip.bottom="'Editar dados do contato'"
            :to="klaosContactEditRoute"
            class="text-sm font-medium truncate leading-tight text-n-slate-12 hover:text-n-brand hover:underline"
          >
            {{ currentContact.name }}
          </router-link>
          <fluent-icon
            v-if="!isHMACVerified"
            v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
            size="14"
            class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
            icon="warning"
          />
        </div>`,
    reason: 'conv-header-edit-link: nome do contato vira link pro /contacts/:id (editar dados)',
  },
  {
    id: '/widgets/conversation/ConversationHeader.vue',
    from: `        <div
          class="flex items-center gap-2 overflow-hidden text-xs conversation--header--actions text-ellipsis whitespace-nowrap"
        >
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
        </div>`,
    to: `        <div
          class="flex items-center gap-2 overflow-hidden text-xs conversation--header--actions text-ellipsis whitespace-nowrap"
        >
          <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
          <span v-if="isSnoozed" class="font-medium text-n-amber-10">
            {{ snoozedDisplayText }}
          </span>
          <span
            v-for="lbl in klaosConversationLabels"
            :key="lbl.title"
            class="inline-flex items-center gap-1 px-1.5 h-5 rounded-md font-medium bg-n-alpha-1 text-n-slate-12"
          >
            <span
              class="size-1.5 rounded-sm flex-shrink-0"
              :style="{ background: lbl.color }"
            />
            {{ lbl.title }}
          </span>
        </div>`,
    reason: 'conv-header-labels: chips coloridas (dot + título) ao lado do InboxName',
  },

  // === KLaOS — Timeline unificada do contato (toggle no ConversationBox) ===
  // Caminho B do design "todas as convs em uma única view": injeta um toggle
  // "Histórico do contato" acima da MessagesView. Quando ON, swap o painel
  // central pra renderizar TODAS as msgs do contato (todas as convs) em ordem
  // cronológica com divisores. Read-only — ReplyBox continua funcional na
  // conv ativa, então o atendente pode ler tudo + responder na conv atual sem
  // sair da tela.
  //
  // Backend: GET /api/custom/v1/accounts/:id/contacts/:cid/timeline
  // Componente: app/javascript/dashboard/components-next/KlaosTimeline/KlaosTimeline.vue
  {
    id: '/widgets/conversation/ConversationBox.vue',
    from: `import MessagesView from './MessagesView.vue';`,
    to: `import MessagesView from './MessagesView.vue';
import KlaosTimeline from 'next/KlaosTimeline/KlaosTimeline.vue';`,
    reason: 'klaos-timeline: import componente KlaosTimeline',
  },
  {
    id: '/widgets/conversation/ConversationBox.vue',
    from: `  components: {
    ConversationHeader,
    DashboardAppFrame,
    EmptyState,
    MessagesView,
  },`,
    to: `  components: {
    ConversationHeader,
    DashboardAppFrame,
    EmptyState,
    MessagesView,
    KlaosTimeline,
  },`,
    reason: 'klaos-timeline: registra KlaosTimeline como componente',
  },
  {
    id: '/widgets/conversation/ConversationBox.vue',
    from: `  data() {
    return { activeIndex: 0 };
  },`,
    to: `  data() {
    return {
      activeIndex: 0,
      // KLaOS — toggle pra alternar entre msgs da conv atual e timeline
      // unificada de TODAS as convs do contato. Estado local (reseta ao
      // trocar de conv via watcher). Read-only quando ON; ReplyBox continua
      // ativo pro atendente responder na conv atual.
      klaosShowTimeline: false,
    };
  },`,
    reason: 'klaos-timeline: state local pro toggle',
  },
  {
    id: '/widgets/conversation/ConversationBox.vue',
    from: `    'currentChat.id'() {
      this.fetchLabels();
      this.activeIndex = 0;
    },
  },`,
    to: `    'currentChat.id'() {
      this.fetchLabels();
      this.activeIndex = 0;
      // Sai da timeline ao trocar de conv — força o atendente reabrir
      // explicitamente pra evitar "sumiço" da conv que ele acabou de clicar.
      this.klaosShowTimeline = false;
    },
  },`,
    reason: 'klaos-timeline: reseta toggle ao trocar de conversa',
  },
  {
    id: '/widgets/conversation/ConversationBox.vue',
    from: `    <div v-show="!activeIndex" class="flex h-full min-h-0 m-0">
      <MessagesView
        v-if="currentChat.id"
        :inbox-id="inboxId"
        :is-inbox-view="isInboxView"
      />`,
    to: `    <div v-if="currentChat.id && currentChat.meta && currentChat.meta.sender" class="flex-shrink-0 flex items-center justify-end gap-2 px-3 py-1.5 border-b border-n-weak bg-n-alpha-1">
      <button
        class="inline-flex items-center gap-1.5 px-2 py-1 text-xs rounded-md transition-colors"
        :class="klaosShowTimeline
          ? 'bg-n-brand text-white'
          : 'bg-n-alpha-2 text-n-slate-11 hover:bg-n-alpha-3'"
        @click="klaosShowTimeline = !klaosShowTimeline"
      >
        <span class="i-ph-clock-counter-clockwise size-3.5" />
        {{ klaosShowTimeline ? 'Voltar à conversa atual' : 'Histórico do contato' }}
      </button>
    </div>
    <div v-show="!activeIndex" class="flex h-full min-h-0 m-0">
      <KlaosTimeline
        v-if="klaosShowTimeline && currentChat.id && currentChat.meta && currentChat.meta.sender"
        :contact-id="currentChat.meta.sender.id"
        :account-id="$route.params.accountId"
        :current-conversation-id="currentChat.id"
      />
      <MessagesView
        v-else-if="currentChat.id"
        :inbox-id="inboxId"
        :is-inbox-view="isInboxView"
      />`,
    reason: 'klaos-timeline: toggle button + swap MessagesView/KlaosTimeline',
  },

  // === KLaOS — emoji picker com "Frequentes" sincronizados ===
  // Persiste contador de uso de cada emoji em user.ui_settings.emoji_frequents
  // (já existe API PUT /api/v1/profile/set_ui_settings, action store updateUISettings).
  // Top 16 viram categoria "Frequentes" no início do picker. Cap em 64 entries
  // pra não inflar JSON. Reset gracioso se store/user indisponível (widget).
  {
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `  computed: {
    categories() {
      return [...this.emojis];
    },
    filterEmojisByCategory() {
      const selectedCategoryName = this.emojis.find(category =>
        category.name === this.selectedKey ? category.name : null
      );
      return selectedCategoryName?.emojis;
    },`,
    to: `  computed: {
    // KLaOS — top 16 emojis mais usados pelo usuário atual, lidos de
    // user.ui_settings.emoji_frequents (persistido server-side, sincroniza
    // entre máquinas). Map { emoji: count } → array ordenado por uso desc.
    klaosFrequentEmojis() {
      const store = this.$store;
      const user = store && store.getters && store.getters.getCurrentUser;
      const frequents = (user && user.ui_settings && user.ui_settings.emoji_frequents) || {};
      return Object.entries(frequents)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 16)
        .map(([emoji, count], i) => ({ emoji, slug: 'klaos-freq-' + i, count }));
    },
    categories() {
      const base = [...this.emojis];
      if (this.klaosFrequentEmojis.length > 0) {
        return [
          { name: 'Frequentes', slug: 'klaos-frequentes', emojis: this.klaosFrequentEmojis },
          ...base,
        ];
      }
      return base;
    },
    filterEmojisByCategory() {
      if (this.selectedKey === 'Frequentes') {
        return this.klaosFrequentEmojis;
      }
      const selectedCategoryName = this.emojis.find(category =>
        category.name === this.selectedKey ? category.name : null
      );
      return selectedCategoryName?.emojis;
    },`,
    reason: 'emoji-frequents: prepend "Frequentes" como categoria virtual no picker',
  },
  {
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `  methods: {
    changeCategory(category) {`,
    to: `  methods: {
    // KLaOS — incrementa contador de uso do emoji em user.ui_settings.emoji_frequents.
    // Cap em 64 entries pra evitar JSON gigante. Defensivo: silencia em contextos
    // sem store/user (widget client-side compartilha esse componente).
    //
    // CRÍTICO: o backend (ProfilesController#update) faz assign_attributes na coluna
    // JSONB ui_settings — REPLACE total, não merge. Por isso temos que espalhar
    // allSettings inteiro no payload, senão apagamos todas as outras chaves do
    // usuário (audio alerts, ordem do sidebar, accordions, etc).
    klaosRecordFrequent(emoji) {
      const store = this.$store;
      const user = store && store.getters && store.getters.getCurrentUser;
      if (!user) return;
      const allSettings = user.ui_settings || {};
      const current = allSettings.emoji_frequents || {};
      const updated = { ...current, [emoji]: (current[emoji] || 0) + 1 };
      const capped = Object.fromEntries(
        Object.entries(updated)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 64)
      );
      store.dispatch('updateUISettings', {
        uiSettings: { ...allSettings, emoji_frequents: capped },
      });
    },
    klaosHandleEmojiClick(emoji) {
      this.klaosRecordFrequent(emoji);
      this.onClick(emoji);
    },
    changeCategory(category) {`,
    reason: 'emoji-frequents: handler que incrementa contador antes de forward pro onClick original',
  },
  {
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `        <div class="emoji--row">
          <button
            v-for="item in filterEmojisByCategory"
            :key="item.slug"
            v-dompurify-html="item.emoji"
            class="emoji--item"
            track-by="$index"
            @click="onClick(item.emoji)"
          />
        </div>`,
    to: `        <div class="emoji--row">
          <button
            v-for="item in filterEmojisByCategory"
            :key="item.slug"
            v-dompurify-html="item.emoji"
            class="emoji--item"
            track-by="$index"
            @click="klaosHandleEmojiClick(item.emoji)"
          />
        </div>`,
    reason: 'emoji-frequents: usa handler custom no botão de categoria',
  },
  {
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `          <div v-if="category.emojis.length > 0" class="emoji--row">
            <button
              v-for="item in category.emojis"
              :key="item.slug"
              v-dompurify-html="item.emoji"
              class="emoji--item"
              track-by="$index"
              @click="onClick(item.emoji)"
            />
          </div>`,
    to: `          <div v-if="category.emojis.length > 0" class="emoji--row">
            <button
              v-for="item in category.emojis"
              :key="item.slug"
              v-dompurify-html="item.emoji"
              class="emoji--item"
              track-by="$index"
              @click="klaosHandleEmojiClick(item.emoji)"
            />
          </div>`,
    reason: 'emoji-frequents: usa handler custom no botão dentro do search result',
  },
  {
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `    getFirstEmojiByCategoryName(categoryName) {
      const categoryItem = this.emojis.find(category =>
        category.name === categoryName ? category : null
      );
      return categoryItem ? categoryItem.emojis[0].emoji : '';
    },`,
    to: `    getFirstEmojiByCategoryName(categoryName) {
      // KLaOS — usa this.categories (que inclui "Frequentes" virtual) pra resolver
      // o ícone da tab no footer. Sem isso, tab "Frequentes" fica sem emoji.
      const categoryItem = this.categories.find(category =>
        category.name === categoryName ? category : null
      );
      return categoryItem && categoryItem.emojis[0] ? categoryItem.emojis[0].emoji : '';
    },`,
    reason: 'emoji-frequents: resolve ícone da tab a partir de categories (inclui Frequentes virtual)',
  },

  // === KLaOS — botão de etiquetas inline na barra do compositor ===
  // Atalho pro time de cobrança: adicionar/remover etiqueta sem precisar abrir
  // o painel direito + expandir "Ações da conversa". Reaproveita LabelDropdown
  // (mesmo picker do sidebar) + useConversationLabels (lê a conv do store, não
  // precisa de conversationId). Popover abre PRA CIMA (bottom-full) porque a
  // barra fica no rodapé. v-on-clickaway no wrapper fecha ao clicar fora.
  // Ancoramos no botão de quoted-reply (não tocado por outro patch) pra evitar
  // conflito com o patch klaos-prefix-toggle que mexe no botão de assinatura.
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `import NextButton from 'dashboard/components-next/button/Button.vue';`,
    to: `import NextButton from 'dashboard/components-next/button/Button.vue';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';`,
    reason: 'label-composer-button: import LabelDropdown + useConversationLabels',
  },
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `  components: { NextButton, FileUpload, VideoCallButton },`,
    to: `  components: { NextButton, FileUpload, VideoCallButton, LabelDropdown },`,
    reason: 'label-composer-button: registra LabelDropdown como componente',
  },
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    const uploadRef = ref(false);`,
    to: `  setup(props) {
    const { setSignatureFlagForInbox, fetchSignatureFlagFromUISettings } =
      useUISettings();

    // KLaOS — etiquetas inline no compositor. useConversationLabels lê a
    // conversa selecionada direto do store, então funciona aqui sem props.
    const {
      accountLabels: klaosAccountLabels,
      savedLabels: klaosSavedLabels,
      activeLabels: klaosActiveLabels,
      addLabelToConversation: klaosAddLabel,
      removeLabelFromConversation: klaosRemoveLabel,
    } = useConversationLabels();
    const klaosShowLabelDropdown = ref(false);

    const uploadRef = ref(false);`,
    reason: 'label-composer-button: wira useConversationLabels + estado do dropdown no setup',
  },
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
    };`,
    to: `    return {
      setSignatureFlagForInbox,
      fetchSignatureFlagFromUISettings,
      uploadRef,
      klaosAccountLabels,
      klaosSavedLabels,
      klaosActiveLabels,
      klaosAddLabel,
      klaosRemoveLabel,
      klaosShowLabelDropdown,
    };`,
    reason: 'label-composer-button: expõe estado/handlers de etiqueta pro template',
  },
  {
    id: '/widgets/WootWriter/ReplyBottomPanel.vue',
    from: `      <NextButton
        v-if="showQuotedReplyToggle"
        v-tooltip.top-end="quotedReplyToggleTooltip"
        icon="i-ph-quotes"`,
    to: `      <div
        v-if="!isEditorDisabled"
        v-on-clickaway="() => (klaosShowLabelDropdown = false)"
        class="relative flex items-center"
      >
        <NextButton
          v-tooltip.top-end="'Etiquetas da conversa'"
          icon="i-lucide-tag"
          :variant="klaosActiveLabels.length ? 'solid' : 'faded'"
          color="slate"
          sm
          :aria-pressed="klaosShowLabelDropdown"
          @click="klaosShowLabelDropdown = !klaosShowLabelDropdown"
        />
        <div
          v-if="klaosShowLabelDropdown"
          class="absolute left-0 z-[9999] p-2 mb-2 border rounded-lg shadow-lg bottom-full w-60 box-border bg-n-alpha-3 backdrop-blur-[100px] border-n-strong"
        >
          <LabelDropdown
            :account-labels="klaosAccountLabels"
            :selected-labels="klaosSavedLabels"
            @add="klaosAddLabel"
            @remove="klaosRemoveLabel"
          />
        </div>
      </div>
      <NextButton
        v-if="showQuotedReplyToggle"
        v-tooltip.top-end="quotedReplyToggleTooltip"
        icon="i-ph-quotes"`,
    reason: 'label-composer-button: botão i-lucide-tag + popover LabelDropdown (abre pra cima) antes do quoted-reply. Usa i-lucide-tag (não i-ph-tag) porque Tailwind JIT só gera CSS de ícone presente em arquivo-fonte — i-lucide-tag já é usado em Sidebar.vue',
  },

  // === KLaOS — ordena etiquetas por frequência de uso (label_frequents) ===
  // Igual emoji frequents: persiste contador em user.ui_settings.label_frequents
  // e ordena o accountLabels do composable por uso desc + alfabético desempate.
  // Afeta AMBOS os pickers (sidebar LabelBox + botão do compositor) porque os
  // dois consomem useConversationLabels.
  //
  // CRÍTICO: merge ui_settings completo no payload — backend faz REPLACE da
  // coluna JSONB (assign_attributes), não merge. Bug do emoji v1 (47811234b)
  // apagou audio config do Gustavo por causa disso. Não repetir.
  {
    id: '/composables/useConversationLabels.js',
    from: `  const accountLabels = computed(() => getters['labels/getLabels'].value);`,
    to: `  const accountLabels = computed(() => {
    const labels = getters['labels/getLabels'].value;
    // KLaOS — ordena por frequência de uso pessoal (user.ui_settings.label_frequents),
    // depois alfabético. Etiquetas nunca usadas pelo atendente vão pro fim da lista.
    const user = getters.getCurrentUser.value;
    const frequents =
      (user && user.ui_settings && user.ui_settings.label_frequents) || {};
    return [...labels].sort((a, b) => {
      const fa = frequents[a.title] || 0;
      const fb = frequents[b.title] || 0;
      if (fa !== fb) return fb - fa;
      return (a.title || '').localeCompare(b.title || '');
    });
  });`,
    reason: 'label-frequents: ordena accountLabels por user.ui_settings.label_frequents desc + alfabético',
  },
  {
    id: '/composables/useConversationLabels.js',
    from: `  const addLabelToConversation = value => {
    const result = activeLabels.value.map(item => item.title);
    result.push(value.title);
    onUpdateLabels(result);
  };`,
    to: `  const addLabelToConversation = value => {
    const result = activeLabels.value.map(item => item.title);
    result.push(value.title);
    onUpdateLabels(result);
    // KLaOS — incrementa contador em user.ui_settings.label_frequents pra
    // que o accountLabels reordene os pickers por uso. Cap em 128 entries
    // (mais que suficiente — maioria das contas tem ~50 etiquetas).
    // Merge ui_settings completo no payload pra NÃO apagar outras chaves
    // (audio alerts, accordions, emoji_frequents, etc) — backend faz
    // REPLACE da coluna JSONB, não merge. Bug do emoji v1 já causou isso.
    const user = getters.getCurrentUser.value;
    if (user) {
      const allSettings = user.ui_settings || {};
      const current = allSettings.label_frequents || {};
      const updated = {
        ...current,
        [value.title]: (current[value.title] || 0) + 1,
      };
      const capped = Object.fromEntries(
        Object.entries(updated)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 128)
      );
      store.dispatch('updateUISettings', {
        uiSettings: { ...allSettings, label_frequents: capped },
      });
    }
  };`,
    reason: 'label-frequents: incrementa contador em add, com merge ui_settings completo (não repetir bug 47811234b)',
  },

  // === KLaOS — fix do filtro de respostas prontas + ordenação por uso ===
  //
  // BUG real do upstream: a API client de canned_responses concatena o
  // searchKey direto na URL SEM encodeURIComponent. Quando o short_code tem
  // caracteres especiais de URL (`+`, `&`, `?`, etc), o backend recebe
  // garbled. Caso Mais Saúde: short_codes "+CDI", "+CPF", "+CDF" etc — o
  // atendente digita "/+cdi" → URL "?search=+cdi" → `+` decodifica como
  // espaço → backend faz ILIKE '% cdi%' → não bate em "+CDI".
  //
  // Frequência: persiste contador em user.ui_settings.canned_frequents,
  // incrementa quando atendente seleciona uma resposta (handleMentionClick).
  // Ordena por uso desc + alfabético, no `items` computed. Backend já filtra
  // por ILIKE quando há search; aqui só reordenamos o que ele retorna.
  //
  // CRÍTICO: merge ui_settings completo no dispatch (mesma lição dos bugs
  // anteriores do emoji v1 e labels).
  {
    id: '/api/cannedResponse.js',
    from: `    const url = searchKey ? \`\${this.url}?search=\${searchKey}\` : this.url;`,
    to: `    const url = searchKey ? \`\${this.url}?search=\${encodeURIComponent(searchKey)}\` : this.url;`,
    reason: 'canned-search-encoding: encodeURIComponent no searchKey pra não decodificar + como espaço (caso Mais Saúde: short_codes +CDI/+CPF/etc)',
  },
  {
    id: '/widgets/conversation/CannedResponse.vue',
    from: `    items() {
      return this.cannedMessages.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
      }));
    },`,
    to: `    items() {
      // KLaOS — ordena por frequência de uso pessoal (user.ui_settings.canned_frequents),
      // depois alfabético. Backend já filtra via ILIKE quando há search; aqui só reordenamos
      // o resultado pra que respostas mais usadas pelo atendente apareçam primeiro.
      const user = this.$store.getters.getCurrentUser;
      const frequents =
        (user && user.ui_settings && user.ui_settings.canned_frequents) || {};
      const sorted = [...this.cannedMessages].sort((a, b) => {
        const fa = frequents[a.short_code] || 0;
        const fb = frequents[b.short_code] || 0;
        if (fa !== fb) return fb - fa;
        return (a.short_code || '').localeCompare(b.short_code || '');
      });
      return sorted.map(cannedMessage => ({
        label: cannedMessage.short_code,
        key: cannedMessage.short_code,
        description: cannedMessage.content,
      }));
    },`,
    reason: 'canned-frequents: ordena items por user.ui_settings.canned_frequents desc + alfabético',
  },
  {
    id: '/widgets/conversation/CannedResponse.vue',
    from: `    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
    },`,
    to: `    handleMentionClick(item = {}) {
      this.$emit('replace', item.description);
      // KLaOS — incrementa contador em user.ui_settings.canned_frequents pra
      // que items() reordene o picker por uso. Cap em 128 entries.
      // Merge ui_settings completo no payload — backend faz REPLACE da coluna
      // JSONB, não merge. Bug do emoji v1 (47811234b) já causou perda de
      // configs por causa disso.
      const user = this.$store.getters.getCurrentUser;
      if (user && item.key) {
        const allSettings = user.ui_settings || {};
        const current = allSettings.canned_frequents || {};
        const updated = {
          ...current,
          [item.key]: (current[item.key] || 0) + 1,
        };
        const capped = Object.fromEntries(
          Object.entries(updated)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 128)
        );
        this.$store.dispatch('updateUISettings', {
          uiSettings: { ...allSettings, canned_frequents: capped },
        });
      }
    },`,
    reason: 'canned-frequents: incrementa contador em handleMentionClick, com merge ui_settings completo',
  },
];

export default function klaosPatches() {
  const applied = new Set();

  return {
    name: 'klaos-custom-patches',
    enforce: 'pre',

    transform(code, id) {
      const targetedPatches = PATCHES.filter(p => id.endsWith(p.id));
      if (targetedPatches.length === 0) return null;

      // Normalize line endings pra match cross-platform (CRLF no Windows vs LF no Unix).
      // Vite/Rollup aceitam LF no output sem problema.
      let out = code.replace(/\r\n/g, '\n');
      let touched = false;

      for (const p of targetedPatches) {
        const from = p.from.replace(/\r\n/g, '\n');
        const to = p.to.replace(/\r\n/g, '\n');
        const key = `${p.id}::${from.slice(0, 40)}`;

        if (out.includes(from)) {
          out = out.split(from).join(to);
          applied.add(key);
          touched = true;
        } else if (!out.includes(to)) {
          throw new Error(
            `[klaos-patches] Target line not found in ${id}\n` +
              `  Expected to find (first 120 chars):\n    ${from.slice(0, 120)}\n` +
              `  Reason: ${p.reason}\n` +
              `  The upstream file likely changed. Update custom/vite/klaos-patches.js.`
          );
        } else {
          // `to` já presente → patch já aplicado (HMR re-transform). Idempotente.
          applied.add(key);
        }
      }

      return touched ? { code: out, map: null } : null;
    },

    buildStart() {
      // Reset applied set per build pra detectar regressão
      applied.clear();
    },

    buildEnd() {
      const missing = PATCHES.filter(p => {
        const key = `${p.id}::${p.from.slice(0, 40)}`;
        return !applied.has(key);
      });
      if (missing.length > 0) {
        const details = missing.map(p => `  - ${p.id}: ${p.reason}`).join('\n');
        // Em dev mode (watch), arquivos podem não ter sido tocados; não falhar.
        // Só avisar.
        this.warn(
          `[klaos-patches] ${missing.length} patch(es) not applied this build:\n${details}`
        );
      }
    },
  };
}
