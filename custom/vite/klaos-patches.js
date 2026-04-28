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
      class="me-3 outline outline-1 outline-n-container shadow rounded-lg"
      :is-loading="isLoading"
      :disabled="isLoading"
      @click="transferToBot"
    />
    <ButtonGroup`,
    reason: 'devolver-ao-bot: botão visível ao lado do Resolver',
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
