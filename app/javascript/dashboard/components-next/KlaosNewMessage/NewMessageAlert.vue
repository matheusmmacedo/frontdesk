<script setup>
// KLaOS — Sinal de nova mensagem (paridade Kualiz).
//
// Comportamento (Kualiz-like, decisão Matheus 2026-06-09):
//   - SEM banner top-right (removido — feedback Matheus/Gustavo)
//   - Pulse VERDE persistente na card da conv na lista
//   - Pulse fica até o agente ABRIR a conv (selectedChat.id === convId)
//   - Conv sobe pro TOPO (bump local de last_activity_at)
//   - Som leve (1 ding) + push nativo (se permission granted)
//
// Filtros (quem recebe o pulse):
//   - Só msg de CLIENTE (incoming, não privada)
//   - Conv atribuída AO USUÁRIO ATUAL (assignee === me)
//     → conv LIVRE (sem assignee) NÃO pulsa (decisão: fica neutra)
//     → conv de OUTRO agente NÃO pulsa
//     → conv com bot atendendo (status=pending OU assignee_agent_bot)
//       NÃO pulsa
//   - Conv ATIVA (aberta agora) PULSA mesmo assim por 4s (decisão Matheus
//     2026-06-09: sinal extra mesmo se já vendo)
import { ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';

const KLAOS_MESSAGE_CREATED = 'klaos.message_created';
const PULSE_CLASS = 'klaos-newmsg-pulse';

const store = useStore();
const currentUserId = useMapGetter('getCurrentUserID');
const selectedChat = useMapGetter('getSelectedChat');

const pulsingConvIds = ref(new Set());

let alertAudio = null;
const initAudio = () => {
  try {
    alertAudio = new Audio('/audio/dashboard/ding.mp3');
    alertAudio.volume = 0.5;
  } catch (e) {
    alertAudio = null;
  }
};

const playSound = async () => {
  if (!alertAudio) return;
  try {
    alertAudio.currentTime = 0;
    await alertAudio.play().catch(() => {});
  } catch (e) {
    /* noop */
  }
};

let notifPermissionAsked = false;
const ensureNotifPermission = async () => {
  if (notifPermissionAsked) return;
  notifPermissionAsked = true;
  if ('Notification' in window && Notification.permission === 'default') {
    try {
      await Notification.requestPermission();
    } catch (e) {
      /* noop */
    }
  }
};

const fireBrowserNotification = (senderName, content, convId) => {
  if (!('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const notif = new Notification(`💬 ${senderName}`, {
      body: content || 'Nova mensagem',
      icon: '/favicon-32x32.png',
      tag: `klaos-newmsg-${convId}`,
      requireInteraction: false,
    });
    notif.onclick = () => {
      window.focus();
      notif.close();
    };
    setTimeout(() => notif.close(), 8000);
  } catch (e) {
    /* noop */
  }
};

const applyPulse = convId => {
  pulsingConvIds.value.add(convId);
  const apply = () => {
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) card.classList.add(PULSE_CLASS);
  };
  apply();
  setTimeout(apply, 500);
  setTimeout(apply, 1500);

  // Conv ativa (já tô vendo): pulsa por 4s e some
  if (selectedChat.value?.id === convId) {
    setTimeout(() => removePulse(convId), 4000);
  }
};

const removePulse = convId => {
  if (!pulsingConvIds.value.has(convId)) return;
  pulsingConvIds.value.delete(convId);
  const card = document.querySelector(
    `[data-klaos-conversation-id="${convId}"]`
  );
  if (card) card.classList.remove(PULSE_CLASS);
};

const bumpToTop = convId => {
  try {
    store.dispatch('updateConversationLastActivity', {
      conversationId: convId,
      lastActivityAt: Math.floor(Date.now() / 1000),
    });
  } catch (e) {
    /* noop */
  }
};

const onMessageCreated = data => {
  if (!data) return;

  // 1. Só mensagens de CLIENTE (incoming)
  if (data.message_type !== 0 && data.message_type !== 'incoming') return;
  // 2. Pula privadas / activity
  if (data.private) return;

  const conv = data.conversation || {};
  const convId = data.conversation_id || conv.id;
  if (!convId) return;

  // 3. Pula se um BOT (AgentBot) está atendendo
  const status = conv.status || data.status;
  if (status === 'pending') return;
  const botId =
    conv.meta?.assignee_bot?.id ||
    conv.assignee_agent_bot_id ||
    conv.assignee_agent_bot?.id;
  if (botId) return;

  // 4. Só pulsa se conv é MINHA. Livre (assignee=null) NÃO pulsa.
  // Decisão Matheus 2026-06-09: conv livre fica neutra.
  const assigneeId = conv.meta?.assignee?.id || conv.assignee_id;
  if (!assigneeId) return;
  if (assigneeId !== currentUserId.value) return;

  const senderName =
    conv.meta?.sender?.name ||
    data.sender?.name ||
    `Conversa #${conv.display_id || convId}`;
  const content = (data.content || '').slice(0, 100);

  bumpToTop(convId);
  applyPulse(convId);
  playSound();
  fireBrowserNotification(senderName, content, convId);
};

watch(
  () => selectedChat.value?.id,
  newId => {
    if (newId && pulsingConvIds.value.has(newId)) {
      setTimeout(() => removePulse(newId), 600);
    }
  }
);

onMounted(() => {
  initAudio();
  ensureNotifPermission();
  emitter.on(KLAOS_MESSAGE_CREATED, onMessageCreated);
});

onBeforeUnmount(() => {
  emitter.off(KLAOS_MESSAGE_CREATED, onMessageCreated);
});
</script>

<template>
  <!-- Headless: sem UI. Sinal vai na card da lista (.klaos-newmsg-pulse). -->
</template>
