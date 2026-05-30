<script setup>
// KLaOS — Modal de motivos de pausa (O.19 Pausas Tipadas).
//
// Aparece quando agente clica no botão "Pausa" do StatusButtons (O.8).
// Lista motivos da conta (admin gerencia via Settings) + click em um
// motivo confirma a pausa. Cancel = não muda status.
//
// Backend:
//   GET /api/custom/v1/accounts/:id/pause_reasons → lista ativa
//
// Emit:
//   - confirm(reason)  — usuário escolheu motivo
//   - close            — fechou sem escolher
//
// Multi-tenant nato. Lazy-seed garante 5 motivos default se conta vazia.
import { ref, onMounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const emit = defineEmits(['confirm', 'close']);
const accountId = useMapGetter('getCurrentAccountId');
const reasons = ref([]);
const loading = ref(true);
const error = ref(null);

onMounted(async () => {
  try {
    const { data } = await window.axios.get(
      `/api/custom/v1/accounts/${accountId.value}/pause_reasons`
    );
    reasons.value = data.reasons || [];
  } catch (e) {
    error.value = 'Falha ao carregar motivos.';
  } finally {
    loading.value = false;
  }
});

const onPick = reason => emit('confirm', reason);
const onClose = () => emit('close');
</script>

<template>
  <teleport to="body">
    <div class="klaos-pause-modal-overlay" @click.self="onClose">
      <div class="klaos-pause-modal">
        <header class="klaos-pause-modal__header">
          <h3>Motivo da pausa</h3>
          <button
            type="button"
            class="klaos-pause-modal__close"
            @click="onClose"
            aria-label="Fechar"
          >
            ✕
          </button>
        </header>

        <div v-if="loading" class="klaos-pause-modal__state">Carregando…</div>
        <div v-else-if="error" class="klaos-pause-modal__state klaos-pause-modal__state--err">
          {{ error }}
        </div>
        <div v-else-if="!reasons.length" class="klaos-pause-modal__state">
          Nenhum motivo configurado. Peça pra admin criar em Configurações &gt; Motivos de Pausa.
        </div>

        <ul v-else class="klaos-pause-modal__list">
          <li v-for="r in reasons" :key="r.id">
            <button
              type="button"
              class="klaos-pause-modal__btn"
              @click="onPick(r)"
            >
              <span class="klaos-pause-modal__icon">{{ r.icon }}</span>
              <span class="klaos-pause-modal__name">{{ r.name }}</span>
            </button>
          </li>
        </ul>

        <footer class="klaos-pause-modal__footer">
          <button
            type="button"
            class="klaos-pause-modal__cancel"
            @click="onClose"
          >
            Cancelar
          </button>
        </footer>
      </div>
    </div>
  </teleport>
</template>

<style scoped>
.klaos-pause-modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 16px;
}
.klaos-pause-modal {
  background: white;
  border-radius: 12px;
  width: 100%;
  max-width: 420px;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 20px 50px rgba(0, 0, 0, 0.3);
}
.klaos-pause-modal__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid #e5e7eb;
}
.klaos-pause-modal__header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #111827;
}
.klaos-pause-modal__close {
  background: none;
  border: none;
  font-size: 16px;
  color: #6b7280;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
}
.klaos-pause-modal__close:hover {
  background: #f3f4f6;
  color: #111827;
}
.klaos-pause-modal__state {
  padding: 32px;
  text-align: center;
  color: #6b7280;
  font-size: 14px;
}
.klaos-pause-modal__state--err {
  color: #b91c1c;
}
.klaos-pause-modal__list {
  list-style: none;
  margin: 0;
  padding: 8px;
  overflow-y: auto;
  flex: 1;
}
.klaos-pause-modal__btn {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  border-radius: 8px;
  background: white;
  border: 1px solid #e5e7eb;
  cursor: pointer;
  text-align: left;
  margin-bottom: 6px;
  transition: all 0.15s ease;
}
.klaos-pause-modal__btn:hover {
  background: #fffbeb;
  border-color: #fcd34d;
  transform: translateX(2px);
}
.klaos-pause-modal__icon {
  font-size: 22px;
}
.klaos-pause-modal__name {
  font-size: 14px;
  font-weight: 500;
  color: #111827;
}
.klaos-pause-modal__footer {
  padding: 12px 16px;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
}
.klaos-pause-modal__cancel {
  background: #f3f4f6;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  padding: 8px 16px;
  font-size: 13px;
  color: #374151;
  cursor: pointer;
}
.klaos-pause-modal__cancel:hover {
  background: #e5e7eb;
}
</style>
