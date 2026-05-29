<script setup>
// KLaOS — Painel de Agentes (O.1 Onda 2).
//
// Tela de SUPERVISÃO em tempo real: admin vê grid com todos os agentes,
// estado atual, chats em atendimento agora, atendidos hoje, tempo logado
// e em pausa, e pode forçar status (logout, pausa).
//
// Backend: /api/custom/v1/accounts/:id/supervisor/agents
// Tempo logado/pausa: tabela klaos_agent_availability_events
//   (alimentada por klaos_agent_availability_tracking initializer)
//
// Refresh:
//   - Polling 10s no payload (chats, atendidos hoje)
//   - Ticker LOCAL 1s pros tempos logado/pausa (adiciona delta desde
//     o último refresh ao online_today_s + busy_today_s do user "live")
//
// Multi-tenant nato.
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import axios from 'axios';

const accountId = useMapGetter('getCurrentAccountId');

const payload = ref(null);
const loading = ref(true);
const error = ref(null);
const tickNow = ref(Date.now());
let refreshInterval = null;
let tickerInterval = null;

const fetchData = async () => {
  try {
    const { data } = await axios.get(
      `/api/custom/v1/accounts/${accountId.value}/supervisor/agents`
    );
    payload.value = data;
    error.value = null;
  } catch (e) {
    error.value =
      e.response?.data?.error || 'Erro ao carregar painel de agentes.';
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchData();
  refreshInterval = setInterval(fetchData, 10000);
  tickerInterval = setInterval(() => {
    tickNow.value = Date.now();
  }, 1000);
});

onUnmounted(() => {
  if (refreshInterval) clearInterval(refreshInterval);
  if (tickerInterval) clearInterval(tickerInterval);
});

const generatedAtMs = computed(() =>
  payload.value ? payload.value.generated_at * 1000 : Date.now()
);

const deltaSec = computed(() =>
  Math.max(0, Math.floor((tickNow.value - generatedAtMs.value) / 1000))
);

const rows = computed(() => {
  if (!payload.value) return [];
  return payload.value.agents.map(a => {
    // Tempo "live": soma o delta desde o último refresh ao bucket do
    // status atual. Ex: agente está online → online_today_s += delta.
    let online = a.online_today_s;
    let busy = a.busy_today_s;
    if (a.availability === 'online') online += deltaSec.value;
    if (a.availability === 'busy') busy += deltaSec.value;
    return {
      ...a,
      online_today_s_live: online,
      busy_today_s_live: busy,
    };
  });
});

const summary = computed(() => payload.value?.summary || {});

const fmtDuration = sec => {
  if (sec === null || sec === undefined) return '--:--:--';
  const s = Math.max(0, Math.floor(sec));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
};

const availabilityIcon = a => {
  if (a === 'online') return '🟢';
  if (a === 'busy') return '🟡';
  return '⚪';
};

const availabilityLabel = a => {
  if (a === 'online') return 'Online';
  if (a === 'busy') return 'Pausa';
  return 'Offline';
};

const availabilityClass = a => {
  if (a === 'online') return 'klaos-supv-state--online';
  if (a === 'busy') return 'klaos-supv-state--busy';
  return 'klaos-supv-state--offline';
};

const forceStatus = async (row, newStatus) => {
  if (row.availability === newStatus) return;
  const action =
    newStatus === 'offline'
      ? 'forçar offline'
      : newStatus === 'busy'
      ? 'forçar pausa'
      : 'colocar online';
  if (!window.confirm(`Tem certeza que quer ${action} ${row.name}?`)) return;
  try {
    await axios.post(
      `/api/custom/v1/accounts/${accountId.value}/supervisor/agents/${row.id}/force_status`,
      { status: newStatus }
    );
    useAlert(`${row.name} agora está ${availabilityLabel(newStatus)}.`);
    fetchData();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao mudar status.');
  }
};
</script>

<template>
  <div class="klaos-supv">
    <header class="klaos-supv__header">
      <div>
        <h1 class="klaos-supv__title">Painel de Agentes</h1>
        <p class="klaos-supv__subtitle">
          Visão em tempo real da operação. Atualiza a cada 10s.
        </p>
      </div>
      <div class="klaos-supv__summary">
        <span class="klaos-supv__badge klaos-supv__badge--online">
          🟢 {{ summary.online || 0 }} online
        </span>
        <span class="klaos-supv__badge klaos-supv__badge--busy">
          🟡 {{ summary.busy || 0 }} pausa
        </span>
        <span class="klaos-supv__badge klaos-supv__badge--offline">
          ⚪ {{ summary.offline || 0 }} offline
        </span>
        <span class="klaos-supv__badge klaos-supv__badge--with-chats">
          💬 {{ summary.with_chats || 0 }} com chats
        </span>
      </div>
    </header>

    <div v-if="loading" class="klaos-supv__loading">Carregando…</div>
    <div v-else-if="error" class="klaos-supv__error">{{ error }}</div>

    <table v-else class="klaos-supv__table">
      <thead>
        <tr>
          <th>Agente</th>
          <th>Estado</th>
          <th>Chats agora</th>
          <th>Atendidos hoje</th>
          <th>Logado hoje</th>
          <th>Pausa hoje</th>
          <th>Ações</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.id">
          <td class="klaos-supv__agent-cell">
            <img
              v-if="row.thumbnail"
              :src="row.thumbnail"
              :alt="row.name"
              class="klaos-supv__avatar"
            />
            <div v-else class="klaos-supv__avatar klaos-supv__avatar--placeholder">
              {{ row.name?.charAt(0) }}
            </div>
            <div>
              <div class="klaos-supv__name">{{ row.name }}</div>
              <div class="klaos-supv__email">{{ row.email }}</div>
            </div>
          </td>
          <td>
            <span
              class="klaos-supv__state"
              :class="availabilityClass(row.availability)"
            >
              {{ availabilityIcon(row.availability) }}
              {{ availabilityLabel(row.availability) }}
            </span>
          </td>
          <td class="klaos-supv__num">
            <strong>{{ row.chats_now }}</strong>
          </td>
          <td class="klaos-supv__num">{{ row.attended_today }}</td>
          <td class="klaos-supv__num klaos-supv__time">
            {{ fmtDuration(row.online_today_s_live) }}
          </td>
          <td class="klaos-supv__num klaos-supv__time">
            {{ fmtDuration(row.busy_today_s_live) }}
          </td>
          <td class="klaos-supv__actions">
            <button
              v-if="row.availability !== 'offline'"
              type="button"
              class="klaos-supv__btn klaos-supv__btn--offline"
              title="Forçar offline"
              @click="forceStatus(row, 'offline')"
            >
              ⏻
            </button>
            <button
              v-if="row.availability !== 'busy'"
              type="button"
              class="klaos-supv__btn klaos-supv__btn--busy"
              title="Forçar pausa"
              @click="forceStatus(row, 'busy')"
            >
              ⏸
            </button>
            <button
              v-if="row.availability !== 'online'"
              type="button"
              class="klaos-supv__btn klaos-supv__btn--online"
              title="Colocar online"
              @click="forceStatus(row, 'online')"
            >
              ▶
            </button>
          </td>
        </tr>
        <tr v-if="!rows.length">
          <td colspan="7" class="klaos-supv__empty">
            Nenhum agente nessa conta.
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.klaos-supv {
  padding: 24px;
  height: 100%;
  overflow: auto;
}
.klaos-supv__header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 16px;
  margin-bottom: 24px;
}
.klaos-supv__title {
  font-size: 24px;
  font-weight: 700;
  margin: 0;
}
.klaos-supv__subtitle {
  font-size: 13px;
  color: #6b7280;
  margin: 4px 0 0;
}
.klaos-supv__summary {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}
.klaos-supv__badge {
  padding: 6px 12px;
  border-radius: 16px;
  font-size: 13px;
  font-weight: 600;
  background: #f3f4f6;
  color: #374151;
  white-space: nowrap;
}
.klaos-supv__badge--online {
  background: #d1fae5;
  color: #065f46;
}
.klaos-supv__badge--busy {
  background: #fef3c7;
  color: #78350f;
}
.klaos-supv__badge--offline {
  background: #e5e7eb;
  color: #374151;
}
.klaos-supv__badge--with-chats {
  background: #dbeafe;
  color: #1e40af;
}
.klaos-supv__table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}
.klaos-supv__table th {
  text-align: left;
  padding: 12px 16px;
  background: #f9fafb;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 600;
  color: #6b7280;
  border-bottom: 1px solid #e5e7eb;
}
.klaos-supv__table td {
  padding: 12px 16px;
  border-bottom: 1px solid #f3f4f6;
  font-size: 14px;
  color: #111827;
  vertical-align: middle;
}
.klaos-supv__table tr:last-child td {
  border-bottom: none;
}
.klaos-supv__agent-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.klaos-supv__avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  background: #e5e7eb;
  flex-shrink: 0;
}
.klaos-supv__avatar--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  color: #6b7280;
  background: #f3f4f6;
}
.klaos-supv__name {
  font-weight: 600;
}
.klaos-supv__email {
  font-size: 12px;
  color: #6b7280;
}
.klaos-supv__state {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
}
.klaos-supv__state--online {
  background: #d1fae5;
  color: #065f46;
}
.klaos-supv__state--busy {
  background: #fef3c7;
  color: #78350f;
}
.klaos-supv__state--offline {
  background: #e5e7eb;
  color: #374151;
}
.klaos-supv__num {
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.klaos-supv__time {
  font-family: 'SF Mono', Monaco, monospace;
  font-size: 13px;
}
.klaos-supv__actions {
  display: flex;
  gap: 4px;
  justify-content: flex-end;
}
.klaos-supv__btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
  border: 1px solid transparent;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.15s ease;
}
.klaos-supv__btn--online {
  background: #d1fae5;
  color: #065f46;
  border-color: #6ee7b7;
}
.klaos-supv__btn--busy {
  background: #fef3c7;
  color: #78350f;
  border-color: #fcd34d;
}
.klaos-supv__btn--offline {
  background: #fee2e2;
  color: #991b1b;
  border-color: #fca5a5;
}
.klaos-supv__btn:hover {
  transform: scale(1.1);
}
.klaos-supv__loading,
.klaos-supv__error,
.klaos-supv__empty {
  padding: 48px;
  text-align: center;
  color: #6b7280;
  font-size: 14px;
}
.klaos-supv__error {
  color: #b91c1c;
}
</style>
