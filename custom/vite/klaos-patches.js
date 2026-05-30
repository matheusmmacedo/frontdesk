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
    to: "import whatsappConnections from './whatsappConnections/whatsappConnections.routes';\nimport klaosMessagePrefix from './klaosMessagePrefix/klaosMessagePrefix.routes';\nimport klaosMetaHealth from './klaosMetaHealth/klaosMetaHealth.routes';",
    reason: 'register KLaOS message prefix + meta health settings route imports',
  },

  // === KLaOS — Banner 24h "Usar template" abre modal de template (O.10 fix) ===
  // O banner KLaOS dispatcha `klaos:open-template-picker` no document.
  // ReplyBox upstream tem `openWhatsappTemplateModal` mas nenhum listener
  // global — clique sem efeito. Patch adiciona o addEventListener no
  // mounted (e remove no unmounted) — clique abre o modal de template real.
  {
    id: '/widgets/conversation/ReplyBox.vue',
    from: "    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);",
    to: "    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.fetchAndSetReplyTo);\n    document.addEventListener('klaos:open-template-picker', this.openWhatsappTemplateModal);",
    reason: 'klaos-banner-24h: listener pra abrir modal de template via custom event',
  },
  {
    id: '/widgets/conversation/ReplyBox.vue',
    from: "    document.removeEventListener('keydown', this.handleKeyEvents);",
    to: "    document.removeEventListener('keydown', this.handleKeyEvents);\n    document.removeEventListener('klaos:open-template-picker', this.openWhatsappTemplateModal);",
    reason: 'klaos-banner-24h: cleanup do listener no unmounted',
  },

  // === KLaOS — Painel de Agentes (O.1): item no Sidebar (admin-only) ===
  // Coloca o link dentro do grupo Reports porque é supervisão. Permission
  // 'administrator' já vem na route meta — sidebar só decide a renderização.
  {
    id: '/sidebar/Sidebar.vue',
    from: `        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
      ],
    },
    {
      name: 'Campaigns',`,
    to: `        {
          name: 'Reports Bot',
          label: t('SIDEBAR.REPORTS_BOT'),
          to: accountScopedRoute('bot_reports'),
        },
        {
          name: 'KLaOS Supervisor Agents',
          label: 'Painel de Agentes',
          to: accountScopedRoute('klaos_supervisor_agents'),
        },
      ],
    },
    {
      name: 'Campaigns',`,
    reason: 'klaos-supervisor: item Painel de Agentes no grupo Reports do sidebar',
  },

  // === KLaOS — Painel de Agentes (O.1): registra rota top-level ===
  {
    id: '/dashboard/dashboard.routes.js',
    from: "import settings from './settings/settings.routes';",
    to: "import settings from './settings/settings.routes';\nimport klaosSupervisor from './klaosSupervisor/klaosSupervisor.routes';",
    reason: 'klaos-supervisor: importa routes do Painel de Agentes',
  },
  {
    id: '/dashboard/dashboard.routes.js',
    from: '        ...campaignsRoutes.routes,\n      ],',
    to: '        ...campaignsRoutes.routes,\n        ...klaosSupervisor.routes,\n      ],',
    reason: 'klaos-supervisor: registra route Painel de Agentes',
  },
  {
    id: '/settings/settings.routes.js',
    from: '...whatsappConnections.routes,\n  ],\n};',
    to: '...whatsappConnections.routes,\n    ...klaosMessagePrefix.routes,\n    ...klaosMetaHealth.routes,\n  ],\n};',
    reason: 'register KLaOS message prefix + meta health routes in settings route array',
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
        },
        {
          name: 'Settings KLaOS Meta Health',
          label: 'Saúde do WhatsApp',
          icon: 'i-lucide-activity',
          to: accountScopedRoute('klaos_meta_health_index'),
        },`,
    reason: 'add Formato do Nome + Saúde do WhatsApp (Fase 2 fix áudio) entries in settings sidebar',
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
    from: "import Button from 'dashboard/components-next/button/Button.vue';",
    to: "import Button from 'dashboard/components-next/button/Button.vue';\nimport TransferToBotButton from 'next/KlaosTransferToBot/TransferToBotButton.vue';",
    reason: 'devolver-ao-bot: import componente custom (botão + diálogo + checkbox análise)',
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
    <TransferToBotButton v-if="showTransferToBot" />
    <ButtonGroup`,
    reason: 'devolver-ao-bot: botão visível (componente custom com diálogo + checkbox de análise)',
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

// Clica em "Etiquetas:" do header → garante painel direito aberto +
// abre o dropdown de adicionar/remover etiquetas (LabelBox). Se o painel
// estava fechado, aguarda 250ms pro LabelBox montar antes de despachar o
// evento que abre o picker.
const klaosOpenLabelsPicker = async () => {
  try {
    const current = store.getters.getUISettings || {};
    if (!current.is_contact_sidebar_open) {
      await store.dispatch('updateUISettings', {
        uiSettings: { ...current, is_contact_sidebar_open: true },
      });
    }
  } catch (e) { /* noop */ }
  setTimeout(() => {
    window.dispatchEvent(new CustomEvent('klaos:focus-labels'));
  }, 250);
};

// Remove UMA etiqueta direto pelo "x" do chip, sem abrir o picker. Manda a
// lista atual de labels da conversa menos a removida pro store
// (conversationLabels/update espera a lista completa nova).
const klaosRemoveLabel = async title => {
  try {
    const convId = props.chat?.id;
    if (!convId) return;
    const current = Array.isArray(props.chat?.labels) ? props.chat.labels : [];
    const next = current.filter(t => t !== title);
    if (next.length === current.length) return;
    await store.dispatch('conversationLabels/update', {
      conversationId: convId,
      labels: next,
    });
  } catch (e) { /* noop */ }
};
</script>`,
    reason: 'conv-header-labels: computed pra rota de edição + labels resolvidas + remoção inline',
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
        </div>
        <div
          class="flex items-center flex-wrap gap-2.5 text-xs mt-1"
        >
          <a
            class="text-xs font-medium text-n-brand underline underline-offset-2 hover:text-n-brand/80 cursor-pointer select-none"
            title="Adicionar etiquetas"
            @click.stop="klaosOpenLabelsPicker"
          >Etiquetas:</a>
          <span
            v-for="lbl in klaosConversationLabels"
            :key="lbl.title"
            :title="lbl.title"
            class="relative inline-block flex-shrink-0 align-middle"
            :style="{ width: '14px', height: '14px' }"
          >
            <span
              class="block rounded-full outline outline-1 outline-n-slate-4"
              :style="{ background: lbl.color, width: '14px', height: '14px' }"
            />
            <span
              role="button"
              tabindex="0"
              title="Remover etiqueta"
              class="absolute flex items-center justify-center rounded-full bg-n-background border border-n-strong text-n-slate-11 cursor-pointer hover:text-n-ruby-11 hover:border-n-ruby-8"
              :style="{ top: '-4px', right: '-2px', width: '11px', height: '11px', fontSize: '9px', lineHeight: '1', fontWeight: '700' }"
              @click.stop="klaosRemoveLabel(lbl.title)"
            >×</span>
          </span>
          <a
            v-if="!klaosConversationLabels.length"
            class="text-xs text-n-slate-10 italic cursor-pointer hover:text-n-brand select-none"
            title="Adicionar etiquetas"
            @click.stop="klaosOpenLabelsPicker"
          >adicionar</a>
        </div>`,
    reason: 'conv-header-labels: atalho "Etiquetas:" sempre visível (+ chips com x quando houver)',
  },
  {
    // KLaOS — o header tinha altura FIXA (h-24 mobile / xl:h-12 = 48px desktop),
    // dimensionada pra 2 linhas (nome + inbox). A linha de etiquetas virou a 3ª
    // e estourava: cortava o topo do nome e ficava estranho no responsivo.
    // Troca pra min-height (cresce com o conteúdo) — acomoda a linha de
    // etiquetas sem cortar o nome, e o flex-wrap das etiquetas cuida do responsivo.
    id: '/widgets/conversation/ConversationHeader.vue',
    from: `px-3 pt-3 pb-2 h-24 xl:h-12`,
    to: `px-3 pt-3 pb-2 min-h-[6rem] xl:min-h-[3rem]`,
    reason: 'conv-header: altura flexível (min-h) pra caber a linha de etiquetas sem cortar o nome',
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
    // KLaOS — top 16 emojis mais usados. Hierarquia personal → global:
    // pessoal sempre vence; global preenche pra atendente novo ver Frequentes
    // útil desde o primeiro acesso. Sync entre máquinas via user.ui_settings
    // + account.custom_attributes (dual-write em klaosRecordFrequent).
    klaosFrequentEmojis() {
      if (typeof window !== 'undefined' && window.klaosGlobalFrequents) {
        window.klaosGlobalFrequents.fetch();
      }
      const store = this.$store;
      const user = store && store.getters && store.getters.getCurrentUser;
      const personal = (user && user.ui_settings && user.ui_settings.emoji_frequents) || {};
      const global = (typeof window !== 'undefined' && window.klaosGlobalFrequents
        ? window.klaosGlobalFrequents.get('emojis')
        : null) || {};
      const keys = new Set([...Object.keys(personal), ...Object.keys(global)]);
      return [...keys]
        .sort((a, b) => {
          const pa = personal[a] || 0;
          const pb = personal[b] || 0;
          if (pa !== pb) return pb - pa;
          const ga = global[a] || 0;
          const gb = global[b] || 0;
          return gb - ga;
        })
        .slice(0, 16)
        .map((emoji, i) => ({ emoji, slug: 'klaos-freq-' + i }));
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
      // KLaOS — dual-write: também incrementa contador GLOBAL da conta pra
      // ranking servir como fallback de novos atendentes
      if (typeof window !== 'undefined' && window.klaosGlobalFrequents) {
        window.klaosGlobalFrequents.track('emoji', emoji);
      }
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
  {
    // KLaOS — mostra "Frequentes" como PRIMEIRA seção da view padrão do picker
    // (estilo WhatsApp): os mais usados aparecem em cima E todos os outros emojis
    // continuam visíveis/roláveis abaixo. (Antes eu abria direto na categoria
    // Frequentes, o que escondia os demais emojis — bug.)
    id: '/shared/components/emoji/EmojiInput.vue',
    from: `    filterAllEmojisBySearch() {
      return this.emojis.map(category => {
        const allEmojis = category.emojis.filter(emoji =>
          emoji.slug.replaceAll('_', ' ').includes(this.search.toLowerCase())
        );
        return allEmojis.length > 0
          ? { ...category, emojis: allEmojis }
          : { ...category, emojis: [] };
      });
    },`,
    to: `    filterAllEmojisBySearch() {
      const base = this.emojis.map(category => {
        const allEmojis = category.emojis.filter(emoji =>
          emoji.slug.replaceAll('_', ' ').includes(this.search.toLowerCase())
        );
        return allEmojis.length > 0
          ? { ...category, emojis: allEmojis }
          : { ...category, emojis: [] };
      });
      // KLaOS — sem busca, prepend "Frequentes" no topo; todos os outros emojis
      // seguem visíveis abaixo. Com busca ativa, não mostra Frequentes.
      if (this.search === '' && this.klaosFrequentEmojis && this.klaosFrequentEmojis.length > 0) {
        return [{ name: 'Frequentes', slug: 'klaos-frequentes', emojis: this.klaosFrequentEmojis }, ...base];
      }
      return base;
    },`,
    reason: 'emoji-frequents: Frequentes como 1ª seção da view padrão (sem esconder os demais)',
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
    // KLaOS — hierarquia personal → global → alfabético.
    // Personal: user.ui_settings.label_frequents (incrementado em addLabelToConversation)
    // Global: window.klaosGlobalFrequents.get('labels') (derivado de taggings,
    //         deterministico, sem dual-write necessário — taggings é fonte da verdade)
    if (typeof window !== 'undefined' && window.klaosGlobalFrequents) {
      window.klaosGlobalFrequents.fetch();
    }
    const user = getters.getCurrentUser.value;
    const personal =
      (user && user.ui_settings && user.ui_settings.label_frequents) || {};
    const global =
      (typeof window !== 'undefined' && window.klaosGlobalFrequents
        ? window.klaosGlobalFrequents.get('labels')
        : null) || {};
    return [...labels].sort((a, b) => {
      const pa = personal[a.title] || 0;
      const pb = personal[b.title] || 0;
      if (pa !== pb) return pb - pa;
      const ga = global[a.title] || 0;
      const gb = global[b.title] || 0;
      if (ga !== gb) return gb - ga;
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
      // KLaOS — hierarquia personal → global → alfabético.
      // Backend já filtra via ILIKE quando há search; aqui só reordenamos.
      if (typeof window !== 'undefined' && window.klaosGlobalFrequents) {
        window.klaosGlobalFrequents.fetch();
      }
      const user = this.$store.getters.getCurrentUser;
      const personal =
        (user && user.ui_settings && user.ui_settings.canned_frequents) || {};
      const global =
        (typeof window !== 'undefined' && window.klaosGlobalFrequents
          ? window.klaosGlobalFrequents.get('canned')
          : null) || {};
      const sorted = [...this.cannedMessages].sort((a, b) => {
        const pa = personal[a.short_code] || 0;
        const pb = personal[b.short_code] || 0;
        if (pa !== pb) return pb - pa;
        const ga = global[a.short_code] || 0;
        const gb = global[b.short_code] || 0;
        if (ga !== gb) return gb - ga;
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
      // KLaOS — dual-write: incrementa contador PESSOAL (user.ui_settings)
      // E GLOBAL (account.custom_attributes via POST). Cap personal em 128.
      // Merge ui_settings completo no payload — backend faz REPLACE da JSONB.
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
      // Global: POST track pra account.custom_attributes.canned_frequents
      if (
        typeof window !== 'undefined' &&
        window.klaosGlobalFrequents &&
        item.key
      ) {
        window.klaosGlobalFrequents.track('canned', item.key);
      }
    },`,
    reason: 'canned-frequents: incrementa contador em handleMentionClick, com merge ui_settings completo',
  },

  // === KLaOS — emoji frequents também no atalho :nome (keyboardEmojiSelector) ===
  // Bug constatado: Gustavo manda muitos 👍 mas o contador só registra cliques
  // direto no picker (EmojiInput.vue). Ele usa atalho `:thumbs_up` via tiptap
  // suggestion (trigger ':') → keyboardEmojiSelector.vue → emite selectEmoji.
  // Patcheamos pra ALSO registrar nessa via.
  {
    id: '/WootWriter/keyboardEmojiSelector.vue',
    from: `import MentionBox from '../mentions/MentionBox.vue';`,
    to: `import MentionBox from '../mentions/MentionBox.vue';
import { useStore } from 'dashboard/composables/store';`,
    reason: 'emoji-frequents-keyboard: import useStore pra dispatcher updateUISettings',
  },
  {
    id: '/WootWriter/keyboardEmojiSelector.vue',
    from: `function handleMentionClick(item = {}) {
  emit('selectEmoji', item.emoji);
}`,
    to: `// KLaOS — store pra registrar emoji_frequents quando o atendente usa o
// atalho de teclado :nome (trigger ':' do tiptap). Sem esse patch, só o
// click direto no picker contava — atendente que prefere teclado nunca
// aparecia no ranking de mais usados.
const klaosStore = useStore();

function handleMentionClick(item = {}) {
  emit('selectEmoji', item.emoji);
  // KLaOS — dual-write: pessoal (ui_settings) + global (account.custom_attributes).
  const user = klaosStore.getters.getCurrentUser;
  if (user && item.emoji) {
    const allSettings = user.ui_settings || {};
    const current = allSettings.emoji_frequents || {};
    const updated = {
      ...current,
      [item.emoji]: (current[item.emoji] || 0) + 1,
    };
    const capped = Object.fromEntries(
      Object.entries(updated)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 64)
    );
    klaosStore.dispatch('updateUISettings', {
      uiSettings: { ...allSettings, emoji_frequents: capped },
    });
  }
  if (typeof window !== 'undefined' && window.klaosGlobalFrequents && item.emoji) {
    window.klaosGlobalFrequents.track('emoji', item.emoji);
  }
}`,
    reason: 'emoji-frequents-keyboard: registra emoji no atalho :nome além do picker direto',
  },

  // === KLaOS — templates Meta ordenados por uso humano ===
  // TemplatesPicker é exclusivo da UI do atendente. Bot/automação envia template
  // via API direto (sem passar por esse picker), então o contador captura SÓ
  // uso humano por construção — atende o pedido "considera humano, não bot".
  {
    id: '/WhatsappTemplates/TemplatesPicker.vue',
    from: `const filteredTemplateMessages = computed(() =>
  whatsAppTemplateMessages.value.filter(template =>
    template.name.toLowerCase().includes(query.value.toLowerCase())
  )
);`,
    to: `const filteredTemplateMessages = computed(() => {
  const list = whatsAppTemplateMessages.value.filter(template =>
    template.name.toLowerCase().includes(query.value.toLowerCase())
  );
  // KLaOS — hierarquia: pinned (📌 manual) → personal → global → alfabético.
  // Pinned vem de user.ui_settings.pinned_templates (array de nomes na ordem).
  if (typeof window !== 'undefined' && window.klaosGlobalFrequents) {
    window.klaosGlobalFrequents.fetch();
  }
  const user = store.getters.getCurrentUser;
  const pinnedList =
    (user && user.ui_settings && user.ui_settings.pinned_templates) || [];
  const pinnedIndex = {};
  pinnedList.forEach((name, idx) => { pinnedIndex[name] = idx; });
  const personal =
    (user && user.ui_settings && user.ui_settings.template_frequents) || {};
  const global =
    (typeof window !== 'undefined' && window.klaosGlobalFrequents
      ? window.klaosGlobalFrequents.get('templates')
      : null) || {};
  return [...list].sort((a, b) => {
    const piA = pinnedIndex[a.name];
    const piB = pinnedIndex[b.name];
    const aIsPinned = piA !== undefined;
    const bIsPinned = piB !== undefined;
    if (aIsPinned && !bIsPinned) return -1;
    if (!aIsPinned && bIsPinned) return 1;
    if (aIsPinned && bIsPinned) return piA - piB;
    const pa = personal[a.name] || 0;
    const pb = personal[b.name] || 0;
    if (pa !== pb) return pb - pa;
    const ga = global[a.name] || 0;
    const gb = global[b.name] || 0;
    if (ga !== gb) return gb - ga;
    return (a.name || '').localeCompare(b.name || '');
  });
});

// KLaOS — verifica se um template está pinado pelo agente atual.
const klaosIsTemplatePinned = templateName => {
  const user = store.getters.getCurrentUser;
  const list =
    (user && user.ui_settings && user.ui_settings.pinned_templates) || [];
  return list.includes(templateName);
};

// KLaOS — toggle pin/unpin do template em user.ui_settings.pinned_templates.
const klaosTogglePinTemplate = (event, templateName) => {
  if (event) {
    event.stopPropagation();
    event.preventDefault();
  }
  const user = store.getters.getCurrentUser;
  if (!user || !templateName) return;
  const allSettings = user.ui_settings || {};
  const current = allSettings.pinned_templates || [];
  const updated = current.includes(templateName)
    ? current.filter(n => n !== templateName)
    : [templateName, ...current].slice(0, 16);
  store.dispatch('updateUISettings', {
    uiSettings: { ...allSettings, pinned_templates: updated },
  });
};`,
    reason: 'template-frequents: ordena filteredTemplateMessages com pinned > frequents',
  },
  {
    id: '/WhatsappTemplates/TemplatesPicker.vue',
    from: `const getTemplateBody = template => {`,
    to: `// KLaOS — wrapper do onSelect que registra uso humano em
// user.ui_settings.template_frequents antes de emitir o evento.
// Cap 128. Merge ui_settings completo no payload (backend faz REPLACE).
const klaosOnSelect = template => {
  emit('onSelect', template);
  const user = store.getters.getCurrentUser;
  if (user && template && template.name) {
    const allSettings = user.ui_settings || {};
    const current = allSettings.template_frequents || {};
    const updated = {
      ...current,
      [template.name]: (current[template.name] || 0) + 1,
    };
    const capped = Object.fromEntries(
      Object.entries(updated)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 128)
    );
    store.dispatch('updateUISettings', {
      uiSettings: { ...allSettings, template_frequents: capped },
    });
  }
};

const getTemplateBody = template => {`,
    reason: 'template-frequents: wrapper klaosOnSelect que incrementa contador antes de emitir',
  },
  {
    id: '/WhatsappTemplates/TemplatesPicker.vue',
    from: `          @click="emit('onSelect', template)"`,
    to: `          @click="klaosOnSelect(template)"`,
    reason: 'template-frequents: usa wrapper klaosOnSelect no click do botão de template',
  },
  // === KLaOS — Pino manual de template (★ favorito) ===
  // V1 usava emoji 📍/📌 — feio + sem afordance clara. V2 usa ícone estrela
  // Lucide (padrão universal "favorito") com:
  //   - Vazio (não pinado): contorno cinza, opacidade 50%
  //   - Pinado: estrela cheia amarela com glow sutil
  //   - Hover: scale + opacidade total
  //   - Animação ao toggle (rotate + scale)
  {
    id: '/WhatsappTemplates/TemplatesPicker.vue',
    from: `<div v-for="(template, i) in filteredTemplateMessages" :key="template.id">
        <button`,
    to: `<div v-for="(template, i) in filteredTemplateMessages" :key="template.id" class="relative">
        <button
          type="button"
          class="absolute top-2.5 right-3 z-10 inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold transition-all hover:scale-105"
          :class="klaosIsTemplatePinned(template.name) ? 'bg-n-amber-4 text-n-amber-12 hover:bg-n-amber-5' : 'bg-n-alpha-2 text-n-slate-12 hover:bg-n-amber-3'"
          :title="klaosIsTemplatePinned(template.name) ? 'Clique pra desfixar' : 'Clique pra fixar no topo'"
          @click="klaosTogglePinTemplate($event, template.name)"
        >
          <span class="text-sm leading-none">{{ klaosIsTemplatePinned(template.name) ? '★' : '☆' }}</span>
          <span class="leading-none">{{ klaosIsTemplatePinned(template.name) ? 'Fixado' : 'Fixar' }}</span>
        </button>
        <button`,
    reason: 'template-pin: pill com texto + estrela (vs só estrela invisível)',
  },

  // === KLaOS — Global Usage Frequents (hierarchia personal → global) ===
  //
  // Instala helper window.klaosGlobalFrequents no boot do app (patcheado no
  // store/index.js que é carregado universalmente). Helper expõe:
  //   - fetch()        — busca /api/custom/v1/accounts/:id/usage_frequents (lazy, idempotente)
  //   - get(kind)      — retorna o map de counters globais pra uma categoria
  //   - track(t, key)  — POST pra incrementar account.custom_attributes (emoji|canned)
  //
  // Hierarquia de ordenação aplicada em labels/templates/emojis/canned:
  //   personal[key] || global[key] || 0  → alfabético desempate
  //
  // Atendente novo (sem ui_settings.X_frequents) entra com ranking decente.
  // À medida que usa, frequents pessoal sobrescreve o global por item.
  {
    id: '/dashboard/store/index.js',
    from: `import { createStore } from 'vuex';`,
    to: `import { createStore } from 'vuex';

// KLaOS — Global Usage Frequents helper. Instalado uma vez no boot do store
// (esse arquivo carrega universalmente). Lazy-fetch dos counters globais
// derivados/armazenados na conta + dual-write track pros que precisam
// (emoji/canned não-derivam, têm que ser incrementados explicitamente).
if (typeof window !== 'undefined' && !window.klaosGlobalFrequents) {
  window.klaosGlobalFrequents = {
    data: { labels: {}, templates: {}, emojis: {}, canned: {} },
    loaded: false,
    loading: false,
    _accountId() {
      const m = window.location.pathname.match(/\\/accounts\\/(\\d+)/);
      return m ? m[1] : null;
    },
    fetch() {
      if (this.loaded || this.loading) return;
      const aid = this._accountId();
      if (!aid) return;
      this.loading = true;
      window.axios
        .get('/api/custom/v1/accounts/' + aid + '/usage_frequents')
        .then(res => {
          if (res && res.data) this.data = res.data;
          this.loaded = true;
        })
        .catch(() => {})
        .finally(() => {
          this.loading = false;
        });
    },
    get(kind) {
      return (this.data && this.data[kind]) || {};
    },
    track(type, key) {
      const aid = this._accountId();
      if (!aid || !key) return;
      window.axios
        .post('/api/custom/v1/accounts/' + aid + '/usage_frequents/track', {
          type,
          key,
        })
        .then(() => {
          // Reflete localmente pra próximo sort já considerar o novo count
          const bucket = this.data[type + 's'];
          if (bucket) bucket[key] = (bucket[key] || 0) + 1;
        })
        .catch(() => {});
    },
  };
}
`,
    reason: 'global-frequents: instala window.klaosGlobalFrequents helper no boot do store',
  },

  // === KLaOS — busca inline por nome em cima das tabs (Minhas/Não atribuídas/Todos) ===
  // Filtro client-side sobre as conversas já carregadas (lista paginada).
  // Combina com tab atual (não substitui). Match por:
  //   - nome do contato (ILIKE)
  //   - email
  //   - últimos N dígitos do telefone (regex strip dígitos)
  //   - display_id exato (quando o input é puramente numérico)
  // Limitação v1: só busca no que está carregado. Conversas ainda não puxadas
  // pelo scroll não aparecem. v2 pode ser server-side se virar gargalo.
  {
    id: '/components/ChatList.vue',
    from: `const chatLists = useMapGetter('getFilteredConversations');`,
    to: `const chatLists = useMapGetter('getFilteredConversations');
// KLaOS — busca inline por nome (client-side, sobre os já carregados)
const klaosSearchQuery = ref('');`,
    reason: 'inline-search: declara ref klaosSearchQuery no setup',
  },
  {
    id: '/components/ChatList.vue',
    from: `  if (activeFolder.value) {
    const { payload } = activeFolder.value.query;
    localConversationList = localConversationList.filter(conversation => {
      return matchesFilters(conversation, payload);
    });
  }

  return localConversationList;
});`,
    to: `  if (activeFolder.value) {
    const { payload } = activeFolder.value.query;
    localConversationList = localConversationList.filter(conversation => {
      return matchesFilters(conversation, payload);
    });
  }

  // KLaOS — busca inline por nome/email/phone/display_id (case-insensitive,
  // dígitos do telefone ignoram máscara). Filtra DEPOIS de tab/folder pra
  // resultados combinarem (ex: "Minhas" + "joão" = só os joãos atribuídos a mim).
  const klaosQ = klaosSearchQuery.value.trim().toLowerCase();
  if (klaosQ) {
    const klaosDigits = klaosQ.replace(/\\D/g, '');
    localConversationList = localConversationList.filter(conv => {
      const sender = (conv && conv.meta && conv.meta.sender) || {};
      const name = (sender.name || '').toLowerCase();
      const email = (sender.email || '').toLowerCase();
      const phone = (sender.phone_number || '').replace(/\\D/g, '');
      const displayId = String((conv && conv.display_id) || '');
      if (name.includes(klaosQ)) return true;
      if (email && email.includes(klaosQ)) return true;
      if (klaosDigits.length >= 3 && phone && phone.includes(klaosDigits)) return true;
      if (klaosDigits.length > 0 && displayId === klaosDigits) return true;
      return false;
    });
  }

  return localConversationList;
});`,
    reason: 'inline-search: filtra conversationList por klaosSearchQuery (nome/email/phone/display_id)',
  },
  {
    id: '/components/ChatList.vue',
    from: `    <ChatTypeTabs
      v-if="!hasAppliedFiltersOrActiveFolders"
      :items="assigneeTabItems"
      :active-tab="activeAssigneeTab"
      is-compact
      @chat-tab-change="updateAssigneeTab"
    />`,
    to: `    <!-- KLaOS — busca inline por nome -->
    <div class="px-4 pt-2 pb-1">
      <div class="flex items-center gap-2 px-2.5 h-8 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak focus-within:outline-n-brand">
        <span class="i-lucide-search size-3.5 text-n-slate-11 flex-shrink-0" />
        <input
          v-model="klaosSearchQuery"
          type="search"
          placeholder="Buscar por nome, telefone ou #ID"
          class="reset-base w-full h-full bg-transparent text-n-slate-12 !text-sm !outline-0 !border-0 !p-0 !m-0"
        />
        <button
          v-if="klaosSearchQuery"
          class="flex-shrink-0 size-4 grid place-content-center text-n-slate-11 hover:text-n-slate-12"
          @click="klaosSearchQuery = ''"
        >
          <span class="i-lucide-x size-3.5" />
        </button>
      </div>
    </div>
    <ChatTypeTabs
      v-if="!hasAppliedFiltersOrActiveFolders"
      :items="assigneeTabItems"
      :active-tab="activeAssigneeTab"
      is-compact
      @chat-tab-change="updateAssigneeTab"
    />`,
    reason: 'inline-search: input de busca acima das tabs (Minhas/Não atribuídas/Todos)',
  },

  // ─── Etiquetas: atalho no card da conversa ─────────────────────────────
  // Adiciona prefixo "Etiquetas:" antes das chips no card. Clicar nele
  // navega pra conversa (clique do card) e abre o picker de labels.
  // Coordenação via sessionStorage (TTL 10s) lido pelo LabelBox no mount.
  {
    id: '/conversationCardComponents/CardLabels.vue',
    from: `const props = defineProps({
  conversationLabels: {
    type: Array,
    required: true,
  },
});`,
    to: `const props = defineProps({
  conversationLabels: {
    type: Array,
    required: true,
  },
  conversationId: {
    type: [Number, String],
    default: null,
  },
});

const klaosFocusLabels = () => {
  // sinaliza pro LabelBox abrir o picker assim que a conversa montar
  try {
    sessionStorage.setItem(
      'klaos:focusLabelsConv',
      JSON.stringify({ id: props.conversationId, ts: Date.now() })
    );
  } catch (e) { /* ignore quota */ }
  // se o LabelBox já está montado (mesma conv), dispara evento direto
  try { window.dispatchEvent(new CustomEvent('klaos:focus-labels')); } catch (e) { /* noop */ }
};`,
    reason: 'card-labels: declara conversationId + flag pro picker abrir',
  },
  {
    id: '/conversationCardComponents/CardLabels.vue',
    from: `      <slot name="before" />
      <woot-label`,
    to: `      <slot name="before" />
      <span
        class="text-xs leading-5 font-medium text-n-slate-11 hover:text-n-brand cursor-pointer mr-1.5 whitespace-nowrap select-none"
        title="Adicionar ou remover etiquetas"
        @click="klaosFocusLabels"
      >
        Etiquetas:
      </span>
      <woot-label`,
    reason: 'card-labels: render prefixo "Etiquetas:" clicável antes das chips',
  },
  // v3: chips do card de lista viram bolinhas (sem texto). Hover mostra nome.
  // Mantemos via overlay no <woot-label> — esconde o texto, força tamanho de
  // bolinha. Deixar o componente original e só "mascarar" via CSS evita ter
  // que substituir o v-for inteiro e reduz fragilidade do patch.
  {
    id: '/conversationCardComponents/CardLabels.vue',
    from: `      <woot-label
        v-for="(label, index) in activeLabels"
        :key="label ? label.id : index"
        :title="label.title"
        :description="label.description"
        :color="label.color"
        variant="smooth"
        class="!mb-0 max-w-[calc(100%-0.5rem)]"
        small
        :class="{
          'invisible absolute': !showAllLabels && index > labelPosition,
        }"
      />`,
    to: `      <span
        v-for="(label, index) in activeLabels"
        :key="label ? label.id : index"
        :title="label.title"
        class="size-3 rounded-full flex-shrink-0 mr-1 outline outline-1 outline-n-slate-4 cursor-pointer label hover:scale-110 transition-transform"
        :style="{ background: label.color }"
        :class="{
          'invisible absolute': !showAllLabels && index > labelPosition,
        }"
      />`,
    reason: 'card-labels: chips → bolinhas (sem texto, com tooltip nome)',
  },
  // v2: estilo hiperlink (underline + cor brand) no prefix "Etiquetas:"
  {
    id: '/conversationCardComponents/CardLabels.vue',
    from: `class="text-xs leading-5 font-medium text-n-slate-11 hover:text-n-brand cursor-pointer mr-1.5 whitespace-nowrap select-none"`,
    to: `class="text-xs leading-5 font-medium text-n-brand underline underline-offset-2 hover:text-n-brand/80 cursor-pointer mr-1.5 whitespace-nowrap select-none"`,
    reason: 'card-labels: estilo hiperlink (underline + cor brand) no "Etiquetas:"',
  },
  // v2: tooltip nas chips mostra o NOME da etiqueta (era description)
  {
    id: '/components/ui/Label.vue',
    from: `:title="description"`,
    to: `:title="title + (description ? ' — ' + description : '')"`,
    reason: 'woot-label: tooltip nativo mostra o nome (e descrição se houver)',
  },
  // v4: tira o título "Etiquetas da conversa" do sidebar (usuário pediu).
  // O LabelBox renderiza só as bolinhas + botão "+" pra adicionar.
  {
    id: '/dashboard/conversation/ConversationAction.vue',
    from: `    <ContactDetailsItem
      compact
      :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_LABELS')"
    />
    <ConversationLabels :conversation-id="conversationId" />`,
    to: `    <ConversationLabels :conversation-id="conversationId" />`,
    reason: 'sidebar: remove título "Etiquetas da conversa" — só bolinhas',
  },
  // v3: sidebar LabelBox vira só bolinhas coloridas (sem chips/texto).
  // Hover na bolinha mostra o nome (tooltip nativo). Clicar abre o picker.
  {
    id: '/conversation/labels/LabelBox.vue',
    from: `        <woot-label
          v-for="label in activeLabels"
          :key="label.id"
          :title="label.title"
          :description="label.description"
          show-close
          :color="label.color"
          variant="smooth"
          class="max-w-[calc(100%-0.5rem)]"
          @remove="removeLabelFromConversation"
        />`,
    to: `        <button
          v-for="label in activeLabels"
          :key="label.id"
          type="button"
          :title="label.title + (label.description ? ' — ' + label.description : '')"
          class="size-4 rounded-full flex-shrink-0 mr-1 mb-1 outline outline-1 outline-n-slate-4 hover:scale-110 transition-transform cursor-pointer"
          :style="{ background: label.color }"
          @click="toggleLabels"
        />`,
    reason: 'sidebar-labels: chips → bolinhas com tooltip; click abre picker',
  },
  // Move o CardLabels do final do card pra logo embaixo do <h4> nome,
  // e passa o conversation-id pro atalho funcionar.
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: `        {{ currentContact.name }}
      </h4>
      <VoiceCallStatus`,
    to: `        {{ currentContact.name }}
      </h4>
      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        :conversation-id="chat.id"
        class="mt-0.5 mx-2 mb-1"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
      <VoiceCallStatus`,
    reason: 'conv-card: move CardLabels pra logo embaixo do nome (atalho + ordem)',
  },
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: `      <CardLabels
        v-if="showLabelsSection"
        :conversation-labels="chat.labels"
        class="mt-0.5 mx-2 mb-0"
      >
        <template v-if="hasSlaPolicyId" #before>
          <SLACardLabel :chat="chat" class="ltr:mr-1 rtl:ml-1" />
        </template>
      </CardLabels>
    </div>
    <ContextMenu`,
    to: `    </div>
    <ContextMenu`,
    reason: 'conv-card: remove o CardLabels do local antigo (final do card)',
  },
  {
    id: '/conversation/labels/LabelBox.vue',
    from: `import { ref } from 'vue';`,
    to: `import { ref, onMounted, onBeforeUnmount } from 'vue';`,
    reason: 'label-box: importa onMounted pra auto-abrir picker via atalho do card',
  },
  {
    id: '/conversation/labels/LabelBox.vue',
    from: `    useKeyboardEvents(keyboardEvents);
    return {`,
    to: `    useKeyboardEvents(keyboardEvents);

    // KLaOS: dois caminhos pra abrir o picker programaticamente:
    //   1. flag sessionStorage (TTL 10s) — set pelo atalho do CardLabels da
    //      lista; consumida quando o LabelBox monta após navegação.
    //   2. evento global 'klaos:focus-labels' — pro caso do LabelBox já estar
    //      montado (mesma conversa) ou do link no sidebar disparar.
    const klaosOpenPicker = () => { showSearchDropdownLabel.value = true; };
    onMounted(() => {
      window.addEventListener('klaos:focus-labels', klaosOpenPicker);
      try {
        const raw = sessionStorage.getItem('klaos:focusLabelsConv');
        if (!raw) return;
        sessionStorage.removeItem('klaos:focusLabelsConv');
        const { ts } = JSON.parse(raw) || {};
        if (!ts || Date.now() - ts > 10000) return;
        setTimeout(klaosOpenPicker, 250);
      } catch (e) { /* noop */ }
    });
    onBeforeUnmount(() => {
      window.removeEventListener('klaos:focus-labels', klaosOpenPicker);
    });

    return {`,
    reason: 'label-box: auto-abre picker quando vier do atalho "Etiquetas:" do card',
  },

  // === KLaOS — Rótulo customizável da aba "Não atribuídas" (item 10 Gustavo) ===
  // Permite cada conta definir o nome da aba. Mais Saúde quer "Inteligência
  // Artificial" porque as conversas não atribuídas estão com a IA. Outros
  // clientes podem ter outros nomes (ex: "Triagem", "Bot"). Multi-tenant via
  // account.settings.unassigned_label.
  {
    id: '/components/ChatList.vue',
    from: `const assigneeTabItems = computed(() => {
  return filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({
    key,
    name: t(\`CHAT_LIST.ASSIGNEE_TYPE_TABS.\${key}\`),
    count: conversationStats.value[countKey] || 0,
  }));
});`,
    to: `// KLaOS custom — rótulo customizável da aba "Não atribuídas" por conta.
// Lê account.settings.unassigned_label; em branco/null = padrão i18n.
const klaosCurrentAccount = computed(() =>
  store.getters['accounts/getAccount'](currentAccountId.value)
);
const klaosUnassignedLabel = computed(
  () => klaosCurrentAccount.value?.settings?.unassigned_label || null
);

const assigneeTabItems = computed(() => {
  return filterItemsByPermission(
    ASSIGNEE_TYPE_TAB_PERMISSIONS,
    userPermissions.value,
    item => item.permissions
  ).map(({ key, count: countKey }) => ({
    key,
    name:
      (key === 'unassigned' && klaosUnassignedLabel.value) ||
      t(\`CHAT_LIST.ASSIGNEE_TYPE_TABS.\${key}\`),
    count: conversationStats.value[countKey] || 0,
  }));
});`,
    reason: 'rotulo-unassigned: aba customizavel por conta via account.settings.unassigned_label',
  },

  // === KLaOS — Toggle "Manter agentes online até logout manual" em Conf > Geral ===
  // Wiring de KeepAgentsOnlineToggle.vue (componente Klaos*) dentro da página
  // Configurações > Conta. Liga toggle por conta (multi-tenant): quando ON,
  // backend trata todos os agentes da conta como auto_offline=false.
  // Itens tocados: import, components register, render no template.
  {
    id: '/settings/account/Index.vue',
    from: "import AudioTranscription from './components/AudioTranscription.vue';",
    to: "import AudioTranscription from './components/AudioTranscription.vue';\nimport KeepAgentsOnlineToggle from 'next/KlaosAccountSettings/KeepAgentsOnlineToggle.vue';",
    reason: 'keep-agents-online: import componente custom (toggle por conta)',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    AudioTranscription,\n    SectionLayout,',
    to: '    AudioTranscription,\n    KeepAgentsOnlineToggle,\n    SectionLayout,',
    reason: 'keep-agents-online: registra componente no options API',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    <AudioTranscription v-if="showAudioTranscriptionConfig" />\n    <AccountId />',
    to: '    <AudioTranscription v-if="showAudioTranscriptionConfig" />\n    <div class="mt-6">\n      <KeepAgentsOnlineToggle />\n    </div>\n    <AccountId />',
    reason: 'keep-agents-online: renderiza toggle entre AudioTranscription e AccountId',
  },

  // === KLaOS — ActionCable: registra evento custom klaos.snooze_reopened ===
  // O backend (custom/config/initializers/klaos_snooze_no_limit.rb) broadcasta
  // este evento quando reabre uma conv adiada. Frontend SnoozeReopenAlert.vue
  // ouve via emitter pra disparar tab piscando + push + som.
  {
    id: '/dashboard/helper/actionCable.js',
    from: "'copilot.message.created': this.onCopilotMessageCreated,\n    };",
    to: "'copilot.message.created': this.onCopilotMessageCreated,\n      'klaos.snooze_reopened': this.onKlaosSnoozeReopened,\n    };",
    reason: 'klaos-snooze-reopened: registra event handler',
  },
  {
    id: '/dashboard/helper/actionCable.js',
    from: "  // eslint-disable-next-line class-methods-use-this\n  onReconnect = () => {",
    to: `  onKlaosSnoozeReopened = data => {
    try {
      emitter.emit('klaos.snooze_reopened', data);
    } catch (e) { /* noop */ }
  };

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {`,
    reason: 'klaos-snooze-reopened: handler que emite via mitt emitter',
  },

  // === KLaOS — Fix bug "mensagem vazia enviada" do composer (ReplyBox.vue) ===
  // Bug nativo Chatwoot (confirmado via git blame + diff vs upstream/develop):
  //   onFinishRecorder seta `hasRecordedAudio=true` INCONDICIONALMENTE,
  //   mesmo quando o file vem null (gravação falhou). Daí isReplyButtonDisabled
  //   libera o botão Send mesmo com composer vazio + sem arquivos →
  //   POST com content='' chega no backend → Meta rejeita ("text.body required"
  //   ou "Template not found").
  //
  // Reproduzimos em DEV (msg 13804) com POST direto. Histórico Mais Saúde prod
  // mostra 3 ocorrências em 7 dias (msgs 24060/22156/22158/18549).
  //
  // Fix em 2 patches:
  //   1. onFinishRecorder: guard `if (!file) return;` ANTES de setar a flag
  //   2. isReplyButtonDisabled: só libera quando hasRecordedAudio + arquivo
  //      de áudio realmente presente em attachedFiles
  //
  // Defesa em profundidade: backend também adicionou KlaosEmptyMessageGuard
  // pra rejeitar no save mesmo se o front escapar.
  {
    id: '/widgets/conversation/ReplyBox.vue',
    from: `    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      this.hasRecordedAudio = true;`,
    to: `    onFinishRecorder(file) {
      this.recordingAudioState = 'stopped';
      // KLaOS guard: sem file (gravação falhou no encode/upload) não pode
      // setar hasRecordedAudio — senão Send fica habilitado e manda vazio.
      if (!file) return;
      this.hasRecordedAudio = true;`,
    reason: 'empty-msg-fix: guard sem file em onFinishRecorder',
  },
  {
    id: '/widgets/conversation/ReplyBox.vue',
    from: 'if (this.hasAttachments || this.hasRecordedAudio) return false;',
    to: `// KLaOS: hasRecordedAudio só vale se o arquivo do áudio realmente
      // foi anexado (attachedFiles tem item com isRecordedAudio:true).
      // Sem essa checagem, gravação que falhou no upload deixava o botão
      // habilitado e mandava msg vazia.
      const klaosHasRecordedAudioFile = this.attachedFiles?.some(f => f.isRecordedAudio);
      if (this.hasAttachments || (this.hasRecordedAudio && klaosHasRecordedAudioFile)) return false;
      if (this.hasRecordedAudio && !klaosHasRecordedAudioFile) {
        // Reset defensivo: flag está ON mas arquivo sumiu (upload falhou).
        this.hasRecordedAudio = false;
      }`,
    reason: 'empty-msg-fix: isReplyButtonDisabled exige file real do áudio',
  },

  // === KLaOS — Força sort LATEST sempre (Gustavo "perdeu" outras ordens) ===
  // Hoje o Frontdesk persiste o sort por usuário em ui_settings — se o
  // agente troca pra "created_at_desc" sem perceber, a lista para de
  // atualizar com mensagem nova. Decisão: forçar SEMPRE last_activity_at_desc.
  // Multi-tenant. Esconde também o dropdown pra não dar opção de errar.
  {
    id: '/components/ChatList.vue',
    from: `  activeSortBy.value = Object.values(wootConstants.SORT_BY_TYPE).includes(
    orderBy
  )
    ? orderBy
    : wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC;`,
    to: `  // KLaOS: sempre força LATEST, ignora ui_settings persistido. Pedido do
  // Gustavo. Agente não pode "se perder" em outro sort por engano.
  activeSortBy.value = wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC;`,
    reason: 'sort-latest: força LATEST sempre, ignora ui_settings persistido',
  },
  {
    id: '/widgets/conversation/ConversationBasicFilter.vue',
    from: `      <div class="flex items-center justify-between last:mt-4 gap-2">
        <span class="text-sm truncate text-n-slate-12">
          {{ $t('CHAT_LIST.CHAT_SORT.ORDER_BY') }}
        </span>
        <SelectMenu
          :model-value="chatSortFilter"
          :options="chatSortOptions"
          :label="activeChatSortLabel"
          :sub-menu-position="isOnExpandedLayout ? 'left' : 'right'"
          @update:model-value="handleSortChange"
        />
      </div>`,
    to: '<!-- KLaOS: removido sort dropdown (forçamos LATEST sempre) -->',
    reason: 'sort-latest: esconde dropdown de sort no UI',
  },

  // === KLaOS — O.8 Botões grandes status do agente na sidebar ===
  // Substitui o "abrir avatar → clicar status" enterrado por 3 botões
  // grandes Online/Pausa/Offline sempre visíveis acima do avatar.
  {
    id: '/components-next/sidebar/Sidebar.vue',
    from: "import SidebarProfileMenu from './SidebarProfileMenu.vue';",
    to: "import SidebarProfileMenu from './SidebarProfileMenu.vue';\nimport KlaosAgentStatusButtons from 'next/KlaosAgent/StatusButtons.vue';",
    reason: 'O.8 status-buttons: import componente custom',
  },
  {
    id: '/components-next/sidebar/Sidebar.vue',
    from: `      <div
        class="px-1 py-1.5 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-n-weak shadow-[0px_-2px_4px_0px_rgba(27,28,29,0.02)]"
        :class="isEffectivelyCollapsed ? 'justify-center' : 'justify-between'"
      >
        <SidebarProfileMenu`,
    to: `      <KlaosAgentStatusButtons v-if="!isEffectivelyCollapsed" class="border-t border-n-weak" />
      <div
        class="px-1 py-1.5 flex-shrink-0 flex w-full z-50 gap-2 items-center border-t border-n-weak shadow-[0px_-2px_4px_0px_rgba(27,28,29,0.02)]"
        :class="isEffectivelyCollapsed ? 'justify-center' : 'justify-between'"
      >
        <SidebarProfileMenu`,
    reason: 'O.8 status-buttons: renderiza 3 botões acima do avatar',
  },

  // === KLaOS — O.10 Banner janela 24h WhatsApp REFORÇADO ===
  // Upstream tem banner cinza/rosa claro discreto. Agente fica travado e
  // não saca o motivo. Substituímos por banner âmbar gritante com ícone
  // piscante + botão "Usar template".
  {
    id: '/widgets/conversation/MessagesView.vue',
    from: `    <Banner
      v-if="!currentChat.can_reply"
      color-scheme="alert"
      class="mx-2 mt-2 overflow-hidden rounded-lg"
      :banner-message="replyWindowBannerMessage"
      :href-link="replyWindowLink"
      :href-link-text="replyWindowLinkText"
    />`,
    to: `    <KlaosWhatsApp24hBanner v-if="!currentChat.can_reply" />`,
    reason: 'O.10 wa24h-banner: substitui banner upstream discreto pelo Klaos âmbar',
  },
  {
    id: '/widgets/conversation/MessagesView.vue',
    from: "import Banner from 'dashboard/components/ui/Banner.vue';",
    to: "import Banner from 'dashboard/components/ui/Banner.vue';\nimport KlaosWhatsApp24hBanner from 'next/KlaosConversation/WhatsApp24hBanner.vue';",
    reason: 'O.10 wa24h-banner: import componente custom',
  },
  {
    id: '/widgets/conversation/MessagesView.vue',
    from: '    Banner,\n    ConversationLabelSuggestion,',
    to: '    Banner,\n    KlaosWhatsApp24hBanner,\n    ConversationLabelSuggestion,',
    reason: 'O.10 wa24h-banner: registra componente no options API',
  },

  // === KLaOS — O.9 "Tempo desde última msg" badge colorido na card ===
  // Substitui o TimeAgo padrão por um badge mais destacado com faixa de
  // tempo colorida. ESTE patch é INDEPENDENTE do snooze (target diferente).
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: "import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';",
    to: "import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';\nimport KlaosLastActivityBadge from 'next/KlaosConversation/LastActivityBadge.vue';",
    reason: 'O.9 last-activity-badge: import componente custom',
  },
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: `        <span class="ml-auto font-normal leading-4 text-xxs">
          <TimeAgo
            :last-activity-timestamp="chat.timestamp"
            :created-at-timestamp="chat.created_at"
            :conversation-id="chat.id"
          />
        </span>`,
    to: `        <span class="ml-auto leading-4">
          <KlaosLastActivityBadge :timestamp="chat.timestamp" />
        </span>`,
    reason: 'O.9 last-activity-badge: substitui TimeAgo por badge colorido por SLA',
  },

  // === KLaOS — i18n: tradução SNOOZE_PLACEHOLDER em pt_BR (faltava upstream) ===
  // O ninja-keys do modal Adiar usava placeholder "Type a time e.g. tomorrow,
  // 2 hours, next friday, jan 15..." em inglês porque a chave
  // COMMAND_BAR.SNOOZE_PLACEHOLDER NÃO estava traduzida em pt_BR/generalSettings.json.
  {
    id: '/i18n/locale/pt_BR/generalSettings.json',
    from: '    "SEARCH_PLACEHOLDER": "Pesquisar ou pular para",\n    "SECTIONS": {',
    to: '    "SEARCH_PLACEHOLDER": "Pesquisar ou pular para",\n    "SNOOZE_PLACEHOLDER": "Digite um horário ex.: amanhã, 2 horas, próxima sexta, 15 jan...",\n    "SECTIONS": {',
    reason: 'snooze-placeholder-i18n: traduz SNOOZE_PLACEHOLDER em pt_BR',
  },

  // === KLaOS — Snooze: data-attr na ConversationCard pro pulse ===
  // Adiciona data-klaos-conversation-id no root da card pra o componente
  // SnoozeReopenAlert achar e aplicar/remover a CSS class .klaos-pulse
  // durante 60s após reabertura.
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: '@click="onCardClick"\n    @contextmenu="openContextMenu($event)"',
    to: ':data-klaos-conversation-id="chat.id"\n    @click="onCardClick"\n    @contextmenu="openContextMenu($event)"',
    reason: 'snooze-pulse: data-attr na card pro SnoozeReopenAlert localizar e pulsar',
  },

  // === KLaOS — O.11 Ações inline na lista de conversas ===
  // Patch DEPOIS do snooze (que adicionou :data-klaos-conversation-id).
  // Outro patch já adicionou KlaosLastActivityBadge no import — adiciona
  // KlaosInlineActions em sequência usando esse import como âncora.
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: "import KlaosLastActivityBadge from 'next/KlaosConversation/LastActivityBadge.vue';",
    to: "import KlaosLastActivityBadge from 'next/KlaosConversation/LastActivityBadge.vue';\nimport KlaosInlineActions from 'next/KlaosConversation/InlineActions.vue';",
    reason: 'O.11 inline-actions: import (encadeado depois do O.9)',
  },
  {
    id: '/widgets/conversation/ConversationCard.vue',
    from: '    :data-klaos-conversation-id="chat.id"\n    @click="onCardClick"\n    @contextmenu="openContextMenu($event)"\n  >',
    to: '    :data-klaos-conversation-id="chat.id"\n    @click="onCardClick"\n    @contextmenu="openContextMenu($event)"\n  >\n    <KlaosInlineActions :chat="chat" />',
    reason: 'O.11 inline-actions: renderiza botões hover na card',
  },

  // === KLaOS — Snooze: monta SnoozeReopenAlert no App.vue ===
  {
    id: '/dashboard/App.vue',
    from: "import WootSnackbarBox from './components/SnackbarContainer.vue';",
    to: "import WootSnackbarBox from './components/SnackbarContainer.vue';\nimport SnoozeReopenAlert from 'next/KlaosSnooze/SnoozeReopenAlert.vue';",
    reason: 'snooze-reopen-alert: import componente do alerta',
  },
  {
    id: '/dashboard/App.vue',
    from: '    WootSnackbarBox,\n    PendingEmailVerificationBanner,',
    to: '    WootSnackbarBox,\n    SnoozeReopenAlert,\n    PendingEmailVerificationBanner,',
    reason: 'snooze-reopen-alert: registra componente',
  },
  {
    id: '/dashboard/App.vue',
    from: '    <WootSnackbarBox />\n    <NetworkNotification />',
    to: '    <WootSnackbarBox />\n    <SnoozeReopenAlert />\n    <NetworkNotification />',
    reason: 'snooze-reopen-alert: monta no App pra escutar transições snoozed→open globalmente',
  },

  // === KLaOS — Snooze: troca CustomSnoozeModal por KlaosCustomSnoozeModal (Item snooze) ===
  // Corrige 3 bugs reportados pelo Gustavo:
  //   B1 calendário em inglês (lang hardcoded antigo)
  //   B2 calendário colapsado (prop `inline` não existe na lib v1.x)
  //   B3 só data sem hora (type=datetime quebrado)
  // A troca preserva o contrato de eventos (close, chooseTime) do upstream
  // pra CmdBarConversationSnooze não precisar mudar.
  {
    id: '/commands/CmdBarConversationSnooze.vue',
    from: "import CustomSnoozeModal from 'dashboard/components/CustomSnoozeModal.vue';",
    to: "import CustomSnoozeModal from 'next/KlaosSnooze/KlaosCustomSnoozeModal.vue';",
    reason: 'snooze: usa modal custom KLaOS (PT-BR + inline + hora) no lugar do upstream',
  },

  // === KLaOS — Wire do UnassignedLabelInput em Conf > Geral (Item 10) ===
  // Patches em Index.vue DEPOIS dos patches do Item 9 — usam o resultado
  // (KeepAgentsOnlineToggle import + render) como âncora.
  {
    id: '/settings/account/Index.vue',
    from: "import KeepAgentsOnlineToggle from 'next/KlaosAccountSettings/KeepAgentsOnlineToggle.vue';",
    to: "import KeepAgentsOnlineToggle from 'next/KlaosAccountSettings/KeepAgentsOnlineToggle.vue';\nimport UnassignedLabelInput from 'next/KlaosAccountSettings/UnassignedLabelInput.vue';",
    reason: 'rotulo-unassigned: import componente custom',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    KeepAgentsOnlineToggle,\n    SectionLayout,',
    to: '    KeepAgentsOnlineToggle,\n    UnassignedLabelInput,\n    SectionLayout,',
    reason: 'rotulo-unassigned: registra componente no options API',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    <div class="mt-6">\n      <KeepAgentsOnlineToggle />\n    </div>\n    <AccountId />',
    to: '    <div class="mt-6">\n      <KeepAgentsOnlineToggle />\n    </div>\n    <div class="mt-6">\n      <UnassignedLabelInput />\n    </div>\n    <AccountId />',
    reason: 'rotulo-unassigned: renderiza input abaixo do toggle online',
  },

  // === KLaOS — Wire do SnoozeReopenAlertToggle em Conf > Geral (Item snooze B5) ===
  // Patches APÓS Item 10 — usa UnassignedLabelInput como âncora.
  {
    id: '/settings/account/Index.vue',
    from: "import UnassignedLabelInput from 'next/KlaosAccountSettings/UnassignedLabelInput.vue';",
    to: "import UnassignedLabelInput from 'next/KlaosAccountSettings/UnassignedLabelInput.vue';\nimport SnoozeReopenAlertToggle from 'next/KlaosAccountSettings/SnoozeReopenAlertToggle.vue';",
    reason: 'snooze-alert-toggle: import componente custom',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    KeepAgentsOnlineToggle,\n    UnassignedLabelInput,\n    SectionLayout,',
    to: '    KeepAgentsOnlineToggle,\n    UnassignedLabelInput,\n    SnoozeReopenAlertToggle,\n    SectionLayout,',
    reason: 'snooze-alert-toggle: registra componente no options API',
  },
  {
    id: '/settings/account/Index.vue',
    from: '    <div class="mt-6">\n      <UnassignedLabelInput />\n    </div>\n    <AccountId />',
    to: '    <div class="mt-6">\n      <UnassignedLabelInput />\n    </div>\n    <div class="mt-6">\n      <SnoozeReopenAlertToggle />\n    </div>\n    <AccountId />',
    reason: 'snooze-alert-toggle: renderiza abaixo do label IA',
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
