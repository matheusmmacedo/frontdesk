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
const AUTO_DISMISS_MS = 18000;

const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const selectedChat = useMapGetter('getSelectedChat');

const pulsingConvIds = ref(new Set());
const alerts = ref([]);

const dismiss = id => {
  alerts.value = alerts.value.filter(a => a.id !== id);
};

const openConversation = displayId => {
  if (!currentAccountId.value || !displayId) return;
  window.location.href = `/app/accounts/${currentAccountId.value}/conversations/${displayId}`;
};

const pushAlert = (mode, payload) => {
  const id = `${payload.conversation_id}-${mode}-${Date.now()}`;
  alerts.value.push({
    id,
    mode,
    displayId: payload.conversation_display_id,
    contactName: payload.contact_name || `Conversa #${payload.conversation_display_id}`,
    fromAgent: payload.previous_assignee?.name,
    toAgent: payload.new_assignee?.name,
    inboxName: payload.inbox_name,
  });
  setTimeout(() => dismiss(id), AUTO_DISMISS_MS);
};

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
  const tryApply = () => {
    const card = document.querySelector(
      `[data-klaos-conversation-id="${convId}"]`
    );
    if (card) {
      card.classList.add(PULSE_CLASS);
      return true;
    }
    return false;
  };

  const afterApplied = () => {
    if (selectedChat.value?.id === convId) {
      setTimeout(() => removePulse(convId), 4000);
    }
  };

  // Tenta imediatamente; se já aplicou, finaliza
  if (tryApply()) {
    afterApplied();
    return;
  }

  // Card ainda não no DOM (Minhas list atualizando após assign) — usa
  // MutationObserver pra detectar quando aparece, com timeout 15s
  const observer = new MutationObserver(() => {
    if (tryApply()) {
      observer.disconnect();
      clearTimeout(killTimer);
      afterApplied();
    }
  });
  observer.observe(document.body, { childList: true, subtree: true });
  const killTimer = setTimeout(() => observer.disconnect(), 15000);
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
  pushAlert('in', payload);
  playSoundLight();
  fireBrowserNotification(
    '📥 Nova conversa atribuída',
    `${payload.contact_name || 'Cliente'} foi transferido pra você` +
      (payload.previous_assignee ? ` (de ${payload.previous_assignee.name})` : ''),
    `klaos-assign-${convId}`
  );
};

const onUnassignedFromMe = payload => {
  pushAlert('out', payload);
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
  <teleport to="body">
    <div v-if="alerts.length" class="klaos-handoff-stack">
      <article
        v-for="alert in alerts"
        :key="alert.id"
        class="klaos-handoff"
        :class="alert.mode === 'in' ? 'klaos-handoff--in' : 'klaos-handoff--out'"
      >
        <div class="klaos-handoff__icon" aria-hidden="true">
          {{ alert.mode === 'in' ? '📥' : '📤' }}
        </div>
        <div class="klaos-handoff__body">
          <div class="klaos-handoff__title">
            <template v-if="alert.mode === 'in'">
              Nova conversa atribuída a você
            </template>
            <template v-else>
              Conversa transferida
            </template>
          </div>
          <div class="klaos-handoff__desc">
            <strong>{{ alert.contactName }}</strong>
            <template v-if="alert.mode === 'in' && alert.fromAgent">
              · de {{ alert.fromAgent }}
            </template>
            <template v-else-if="alert.mode === 'out' && alert.toAgent">
              · para {{ alert.toAgent }}
            </template>
            <template v-if="alert.inboxName">
              <span class="klaos-handoff__inbox">{{ alert.inboxName }}</span>
            </template>
          </div>
        </div>
        <div class="klaos-handoff__actions">
          <button
            v-if="alert.mode === 'in'"
            type="button"
            class="klaos-handoff__open"
            @click="openConversation(alert.displayId)"
          >
            Abrir
          </button>
          <button
            type="button"
            class="klaos-handoff__close"
            aria-label="Fechar"
            @click="dismiss(alert.id)"
          >
            ✕
          </button>
        </div>
      </article>
    </div>
  </teleport>
</template>

<style scoped>
.klaos-handoff-stack {
  position: fixed;
  top: 16px;
  right: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 99999;
  width: min(380px, calc(100vw - 32px));
  pointer-events: none;
}
.klaos-handoff {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 10px;
  background: white;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  border-left: 4px solid currentColor;
  pointer-events: auto;
  animation: klaos-handoff-in 0.25s ease-out;
}
@keyframes klaos-handoff-in {
  from { transform: translateX(20px); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}
.klaos-handoff--in { color: #059669; }
.klaos-handoff--out { color: #d97706; }
.klaos-handoff__icon {
  font-size: 22px;
  line-height: 1;
  flex-shrink: 0;
  margin-top: 2px;
}
.klaos-handoff__body { flex: 1; min-width: 0; }
.klaos-handoff__title {
  font-size: 13px;
  font-weight: 700;
  color: #111827;
  line-height: 1.2;
}
.klaos-handoff__desc {
  font-size: 12px;
  color: #374151;
  margin-top: 3px;
  line-height: 1.35;
  word-break: break-word;
}
.klaos-handoff__desc strong { color: #111827; font-weight: 600; }
.klaos-handoff__inbox {
  display: inline-block;
  margin-left: 6px;
  padding: 1px 7px;
  border-radius: 999px;
  background: #f3f4f6;
  color: #4b5563;
  font-size: 10px;
  font-weight: 500;
}
.klaos-handoff__actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}
.klaos-handoff__open {
  background: #059669;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}
.klaos-handoff__open:hover { background: #047857; }
.klaos-handoff__close {
  background: transparent;
  border: none;
  color: #6b7280;
  font-size: 14px;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  line-height: 1;
}
.klaos-handoff__close:hover { background: #f3f4f6; color: #111827; }
@media (max-width: 600px) {
  .klaos-handoff-stack { top: 12px; right: 12px; left: 12px; width: auto; }
  .klaos-handoff__open { padding: 5px 10px; font-size: 11px; }
}
</style>
