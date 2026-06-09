<script setup>
// KLaOS — Sinal de transferência de conversa (paridade Kualiz).
//
// Comportamento (Kualiz-like, decisão Matheus 2026-06-09):
//   - SEM banner top-right (removido — feedback Matheus/Gustavo)
//   - Pulse AZUL persistente na card da conv na lista
//   - Pulse fica até o agente ABRIR a conv (selectedChat.id === convId)
//   - Conv sobe pro TOPO da lista (bump local de last_activity_at,
//     não toca no banco — não polui SLA)
//   - Som leve (1 ding) + push nativo no IN (se permission granted)
//
// Reage a 2 eventos custom broadcastados pelo backend
// (custom/config/initializers/klaos_conversation_handoff_broadcast.rb):
//   1. klaos.conversation_assigned_to_me   → conv atribuída A MIM (pulsa)
//   2. klaos.conversation_unassigned_from_me → conv tirada DE MIM (silencioso,
//      só remove pulse se ainda estava pulsando)
import { ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';

const KLAOS_ASSIGNED_TO_ME = 'klaos.conversation_assigned_to_me';
const KLAOS_UNASSIGNED_FROM_ME = 'klaos.conversation_unassigned_from_me';
const PULSE_CLASS = 'klaos-handoff-pulse';

const store = useStore();
const selectedChat = useMapGetter('getSelectedChat');

const pulsingConvIds = ref(new Set());

let alertAudio = null;

const initAudio = () => {
  try {
    alertAudio = new Audio('/audio/dashboard/ding.mp3');
    alertAudio.volume = 0.55;
  } catch (e) {
    alertAudio = null;
  }
};

const playSoundLight = async () => {
  if (!alertAudio) return;
  try {
    alertAudio.currentTime = 0;
    await alertAudio.play().catch(() => {});
  } catch (e) {
    /* noop */
  }
};

const fireBrowserNotification = (title, body, tag) => {
  if (!('Notification' in window)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const notif = new Notification(title, {
      body,
      icon: '/favicon-32x32.png',
      tag,
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
  // re-aplica em 500ms e 1500ms caso a card só renderize depois (bump
  // pode ter movido a conv pra dentro da viewport agora — DOM novo)
  setTimeout(apply, 500);
  setTimeout(apply, 1500);

  // Conv já ativa quando recebeu transferência? Some em 4s (já tô vendo)
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

// Bump pro topo: seta last_activity_at = now no store local.
// A lista já ordena por last_activity_at desc → conv sobe.
// NÃO toca no banco — só visual local. Backend mantém valor real.
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

const onAssignedToMe = payload => {
  const convId = payload?.conversation_id;
  if (!convId) return;

  bumpToTop(convId);
  applyPulse(convId);
  playSoundLight();
  fireBrowserNotification(
    '📥 Nova conversa atribuída',
    `${payload.contact_name || 'Cliente'} foi transferido pra você` +
      (payload.previous_assignee ? ` (de ${payload.previous_assignee.name})` : ''),
    `klaos-assign-${convId}`
  );
};

const onUnassignedFromMe = payload => {
  // Conv saiu de mim — se ainda estava pulsando, para
  const convId = payload?.conversation_id;
  if (convId) removePulse(convId);
};

// Watcher: quando agente abre a conv, remove o pulse (com pequeno delay
// pra ele ver a card piscando antes de sumir).
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
  emitter.on(KLAOS_ASSIGNED_TO_ME, onAssignedToMe);
  emitter.on(KLAOS_UNASSIGNED_FROM_ME, onUnassignedFromMe);
});

onBeforeUnmount(() => {
  emitter.off(KLAOS_ASSIGNED_TO_ME, onAssignedToMe);
  emitter.off(KLAOS_UNASSIGNED_FROM_ME, onUnassignedFromMe);
});
</script>

<template>
  <!-- Headless: sem UI. Sinal vai na card da lista (.klaos-handoff-pulse). -->
</template>
