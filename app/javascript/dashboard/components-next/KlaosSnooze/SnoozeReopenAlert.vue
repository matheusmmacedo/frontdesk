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
  useAlert(`🔔 ${senderName} voltou do adiamento — clique pra atender.`);
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
});
</script>

<template>
  <!-- Sem UI — escuta passiva. Estilo global pra pulso das cards. -->
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
        }`
      }}
    </component>
  </teleport>
</template>
