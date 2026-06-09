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
const AUTO_DISMISS_MS = 8000;

const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');
const currentUserId = useMapGetter('getCurrentUserID');
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

  if (tryApply()) {
    afterApplied();
    return;
  }

  // Polling cada 250ms até 20s (re-aplica em re-renders do Vue)
  let attempts = 0;
  const interval = setInterval(() => {
    attempts += 1;
    if (!pulsingConvIds.value.has(convId)) {
      clearInterval(interval);
      return;
    }
    tryApply();
    if (attempts > 80) {
      clearInterval(interval);
      afterApplied();
    } else if (attempts === 1 && tryApply()) {
      afterApplied();
    }
  }, 250);
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

  // data.conversation.id é o display_id (api serializa assim).
  // Card na lista usa chat.id que = display_id. Sempre preferir conv.id.
  const conv = data.conversation || {};
  const convId = conv.id || conv.display_id || data.conversation_id;
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

  const id = `${convId}-${data.id || Date.now()}`;
  alerts.value.push({
    id,
    convId,
    displayId: conv.display_id || convId,
    senderName,
    content,
    inboxName: conv.inbox?.name || data.inbox?.name,
  });
  setTimeout(() => dismiss(id), AUTO_DISMISS_MS);

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
  <teleport to="body">
    <div v-if="alerts.length" class="klaos-newmsg-stack">
      <article v-for="alert in alerts" :key="alert.id" class="klaos-newmsg">
        <div class="klaos-newmsg__icon" aria-hidden="true">💬</div>
        <div class="klaos-newmsg__body">
          <div class="klaos-newmsg__title">
            Nova mensagem
            <template v-if="alert.inboxName">
              <span class="klaos-newmsg__inbox">{{ alert.inboxName }}</span>
            </template>
          </div>
          <div class="klaos-newmsg__sender">{{ alert.senderName }}</div>
          <div v-if="alert.content" class="klaos-newmsg__content">{{ alert.content }}</div>
        </div>
        <div class="klaos-newmsg__actions">
          <button
            type="button"
            class="klaos-newmsg__open"
            @click="openConversation(alert.displayId)"
          >
            Abrir
          </button>
          <button
            type="button"
            class="klaos-newmsg__close"
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
.klaos-newmsg-stack {
  position: fixed;
  top: 16px;
  right: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  z-index: 99998;
  width: min(380px, calc(100vw - 32px));
  pointer-events: none;
}
.klaos-newmsg {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 12px 14px;
  border-radius: 10px;
  background: white;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  border-left: 4px solid #2563eb;
  pointer-events: auto;
  animation: klaos-newmsg-in 0.25s ease-out;
}
@keyframes klaos-newmsg-in {
  from { transform: translateX(20px); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}
.klaos-newmsg__icon { font-size: 22px; line-height: 1; flex-shrink: 0; margin-top: 2px; }
.klaos-newmsg__body { flex: 1; min-width: 0; }
.klaos-newmsg__title {
  font-size: 13px; font-weight: 700; color: #1e40af; line-height: 1.2;
  display: flex; align-items: center; gap: 6px; flex-wrap: wrap;
}
.klaos-newmsg__inbox {
  display: inline-block; padding: 1px 7px; border-radius: 999px;
  background: #f3f4f6; color: #4b5563; font-size: 10px; font-weight: 500;
}
.klaos-newmsg__sender {
  font-size: 12px; font-weight: 600; color: #111827; margin-top: 3px; line-height: 1.3;
}
.klaos-newmsg__content {
  font-size: 12px; color: #4b5563; margin-top: 2px; line-height: 1.35;
  word-break: break-word; overflow: hidden;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
}
.klaos-newmsg__actions { display: flex; align-items: center; gap: 4px; flex-shrink: 0; }
.klaos-newmsg__open {
  background: #2563eb; color: white; border: none;
  padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; cursor: pointer;
}
.klaos-newmsg__open:hover { background: #1d4ed8; }
.klaos-newmsg__close {
  background: transparent; border: none; color: #6b7280;
  font-size: 14px; cursor: pointer; padding: 4px 8px; border-radius: 4px; line-height: 1;
}
.klaos-newmsg__close:hover { background: #f3f4f6; color: #111827; }
@media (max-width: 600px) {
  .klaos-newmsg-stack { top: 12px; right: 12px; left: 12px; width: auto; }
}
</style>
