<script setup>
// KLaOS — Botões grandes de status do agente (O.8 Onda 2).
//
// Paridade Kualiz: 3 botões claros e visíveis pro agente mudar de
// status sem precisar abrir o dropdown do avatar. Verde (Online),
// amarelo (Pausa) e cinza/vermelho (Offline). Estado ativo
// destacado por borda + opacity dos outros.
//
// Usa as actions/getters nativos do Chatwoot:
//   - getCurrentUserAvailability — status atual
//   - updateAvailability — dispatch pra mudar
//
// Multi-tenant nato. Renderizado na sidebar (acima do avatar).
import { computed } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import wootConstants from 'dashboard/constants/globals';
import { useImpersonation } from 'dashboard/composables/useImpersonation';

const store = useStore();
const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
const currentAccountId = useMapGetter('getCurrentAccountId');
const { isImpersonating } = useImpersonation();

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const buttons = computed(() => [
  {
    key: AVAILABILITY_STATUS_KEYS[0], // online
    label: 'Online',
    icon: '🟢',
    activeBg: 'bg-n-teal-9',
    activeText: 'text-white',
  },
  {
    key: AVAILABILITY_STATUS_KEYS[1], // busy
    label: 'Pausa',
    icon: '🟡',
    activeBg: 'bg-n-amber-9',
    activeText: 'text-white',
  },
  {
    key: AVAILABILITY_STATUS_KEYS[2], // offline
    label: 'Offline',
    icon: '⚪',
    activeBg: 'bg-n-slate-9',
    activeText: 'text-white',
  },
]);

const isActive = key => currentUserAvailability.value === key;

const setStatus = key => {
  if (isImpersonating.value) {
    useAlert(
      'Você está em modo impersonate — não pode mudar o status do agente.'
    );
    return;
  }
  if (isActive(key)) return;
  store.dispatch('updateAvailability', {
    availability: key,
    account_id: currentAccountId.value,
  });
};
</script>

<template>
  <div class="klaos-agent-status-buttons grid grid-cols-3 gap-1 p-1">
    <button
      v-for="btn in buttons"
      :key="btn.key"
      type="button"
      class="flex flex-col items-center justify-center gap-0.5 py-2 rounded-md text-xs font-medium transition-all"
      :class="[
        isActive(btn.key)
          ? [btn.activeBg, btn.activeText, 'shadow-sm']
          : 'bg-n-alpha-1 text-n-slate-12 hover:bg-n-alpha-2 opacity-70',
      ]"
      :title="`Definir status: ${btn.label}`"
      @click="setStatus(btn.key)"
    >
      <span class="text-base leading-none">{{ btn.icon }}</span>
      <span class="leading-none">{{ btn.label }}</span>
    </button>
  </div>
</template>
