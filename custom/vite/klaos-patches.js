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
          label: 'Prefixo mensagens humanas',
          icon: 'i-lucide-message-square-text',
          to: accountScopedRoute('klaos_message_prefix_index'),
        },`,
    reason: 'add KLaOS message prefix entry in settings sidebar',
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
