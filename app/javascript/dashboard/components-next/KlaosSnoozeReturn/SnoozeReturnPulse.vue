<script setup>
// KLaOS — Pulse ÂMBAR persistente na card de conversas que voltaram do
// adiamento. Análogo ao ConversationHandoffAlert (azul, transferência) e
// NewMessageAlert (verde, nova mensagem), mas com borda no TOPO pra
// diferenciar visualmente das outras duas que ocupam as laterais.
//
// Funcionamento (igual aos outros pulses):
//   - GET /api/custom/v1/.../snooze_returns no mount pra puxar lista
//     persistente (mesmo após reload — diferente do banner volátil)
//   - Aplica `.klaos-snooze-return-pulse` em cada card via querySelector
//     no `data-klaos-conversation-id`
//   - Polling 500ms re-aplica a classe pra resistir a Vue re-renders
//   - Quando user clica e abre a conv → remove pulse só daquela
//   - LocalStorage por account+user pra sobreviver navegação
//   - Refresh a cada 60s pra puxar novas convs reabertas
import { ref, watch, onMounted, onBeforeUnmount } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const PULSE_CLASS = 'klaos-snooze-return-pulse';

const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');
const selectedChat = useMapGetter('getSelectedChat');

const pulsingConvIds = ref(new Set());
let pollInterval = null;
let refreshInterval = null;

const storageKey = () =>
  `klaos.snooze_return_pulsing.${currentAccountId.value || 0}.${currentUserId.value || 0}`;

const persistPulsing = () => {
  try {
    localStorage.setItem(
      storageKey(),
      JSON.stringify(Array.from(pulsingConvIds.value))
    );
  } catch (e) { /* noop */ }
};

const restorePulsing = () => {
  try {
    const raw = localStorage.getItem(storageKey());
    if (!raw) return;
    const ids = JSON.parse(raw);
    if (Array.isArray(ids)) ids.forEach(id => pulsingConvIds.value.add(id));
  } catch (e) { /* noop */ }
};

const applyPulseLoop = () => {
  if (pollInterval) clearInterval(pollInterval);
  pollInterval = setInterval(() => {
    if (pulsingConvIds.value.size === 0) return;
    for (const id of pulsingConvIds.value) {
      const card = document.querySelector(`[data-klaos-conversation-id="${id}"]`);
      if (card) card.classList.add(PULSE_CLASS);
    }
  }, 500);
};

const removePulse = convId => {
  if (!pulsingConvIds.value.has(convId)) return;
  pulsingConvIds.value.delete(convId);
  persistPulsing();
  const card = document.querySelector(`[data-klaos-conversation-id="${convId}"]`);
  if (card) card.classList.remove(PULSE_CLASS);
};

const fetchReturns = async () => {
  const acct = currentAccountId.value;
  if (!acct) return;
  try {
    const r = await window.axios.get(
      `/api/custom/v1/accounts/${acct}/snooze_returns`
    );
    const items = r.data?.items || [];
    // display_id é o ID que o ChatList usa no data-attr (NÃO o id interno)
    items.forEach(item => {
      pulsingConvIds.value.add(item.display_id);
    });
    persistPulsing();
  } catch (e) { /* noop */ }
};

// Watcher: quando user abre uma conv, remove pulse só daquela.
watch(
  () => selectedChat.value?.id,
  newId => {
    if (newId && pulsingConvIds.value.has(newId)) {
      setTimeout(() => removePulse(newId), 600);
    }
  }
);

onMounted(() => {
  restorePulsing();
  applyPulseLoop();
  fetchReturns();
  // Re-busca a cada 60s pra pegar convs reabertas durante a sessão
  refreshInterval = setInterval(fetchReturns, 60000);
});

onBeforeUnmount(() => {
  if (pollInterval) clearInterval(pollInterval);
  if (refreshInterval) clearInterval(refreshInterval);
});
</script>

<template>
  <!-- Nada renderizado. Trabalho é todo via DOM manipulation. -->
</template>
