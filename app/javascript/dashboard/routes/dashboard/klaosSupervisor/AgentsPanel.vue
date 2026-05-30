<script setup>
// KLaOS — Painel de Agentes v3 (O.1 + O.19 — Onda 2).
//
// Layout: LISTA full-width vertical. Cada agente = uma linha larga com
// status colorido à esquerda, avatar + nome, motivo da pausa em badge,
// métricas inline e ações no fim. Topo tem busca por nome/email +
// pílulas resumo. Paginação client-side (20 por página).
//
// Backend: GET /api/custom/v1/accounts/:id/supervisor/agents
//   Retorna agents[] com availability + pause_reason {name, icon,
//   elapsed_s, max_minutes, overtime} + tempos do dia.
//
// Refresh:
//   - Polling 10s do payload
//   - Ticker LOCAL 1s pros tempos
//
// Multi-tenant nato.
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

const accountId = useMapGetter('getCurrentAccountId');

const payload = ref(null);
const loading = ref(true);
const error = ref(null);
const tickNow = ref(Date.now());
const query = ref('');
const page = ref(1);
const PER_PAGE = 20;
let refreshInterval = null;
let tickerInterval = null;

const fetchData = async () => {
  try {
    const { data } = await window.axios.get(
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

// All rows com tempos live computados
const allRows = computed(() => {
  if (!payload.value) return [];
  return payload.value.agents.map(a => {
    let online = a.online_today_s;
    let busy = a.busy_today_s;
    if (a.availability === 'online') online += deltaSec.value;
    if (a.availability === 'busy') busy += deltaSec.value;
    let pause = null;
    if (a.pause_reason) {
      const elapsedLive = a.pause_reason.elapsed_s + deltaSec.value;
      const maxS = a.pause_reason.max_minutes
        ? a.pause_reason.max_minutes * 60
        : null;
      pause = {
        ...a.pause_reason,
        elapsed_s_live: elapsedLive,
        overtime_live: maxS ? elapsedLive > maxS : false,
        remaining_s: maxS ? maxS - elapsedLive : null,
      };
    }
    return {
      ...a,
      online_today_s_live: online,
      busy_today_s_live: busy,
      pause_live: pause,
    };
  });
});

// Busca por nome ou email
const filteredRows = computed(() => {
  const q = query.value.trim().toLowerCase();
  if (!q) return allRows.value;
  return allRows.value.filter(
    a =>
      a.name?.toLowerCase().includes(q) ||
      a.email?.toLowerCase().includes(q)
  );
});

const totalPages = computed(() =>
  Math.max(1, Math.ceil(filteredRows.value.length / PER_PAGE))
);

const pagedRows = computed(() => {
  const start = (page.value - 1) * PER_PAGE;
  return filteredRows.value.slice(start, start + PER_PAGE);
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

const fmtShort = sec => {
  if (sec === null || sec === undefined) return '0min';
  const s = Math.max(0, Math.abs(Math.floor(sec)));
  const m = Math.floor(s / 60);
  const ss = s % 60;
  if (m < 60) return `${m}min ${ss}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}min`;
};

const availabilityLabel = a =>
  a === 'online' ? 'Online' : a === 'busy' ? 'Pausa' : 'Offline';

const rowStateClass = a =>
  a === 'online'
    ? 'klaos-supv-row--online'
    : a === 'busy'
    ? 'klaos-supv-row--busy'
    : 'klaos-supv-row--offline';

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
    await window.axios.post(
      `/api/custom/v1/accounts/${accountId.value}/supervisor/agents/${row.id}/force_status`,
      { status: newStatus }
    );
    useAlert(`${row.name} agora está ${availabilityLabel(newStatus)}.`);
    fetchData();
  } catch (e) {
    useAlert(e.response?.data?.error || 'Erro ao mudar status.');
  }
};

const onSearchInput = () => {
  page.value = 1; // reset paginação ao buscar
};

const goPage = n => {
  if (n < 1 || n > totalPages.value) return;
  page.value = n;
};
</script>

<template>
  <div class="klaos-supv">
    <header class="klaos-supv__header">
      <div>
        <h1 class="klaos-supv__title">Painel de Atendentes</h1>
        <p class="klaos-supv__subtitle">
          Visão em tempo real da operação. Atualiza a cada 10s.
        </p>
      </div>
      <div class="klaos-supv__summary">
        <span class="klaos-supv__pill klaos-supv__pill--online">
          🟢 {{ summary.online || 0 }} online
        </span>
        <span class="klaos-supv__pill klaos-supv__pill--busy">
          🟡 {{ summary.busy || 0 }} pausa
        </span>
        <span class="klaos-supv__pill klaos-supv__pill--offline">
          ⚪ {{ summary.offline || 0 }} offline
        </span>
        <span class="klaos-supv__pill klaos-supv__pill--chats">
          💬 {{ summary.with_chats || 0 }} com chats
        </span>
      </div>
    </header>

    <div class="klaos-supv__toolbar">
      <div class="klaos-supv__search-wrap">
        <span class="klaos-supv__search-icon i-lucide-search" aria-hidden="true"></span>
        <input
          v-model="query"
          type="text"
          placeholder="Buscar por nome ou email…"
          class="klaos-supv__search"
          @input="onSearchInput"
        />
        <button
          v-if="query"
          type="button"
          class="klaos-supv__search-clear"
          @click="query = ''; page = 1"
          title="Limpar busca"
        >
          ✕
        </button>
      </div>
      <div class="klaos-supv__count">
        {{ filteredRows.length }} atendente{{ filteredRows.length === 1 ? '' : 's' }}
        <template v-if="query">filtrado{{ filteredRows.length === 1 ? '' : 's' }}</template>
      </div>
    </div>

    <div v-if="loading" class="klaos-supv__state">Carregando…</div>
    <div v-else-if="error" class="klaos-supv__state klaos-supv__state--err">{{ error }}</div>
    <div v-else-if="!pagedRows.length" class="klaos-supv__state">
      {{ query ? 'Nenhum atendente bate com a busca.' : 'Nenhum atendente nessa conta.' }}
    </div>

    <ul v-else class="klaos-supv__list">
      <li
        v-for="row in pagedRows"
        :key="row.id"
        class="klaos-supv-row"
        :class="[rowStateClass(row.availability), row.pause_live?.overtime_live && 'klaos-supv-row--overtime']"
      >
        <div class="klaos-supv-row__status">
          <span class="klaos-supv-row__status-dot"></span>
          <span class="klaos-supv-row__status-lbl">{{ availabilityLabel(row.availability) }}</span>
        </div>

        <div class="klaos-supv-row__agent">
          <img
            v-if="row.thumbnail"
            :src="row.thumbnail"
            :alt="row.name"
            class="klaos-supv-row__avatar"
          />
          <div v-else class="klaos-supv-row__avatar klaos-supv-row__avatar--placeholder">
            {{ row.name?.charAt(0) }}
          </div>
          <div class="klaos-supv-row__name-block">
            <div class="klaos-supv-row__name">{{ row.name }}</div>
            <div class="klaos-supv-row__email">{{ row.email }}</div>
          </div>
        </div>

        <div
          v-if="row.pause_live"
          class="klaos-supv-row__reason"
          :class="row.pause_live.overtime_live && 'klaos-supv-row__reason--overtime'"
          :title="row.pause_live.max_minutes
            ? `Limite: ${row.pause_live.max_minutes} min`
            : 'Sem limite'"
        >
          {{ row.pause_live.icon }} {{ row.pause_live.name }}
          <span class="klaos-supv-row__reason-time">
            · {{ fmtShort(row.pause_live.elapsed_s_live) }}
            <template v-if="row.pause_live.overtime_live">
              · +{{ fmtShort(-row.pause_live.remaining_s) }}
            </template>
          </span>
        </div>
        <div v-else class="klaos-supv-row__reason-empty"></div>

        <div class="klaos-supv-row__metrics">
          <div class="klaos-supv-row__metric">
            <div class="klaos-supv-row__metric-val">{{ row.chats_now }}</div>
            <div class="klaos-supv-row__metric-lbl">chats</div>
          </div>
          <div class="klaos-supv-row__metric">
            <div class="klaos-supv-row__metric-val">{{ row.attended_today }}</div>
            <div class="klaos-supv-row__metric-lbl">atend.</div>
          </div>
          <div class="klaos-supv-row__metric">
            <div class="klaos-supv-row__metric-val klaos-supv-row__metric-val--time">
              {{ fmtDuration(row.online_today_s_live) }}
            </div>
            <div class="klaos-supv-row__metric-lbl">logado</div>
          </div>
          <div class="klaos-supv-row__metric">
            <div class="klaos-supv-row__metric-val klaos-supv-row__metric-val--time">
              {{ fmtDuration(row.busy_today_s_live) }}
            </div>
            <div class="klaos-supv-row__metric-lbl">pausa</div>
          </div>
        </div>

        <div class="klaos-supv-row__actions">
          <button
            v-if="row.availability !== 'online'"
            type="button"
            class="klaos-supv-row__btn klaos-supv-row__btn--online"
            title="Colocar online"
            @click="forceStatus(row, 'online')"
          >
            ▶
          </button>
          <button
            v-if="row.availability !== 'busy'"
            type="button"
            class="klaos-supv-row__btn klaos-supv-row__btn--busy"
            title="Forçar pausa"
            @click="forceStatus(row, 'busy')"
          >
            ⏸
          </button>
          <button
            v-if="row.availability !== 'offline'"
            type="button"
            class="klaos-supv-row__btn klaos-supv-row__btn--offline"
            title="Forçar offline"
            @click="forceStatus(row, 'offline')"
          >
            ⏻
          </button>
        </div>
      </li>
    </ul>

    <nav v-if="totalPages > 1" class="klaos-supv__pager">
      <button
        type="button"
        class="klaos-supv__pager-btn"
        :disabled="page === 1"
        @click="goPage(page - 1)"
      >
        ‹ Anterior
      </button>
      <span class="klaos-supv__pager-info">Página {{ page }} de {{ totalPages }}</span>
      <button
        type="button"
        class="klaos-supv__pager-btn"
        :disabled="page === totalPages"
        @click="goPage(page + 1)"
      >
        Próxima ›
      </button>
    </nav>
  </div>
</template>

<style scoped>
.klaos-supv {
  padding: 24px;
  height: 100%;
  overflow: auto;
  background: #f9fafb;
}
.klaos-supv__header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 16px;
  margin-bottom: 16px;
}
.klaos-supv__title {
  font-size: 22px;
  font-weight: 700;
  margin: 0;
  color: #111827;
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
.klaos-supv__pill {
  padding: 6px 14px;
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
}
.klaos-supv__pill--online { background: #d1fae5; color: #065f46; }
.klaos-supv__pill--busy { background: #fef3c7; color: #78350f; }
.klaos-supv__pill--offline { background: #e5e7eb; color: #374151; }
.klaos-supv__pill--chats { background: #dbeafe; color: #1e40af; }

.klaos-supv__toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.klaos-supv__search-wrap {
  position: relative;
  flex: 1;
  max-width: 400px;
  display: flex;
  align-items: center;
}
.klaos-supv__search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: #6b7280;
  pointer-events: none;
  width: 18px;
  height: 18px;
  font-size: 18px;
}
.klaos-supv__search {
  width: 100%;
  padding: 10px 36px 10px 36px;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  background: white;
  font-size: 14px;
  color: #111827;
}
.klaos-supv__search:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
}
.klaos-supv__search-clear {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  font-size: 14px;
  color: #6b7280;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
}
.klaos-supv__search-clear:hover { background: #f3f4f6; }
.klaos-supv__count {
  font-size: 13px;
  color: #6b7280;
}

.klaos-supv__list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.klaos-supv-row {
  display: grid;
  grid-template-columns: 120px minmax(220px, 1.5fr) minmax(160px, 1.2fr) auto auto;
  gap: 16px;
  align-items: center;
  background: white;
  border-radius: 10px;
  border-left: 4px solid #e5e7eb;
  padding: 12px 16px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04);
  transition: all 0.15s ease;
}
.klaos-supv-row:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}
.klaos-supv-row--online { border-left-color: #10b981; }
.klaos-supv-row--busy { border-left-color: #f59e0b; }
.klaos-supv-row--offline { border-left-color: #9ca3af; }
.klaos-supv-row--overtime {
  border-left-color: #dc2626 !important;
  background: linear-gradient(90deg, #fef2f2 0%, white 30%);
  animation: klaos-supv-pulse 1.5s ease-in-out infinite;
}
@keyframes klaos-supv-pulse {
  0%, 100% { box-shadow: 0 0 0 1px #fecaca; }
  50% { box-shadow: 0 0 0 3px #fca5a5; }
}

.klaos-supv-row__status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.klaos-supv-row--online .klaos-supv-row__status { color: #065f46; }
.klaos-supv-row--busy .klaos-supv-row__status { color: #78350f; }
.klaos-supv-row--offline .klaos-supv-row__status { color: #374151; }
.klaos-supv-row--overtime .klaos-supv-row__status { color: #991b1b; }
.klaos-supv-row__status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: currentColor;
}

.klaos-supv-row__agent {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.klaos-supv-row__avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  object-fit: cover;
  background: #e5e7eb;
  flex-shrink: 0;
}
.klaos-supv-row__avatar--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  color: #6b7280;
  background: #f3f4f6;
  font-size: 14px;
}
.klaos-supv-row__name-block {
  min-width: 0;
}
.klaos-supv-row__name {
  font-weight: 600;
  color: #111827;
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.klaos-supv-row__email {
  font-size: 11px;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.klaos-supv-row__reason {
  font-size: 12px;
  padding: 4px 10px;
  border-radius: 999px;
  background: #fef3c7;
  color: #78350f;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  justify-self: start;
}
.klaos-supv-row__reason--overtime {
  background: #fee2e2;
  color: #991b1b;
  font-weight: 700;
}
.klaos-supv-row__reason-time {
  opacity: 0.85;
  font-variant-numeric: tabular-nums;
}
.klaos-supv-row__reason-empty {}

.klaos-supv-row__metrics {
  display: grid;
  grid-template-columns: repeat(4, 70px);
  gap: 6px;
}
.klaos-supv-row__metric {
  text-align: center;
}
.klaos-supv-row__metric-val {
  font-size: 16px;
  font-weight: 700;
  color: #111827;
  line-height: 1.2;
}
.klaos-supv-row__metric-val--time {
  font-size: 12px;
  font-family: 'SF Mono', Monaco, monospace;
  letter-spacing: -0.5px;
}
.klaos-supv-row__metric-lbl {
  font-size: 10px;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  margin-top: 1px;
}

.klaos-supv-row__actions {
  display: flex;
  gap: 4px;
}
.klaos-supv-row__btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: 1px solid transparent;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}
.klaos-supv-row__btn--online {
  background: #d1fae5; color: #065f46; border-color: #6ee7b7;
}
.klaos-supv-row__btn--busy {
  background: #fef3c7; color: #78350f; border-color: #fcd34d;
}
.klaos-supv-row__btn--offline {
  background: #fee2e2; color: #991b1b; border-color: #fca5a5;
}
.klaos-supv-row__btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.klaos-supv__pager {
  margin-top: 16px;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 16px;
}
.klaos-supv__pager-btn {
  padding: 8px 16px;
  border-radius: 6px;
  border: 1px solid #d1d5db;
  background: white;
  font-size: 13px;
  font-weight: 600;
  color: #374151;
  cursor: pointer;
}
.klaos-supv__pager-btn:hover:not(:disabled) {
  background: #f3f4f6;
}
.klaos-supv__pager-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.klaos-supv__pager-info {
  font-size: 13px;
  color: #6b7280;
}

.klaos-supv__state {
  padding: 48px;
  text-align: center;
  color: #6b7280;
  font-size: 14px;
  background: white;
  border-radius: 10px;
}
.klaos-supv__state--err { color: #b91c1c; }

@media (max-width: 1100px) {
  .klaos-supv-row {
    grid-template-columns: 1fr;
    gap: 10px;
  }
  .klaos-supv-row__metrics {
    grid-template-columns: repeat(4, 1fr);
  }
  .klaos-supv-row__actions {
    justify-content: flex-end;
  }
}
</style>
