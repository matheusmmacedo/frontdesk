<script setup>
// KLaOS — Banner gritante quando a conexão WebSocket cai (paridade
// Kualiz, problema reportado pelo Gustavo).
//
// Sintoma reportado: "às vezes permanece constantemente desconectado e
// alguém manda mensagem, a gente não vê". Chatwoot já tenta reconectar
// silenciosamente, mas o agente NÃO SABE que está offline — fica
// achando que as conversas estão paradas quando na verdade não tá
// recebendo eventos novos.
//
// Solução: escutar BUS_EVENTS.WEBSOCKET_DISCONNECT / RECONNECT que o
// próprio actionCable.js do Chatwoot já emite. Banner aparece após
// um pequeno grace de 4s (evita "piscar" em hiccups de rede) e some
// no reconnect. Botão "Recarregar agora" pra fix imediato.
//
// Multi-tenant nato.
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const isOffline = ref(false);
let graceTimer = null;
const GRACE_MS = 4000;

const onDisconnect = () => {
  // Só marca offline após X segundos sem reconnect — evita flash em
  // hiccups breves (1-2s) de rede instável.
  if (graceTimer) clearTimeout(graceTimer);
  graceTimer = setTimeout(() => {
    isOffline.value = true;
  }, GRACE_MS);
};

const onReconnect = () => {
  if (graceTimer) {
    clearTimeout(graceTimer);
    graceTimer = null;
  }
  isOffline.value = false;
};

const reload = () => window.location.reload();

onMounted(() => {
  emitter.on(BUS_EVENTS.WEBSOCKET_DISCONNECT, onDisconnect);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT, onReconnect);
  emitter.on(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED, onReconnect);
});

onBeforeUnmount(() => {
  emitter.off(BUS_EVENTS.WEBSOCKET_DISCONNECT, onDisconnect);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT, onReconnect);
  emitter.off(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED, onReconnect);
  if (graceTimer) clearTimeout(graceTimer);
});
</script>

<template>
  <teleport to="body">
    <div v-if="isOffline" class="klaos-offline-banner" role="alert">
      <span class="klaos-offline-banner__icon" aria-hidden="true">⚠️</span>
      <div class="klaos-offline-banner__body">
        <div class="klaos-offline-banner__title">
          Desconectado do servidor
        </div>
        <div class="klaos-offline-banner__desc">
          Você não receberá novas mensagens até reconectar.
          Tentando reconectar automaticamente…
        </div>
      </div>
      <button
        type="button"
        class="klaos-offline-banner__btn"
        @click="reload"
      >
        Recarregar agora
      </button>
    </div>
  </teleport>
</template>

<style scoped>
.klaos-offline-banner {
  position: fixed;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 99999;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  background: linear-gradient(90deg, #dc2626 0%, #b91c1c 100%);
  color: white;
  border-radius: 10px;
  box-shadow: 0 6px 20px rgba(220, 38, 38, 0.4);
  width: min(640px, calc(100vw - 24px));
  animation: klaos-offline-pulse 1.6s ease-in-out infinite;
}
@keyframes klaos-offline-pulse {
  0%, 100% { box-shadow: 0 6px 20px rgba(220, 38, 38, 0.4); }
  50% { box-shadow: 0 6px 28px rgba(220, 38, 38, 0.7); }
}
.klaos-offline-banner__icon {
  font-size: 22px;
  line-height: 1;
  flex-shrink: 0;
}
.klaos-offline-banner__body {
  flex: 1;
  min-width: 0;
}
.klaos-offline-banner__title {
  font-size: 13px;
  font-weight: 700;
  line-height: 1.2;
}
.klaos-offline-banner__desc {
  font-size: 12px;
  margin-top: 2px;
  opacity: 0.95;
  line-height: 1.3;
}
.klaos-offline-banner__btn {
  background: white;
  color: #b91c1c;
  border: none;
  padding: 7px 14px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 700;
  cursor: pointer;
  flex-shrink: 0;
  white-space: nowrap;
}
.klaos-offline-banner__btn:hover {
  background: #fef2f2;
}
@media (max-width: 600px) {
  .klaos-offline-banner {
    flex-wrap: wrap;
    gap: 8px;
  }
  .klaos-offline-banner__btn {
    width: 100%;
  }
}
</style>
