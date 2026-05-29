<script setup>
// KLaOS — Alerta de retorno de conversa adiada (Item snooze, B5).
//
// Quando uma conversa volta do estado "Adiada" (snoozed → open), este
// componente dispara um alerta ESCANDALOSO pra garantir que o agente vê:
//   1. document.title piscando "🔔 Conversa voltou!" alternado com original
//      (4 segundos, 8 piscadas) — chama atenção mesmo se a aba tá em
//      background
//   2. Notification API do browser (push nativo, aparece mesmo com aba
//      minimizada — requer permissão prévia)
//   3. Som tocando 3x em sequência (autoplay policy permitindo)
//   4. Toast no canto da tela
//   5. CSS class .klaos-pulse na card da conv na lista (pulsa por 60s)
//
// Multi-tenant: liga/desliga via toggle por conta
// `account.settings.snooze_reopen_alert` (default OFF — opt-in por conta).
//
// Funcionamento: watcher no store rastreia status anterior de cada conv
// em memória. Quando detecta transição snoozed → open, dispara o alerta.
// Sem polling, sem chamada de rede extra — apenas reage ao update que já
// vem via ActionCable do upstream.
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';

// KLaOS custom event broadcastado pelo backend
// (custom/config/initializers/klaos_snooze_no_limit.rb) sempre que uma conv
// adiada reabre. ActionCable.js (via patch klaos-patches) escuta e emite via
// mitt emitter, e este componente reage.
const KLAOS_SNOOZE_REOPENED_EVENT = 'klaos.snooze_reopened';

const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');

const account = computed(() =>
  store.getters['accounts/getAccount'](currentAccountId.value)
);

const isEnabled = computed(
  () => account.value?.settings?.snooze_reopen_alert === true
);

// Map: conversation_id -> previous status. Não armazena conversas com
// status diferente de 'snoozed' (memória controlada).
const prevStatus = ref(new Map());

// Banner top de alerta visível mesmo com aba ATIVA (Chrome esconde push
// notification quando aba está em foco). Array de alertas ativos.
const activeAlerts = ref([]);

const dismissAlert = id => {
  activeAlerts.value = activeAlerts.value.filter(a => a.id !== id);
};

const openConversation = convId => {
  const accountId = currentAccountId.value;
  if (!accountId || !convId) return;
  window.location.href = `/app/accounts/${accountId}/conversations/${convId}`;
};

// Áudio: usa o ding do Chatwoot que já existe em public/audio/dashboard.
let alertAudio = null;
const initAudio = () => {
  try {
    alertAudio = new Audio('/audio/dashboard/ding.mp3');
    alertAudio.volume = 1.0;
  } catch (e) {
    alertAudio = null;
  }
};

const playSoundLoud = async () => {
  if (!alertAudio) return;
  for (let i = 0; i < 3; i += 1) {
    try {
      alertAudio.currentTime = 0;
      await alertAudio.play().catch(() => {});
    } catch (e) {
      /* noop */
    }
    await new Promise(r => setTimeout(r, 800));
  }
};

// Pisca document.title. Faz 8 ciclos (4s total).
let originalTitle = null;
let titleInterval = null;
const startTitlePulse = senderName => {
  if (titleInterval) clearInterval(titleInterval);
  if (!originalTitle) originalTitle = document.title;
  const alertTitle = `🔔 ${senderName} voltou!`;
  let toggled = false;
  let count = 0;
  titleInterval = setInterval(() => {
    document.title = toggled ? originalTitle : alertTitle;
    toggled = !toggled;
    count += 1;
    if (count >= 16) {
      // 8 piscadas (16 trocas a 500ms cada = 8s)
      clearInterval(titleInterval);
      titleInterval = null;
      document.title = originalTitle;
    }
  }, 500);
};

// Notification API — push nativo. Pede permissão na 1a vez.
let notificationPermissionAsked = false;
const ensureNotifPermission = async () => {
  if (notificationPermissionAsked) return;
  notificationPermissionAsked = true;
  if ('Notification' in window && Notification.permission === 'default') {
    try {
      await Notification.requestPermission();
    } catch (e) {
      /* noop */
    }
  }
};

const fireBrowserNotification = (senderName, convId) => {
  if (!('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const notif = new Notification(`🔔 ${senderName} voltou do adiamento`, {
      body: `Clique pra abrir. Conversa #${convId}.`,
      icon: '/favicon-32x32.png',
      tag: `klaos-snooze-reopen-${convId}`,
      requireInteraction: true,
    });
    notif.onclick = () => {
      window.focus();
      notif.close();
    };
  } catch (e) {
    /* noop */
  }
};

const pulseConversationCard = convId => {
  const apply = () => {
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) card.classList.add('klaos-pulse');
  };
  apply();
  setTimeout(apply, 1000);
  setTimeout(() => {
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) card.classList.remove('klaos-pulse');
  }, 60000);
};

const handleReopen = conversation => {
  const senderName =
    conversation.meta?.sender?.name || `Conv #${conversation.id}`;
  // eslint-disable-next-line no-console
  console.warn(
    '[KlaosSnoozeReopenAlert] CONVERSA VOLTOU DO ADIAMENTO',
    conversation.id,
    senderName
  );

  playSoundLoud();
  startTitlePulse(senderName);
  fireBrowserNotification(senderName, conversation.id);
  pulseConversationCard(conversation.id);
  // Banner fixed no topo — NÃO some sozinho. Visível mesmo com aba ativa.
  activeAlerts.value.push({
    id: `${conversation.id}-${Date.now()}`,
    conversationId: conversation.id,
    senderName,
    when: new Date(),
  });
};

const conversationsList = computed(
  () => store.state.conversations?.allConversations || []
);

watch(
  conversationsList,
  newList => {
    if (!isEnabled.value) {
      // Atualiza prevStatus mesmo desligado pra não disparar avalanche
      // se o admin ligar o toggle.
      for (const c of newList) prevStatus.value.set(c.id, c.status);
      return;
    }
    for (const conv of newList) {
      const before = prevStatus.value.get(conv.id);
      if (before === 'snoozed' && conv.status === 'open') {
        handleReopen(conv);
      }
      prevStatus.value.set(conv.id, conv.status);
    }
  },
  { deep: true }
);

// Escuta o evento ActionCable custom broadcastado pelo backend quando
// reabre conv adiada. Usar window.bus (mitt emitter do Chatwoot) que recebe
// TODOS os eventos de ActionCable como bus.on(event_name, data).
const onKlaosSnoozeReopened = data => {
  if (!isEnabled.value) return;
  handleReopen({
    id: data?.conversation_id || data?.id,
    meta: { sender: { name: data?.sender_name || 'Conv' } },
  });
};

onMounted(() => {
  initAudio();
  ensureNotifPermission();
  // Hook global pra debug manual: window.__klaosTestSnoozeReopen('Nome')
  window.__klaosTestSnoozeReopen = name => {
    handleReopen({
      id: 999999,
      meta: { sender: { name: name || 'Teste KLaOS' } },
    });
  };
  emitter.on(KLAOS_SNOOZE_REOPENED_EVENT, onKlaosSnoozeReopened);
});
onBeforeUnmount(() => {
  if (titleInterval) {
    clearInterval(titleInterval);
    if (originalTitle) document.title = originalTitle;
  }
  if (alertAudio) {
    try {
      alertAudio.pause();
    } catch (e) {
      /* noop */
    }
    alertAudio = null;
  }
  delete window.__klaosTestSnoozeReopen;
  emitter.off(KLAOS_SNOOZE_REOPENED_EVENT, onKlaosSnoozeReopened);
});
</script>

<template>
  <!-- Estilo global pra pulso das cards -->
  <teleport to="head">
    <component :is="'style'">
      {{
        `@keyframes klaos-pulse-anim {
          0%, 100% { background-color: transparent; }
          50% { background-color: rgba(251, 191, 36, 0.25); }
        }
        .klaos-pulse {
          animation: klaos-pulse-anim 0.8s ease-in-out infinite;
          box-shadow: inset 4px 0 0 #f59e0b;
        }
        @keyframes klaos-banner-blink {
          0%, 50% { background: linear-gradient(90deg, #dc2626 0%, #b91c1c 100%); }
          51%, 100% { background: linear-gradient(90deg, #f59e0b 0%, #d97706 100%); }
        }
        .klaos-snooze-banner {
          position: fixed; top: 0; left: 0; right: 0; z-index: 9999;
          padding: 14px 20px;
          color: white;
          font-weight: 600; font-size: 16px;
          box-shadow: 0 4px 12px rgba(0,0,0,0.25);
          animation: klaos-banner-blink 1s ease-in-out infinite;
          display: flex; justify-content: space-between; align-items: center;
          gap: 12px;
        }
        .klaos-snooze-banner__content { flex: 1; }
        .klaos-snooze-banner__open {
          background: white; color: #b91c1c;
          padding: 6px 14px; border-radius: 6px; border: none;
          font-weight: 700; cursor: pointer; font-size: 14px;
        }
        .klaos-snooze-banner__close {
          background: transparent; color: white; border: 1px solid rgba(255,255,255,0.5);
          padding: 6px 10px; border-radius: 6px; cursor: pointer; font-size: 14px;
        }`
      }}
    </component>
  </teleport>

  <!-- Banner fixed no topo: empilha um pra cada alerta ativo -->
  <teleport to="body">
    <div v-if="activeAlerts.length" style="position: fixed; top: 0; left: 0; right: 0; z-index: 9999;">
      <div
        v-for="alert in activeAlerts"
        :key="alert.id"
        class="klaos-snooze-banner"
        :style="{ position: 'static', marginBottom: '2px' }"
      >
        <span class="klaos-snooze-banner__content">
          🔔 Conversa com <b>{{ alert.senderName }}</b> voltou do adiamento — atender agora?
        </span>
        <button class="klaos-snooze-banner__open" @click="openConversation(alert.conversationId)">
          Abrir
        </button>
        <button class="klaos-snooze-banner__close" @click="dismissAlert(alert.id)">
          ✕
        </button>
      </div>
    </div>
  </teleport>
</template>
