<script setup>
// KLaOS — Ações inline na linha da conversa (O.11 Onda 2).
//
// Paridade Kualiz Painel de Atendimentos: cada conversa na lista tem
// botões de ação rápida em hover, sem precisar abrir a conv. Reusa as
// actions Vuex nativas — zero novo backend.
//
// Ação:
//   - ✓ Resolver (toggle status pra resolved) — única ação que pode rodar
//     SEM precisar abrir a conv no painel direito. "Transferir" foi
//     removido porque exige UI complexa (assignee picker) que só faz
//     sentido no header da conv aberta — sem isso era só "trocar de
//     conv selecionada", redundante com o click normal no card.
//
// Multi-tenant nato. Só mostra quando hover na card.
import { computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  chat: { type: Object, required: true },
});

const store = useStore();

const isResolved = computed(
  () => props.chat?.status === wootConstants.STATUS_TYPE.RESOLVED
);

const onResolve = e => {
  e.stopPropagation();
  e.preventDefault();
  if (isResolved.value) return;
  store
    .dispatch('toggleStatus', {
      conversationId: props.chat.id,
      status: wootConstants.STATUS_TYPE.RESOLVED,
    })
    .then(() => {
      useAlert('Conversa resolvida.');
    })
    .catch(() => {
      useAlert('Erro ao resolver. Tente novamente.');
    });
};

</script>

<template>
  <div
    class="klaos-inline-actions hidden group-hover:flex absolute bottom-1 right-1 gap-1 z-10"
  >
    <button
      v-if="!isResolved"
      type="button"
      class="klaos-inline-actions__btn"
      title="Resolver conversa"
      @click="onResolve"
    >
      ✓
    </button>
  </div>
</template>

<style scoped>
.klaos-inline-actions__btn {
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.95);
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 4px;
  font-size: 13px;
  font-weight: 600;
  color: #4b5563;
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
  transition: all 0.15s ease;
}
.klaos-inline-actions__btn:hover {
  background: #f3f4f6;
  color: #111827;
  transform: scale(1.1);
}
:global(.dark) .klaos-inline-actions__btn {
  background: rgba(40, 40, 40, 0.95);
  border-color: rgba(255, 255, 255, 0.15);
  color: #d1d5db;
}
:global(.dark) .klaos-inline-actions__btn:hover {
  background: #1f2937;
  color: white;
}
</style>
