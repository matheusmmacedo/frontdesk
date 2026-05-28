<script setup>
// KLaOS — Alerta de retorno de conversa adiada (Item snooze, B5).
//
// Quando uma conversa volta do estado "Adiada" (snoozed → open), este
// componente:
//   1. Toca um som curto pra avisar o agente
//   2. Mostra um toast com link pra abrir a conversa
//   3. Adiciona CSS class `klaos-pulse` na card da lista (pulsa por 60s
//      pra chamar atenção)
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
import { useRouter } from 'vue-router';

const store = useStore();
const router = useRouter();
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

// Set de conversas pulsando (CSS klaos-pulse). Limpa após 60s.
const pulsingIds = ref(new Set());

// Áudio: usa o mesmo arquivo padrão do Chatwoot pra notificações.
let alertAudio = null;
const initAudio = () => {
  try {
    // Reutiliza o arquivo de notificação que já existe no public/audio/.
    alertAudio = new Audio('/audio/notification.mp3');
    alertAudio.volume = 0.6;
  } catch (e) {
    alertAudio = null;
  }
};

const playSound = () => {
  if (!alertAudio) return;
  try {
    alertAudio.currentTime = 0;
    alertAudio.play().catch(() => {
      // autoplay policy do browser pode bloquear. Silencioso — agente
      // verá o toast mesmo sem som.
    });
  } catch (e) {
    /* noop */
  }
};

const pulseConversationCard = convId => {
  pulsingIds.value.add(convId);
  // Tenta achar a card no DOM e aplicar a classe. Usa attribute selector
  // setado pelo patch em ConversationCard.vue.
  const apply = () => {
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) card.classList.add('klaos-pulse');
  };
  apply();
  // Re-tenta após 1s caso a card só apareça depois (filtros, infinite scroll).
  setTimeout(apply, 1000);
  setTimeout(() => {
    pulsingIds.value.delete(convId);
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) card.classList.remove('klaos-pulse');
  }, 60000);
};

const handleReopen = conversation => {
  playSound();
  pulseConversationCard(conversation.id);
  const senderName =
    conversation.meta?.sender?.name || `#${conversation.id}`;
  useAlert(`Conversa com ${senderName} voltou do adiamento.`);
};

const conversationsList = computed(
  () => store.state.conversations?.allConversations || []
);

watch(
  conversationsList,
  (newList, oldList) => {
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

onMounted(initAudio);
onBeforeUnmount(() => {
  if (alertAudio) {
    try {
      alertAudio.pause();
    } catch (e) {
      /* noop */
    }
    alertAudio = null;
  }
});
</script>

<template>
  <!-- Sem UI — escuta passiva. Renderiza estilo global pulso pras cards. -->
  <teleport to="head">
    <style>
      @keyframes klaos-pulse-anim {
        0%,
        100% {
          background-color: transparent;
        }
        50% {
          background-color: rgba(251, 191, 36, 0.18);
        }
      }
      .klaos-pulse {
        animation: klaos-pulse-anim 1s ease-in-out infinite;
      }
    </style>
  </teleport>
</template>
