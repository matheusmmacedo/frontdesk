<script setup>
// KLaOS — Painel de Agentes v2 (O.1 + O.19 — Onda 2).
//
// GRID de cards (substituiu a tabela). Cada agente vira card com:
//   - Header colorido por status (verde/amarelo/cinza)
//   - Avatar grande
//   - Motivo da pausa em badge âmbar (vermelho piscante se overtime)
//   - 4 métricas em grid: chats / atendidos / logado / pausa
//   - Ações de forçar status no rodapé
//
// Backend: GET /api/custom/v1/accounts/:id/supervisor/agents
//   Retorna agents[] com availability + pause_reason {name, icon,
//   elapsed_s, max_minutes, overtime} + tempos do dia.
//
// Refresh:
//   - Polling 10s do payload (chats, atendidos, motivo)
//   - Ticker LOCAL 1s pros tempos (soma delta ao bucket do status atual)
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

const rows = computed(() => {
  if (!payload.value) return [];
  return payload.value.agents.map(a => {
    // Tempos "live": soma delta ao bucket do status atual
    let online = a.online_today_s;
    let busy = a.busy_today_s;
    if (a.availability === 'online') online += deltaSec.value;
    if (a.availability === 'busy') busy += deltaSec.value;
    // Motivo: também tickando elapsed pra detectar overtime ao vivo
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

const statusClass = a =>
  a === 'online'
    ? 'klaos-supv-card--online'
    : a === 'busy'
    ? 'klaos-supv-card--busy'
    : 'klaos-supv-card--offline';

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

    <div v-if="loading" class="klaos-supv__loading">Carregando…</div>
    <div v-else-if="error" class="klaos-supv__error">{{ error }}</div>

    <div v-else class="klaos-supv__grid">
      <article
        v-for="row in rows"
        :key="row.id"
        class="klaos-supv-card"
        :class="[statusClass(row.availability), row.pause_live?.overtime_live && 'klaos-supv-card--overtime']"
      >
        <header class="klaos-supv-card__head">
          <div class="klaos-supv-card__head-status">
            <span class="klaos-supv-card__dot"></span>
            {{ availabilityLabel(row.availability) }}
          </div>
          <div
            v-if="row.pause_live"
            class="klaos-supv-card__reason"
            :class="row.pause_live.overtime_live && 'klaos-supv-card__reason--overtime'"
            :title="row.pause_live.max_minutes
              ? `Limite: ${row.pause_live.max_minutes} min`
              : 'Sem limite'"
          >
            {{ row.pause_live.icon }} {{ row.pause_live.name }}
            <span class="klaos-supv-card__reason-time">
              {{ fmtShort(row.pause_live.elapsed_s_live) }}
              <template v-if="row.pause_live.overtime_live">
                · +{{ fmtShort(-row.pause_live.remaining_s) }}
              </template>
            </span>
          </div>
        </header>

        <div class="klaos-supv-card__body">
          <div class="klaos-supv-card__avatar-wrap">
            <img
              v-if="row.thumbnail"
              :src="row.thumbnail"
              :alt="row.name"
              class="klaos-supv-card__avatar"
            />
            <div v-else class="klaos-supv-card__avatar klaos-supv-card__avatar--placeholder">
              {{ row.name?.charAt(0) }}
            </div>
            <div class="klaos-supv-card__name-block">
              <div class="klaos-supv-card__name">{{ row.name }}</div>
              <div class="klaos-supv-card__email">{{ row.email }}</div>
            </div>
          </div>

          <div class="klaos-supv-card__metrics">
            <div class="klaos-supv-card__metric">
              <div class="klaos-supv-card__metric-val">{{ row.chats_now }}</div>
              <div class="klaos-supv-card__metric-lbl">chats agora</div>
            </div>
            <div class="klaos-supv-card__metric">
              <div class="klaos-supv-card__metric-val">{{ row.attended_today }}</div>
              <div class="klaos-supv-card__metric-lbl">atendidos hoje</div>
            </div>
            <div class="klaos-supv-card__metric">
              <div class="klaos-supv-card__metric-val klaos-supv-card__metric-val--time">
                {{ fmtDuration(row.online_today_s_live) }}
              </div>
              <div class="klaos-supv-card__metric-lbl">logado hoje</div>
            </div>
            <div class="klaos-supv-card__metric">
              <div class="klaos-supv-card__metric-val klaos-supv-card__metric-val--time">
                {{ fmtDuration(row.busy_today_s_live) }}
              </div>
              <div class="klaos-supv-card__metric-lbl">pausa hoje</div>
            </div>
          </div>
        </div>

        <footer class="klaos-supv-card__actions">
          <button
            v-if="row.availability !== 'online'"
            type="button"
            class="klaos-supv-card__btn klaos-supv-card__btn--online"
            @click="forceStatus(row, 'online')"
          >
            ▶ Online
          </button>
          <button
            v-if="row.availability !== 'busy'"
            type="button"
            class="klaos-supv-card__btn klaos-supv-card__btn--busy"
            @click="forceStatus(row, 'busy')"
          >
            ⏸ Pausa
          </button>
          <button
            v-if="row.availability !== 'offline'"
            type="button"
            class="klaos-supv-card__btn klaos-supv-card__btn--offline"
            @click="forceStatus(row, 'offline')"
          >
            ⏻ Offline
          </button>
        </footer>
      </article>

      <div v-if="!rows.length" class="klaos-supv__empty">
        Nenhum agente nessa conta.
      </div>
    </div>
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
  margin-bottom: 20px;
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
.klaos-supv__pill--online {
  background: #d1fae5;
  color: #065f46;
}
.klaos-supv__pill--busy {
  background: #fef3c7;
  color: #78350f;
}
.klaos-supv__pill--offline {
  background: #e5e7eb;
  color: #374151;
}
.klaos-supv__pill--chats {
  background: #dbeafe;
  color: #1e40af;
}

.klaos-supv__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 16px;
}

.klaos-supv-card {
  background: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  border: 1px solid #e5e7eb;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  transition: all 0.2s ease;
}
.klaos-supv-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
  transform: translateY(-1px);
}

.klaos-supv-card__head {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 14px;
  color: white;
  font-size: 12px;
  font-weight: 600;
  gap: 8px;
  flex-wrap: wrap;
}
.klaos-supv-card--online .klaos-supv-card__head {
  background: linear-gradient(90deg, #10b981 0%, #059669 100%);
}
.klaos-supv-card--busy .klaos-supv-card__head {
  background: linear-gradient(90deg, #f59e0b 0%, #d97706 100%);
}
.klaos-supv-card--offline .klaos-supv-card__head {
  background: linear-gradient(90deg, #6b7280 0%, #4b5563 100%);
}
.klaos-supv-card--overtime {
  border-color: #dc2626;
  box-shadow: 0 0 0 2px #fecaca;
  animation: klaos-supv-pulse 1.5s ease-in-out infinite;
}
.klaos-supv-card--overtime .klaos-supv-card__head {
  background: linear-gradient(90deg, #dc2626 0%, #b91c1c 100%);
}
@keyframes klaos-supv-pulse {
  0%, 100% { box-shadow: 0 0 0 2px #fecaca; }
  50% { box-shadow: 0 0 0 4px #fca5a5; }
}

.klaos-supv-card__head-status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.klaos-supv-card__dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: white;
}
.klaos-supv-card__reason {
  background: rgba(255, 255, 255, 0.2);
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.klaos-supv-card__reason-time {
  font-variant-numeric: tabular-nums;
  opacity: 0.95;
}

.klaos-supv-card__body {
  padding: 14px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.klaos-supv-card__avatar-wrap {
  display: flex;
  align-items: center;
  gap: 12px;
}
.klaos-supv-card__avatar {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  object-fit: cover;
  background: #e5e7eb;
  flex-shrink: 0;
}
.klaos-supv-card__avatar--placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  color: #6b7280;
  background: #f3f4f6;
  font-size: 16px;
}
.klaos-supv-card__name-block {
  min-width: 0;
  flex: 1;
}
.klaos-supv-card__name {
  font-weight: 600;
  color: #111827;
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.klaos-supv-card__email {
  font-size: 11px;
  color: #6b7280;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.klaos-supv-card__metrics {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
}
.klaos-supv-card__metric {
  background: #f9fafb;
  border-radius: 8px;
  padding: 8px 10px;
  text-align: center;
}
.klaos-supv-card__metric-val {
  font-size: 18px;
  font-weight: 700;
  color: #111827;
  line-height: 1.2;
}
.klaos-supv-card__metric-val--time {
  font-size: 13px;
  font-family: 'SF Mono', Monaco, monospace;
  letter-spacing: -0.5px;
}
.klaos-supv-card__metric-lbl {
  font-size: 10px;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  margin-top: 2px;
}

.klaos-supv-card__actions {
  display: flex;
  gap: 6px;
  padding: 10px 14px;
  border-top: 1px solid #f3f4f6;
  background: #fafafa;
}
.klaos-supv-card__btn {
  flex: 1;
  padding: 6px 10px;
  border-radius: 6px;
  border: 1px solid transparent;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  text-align: center;
}
.klaos-supv-card__btn--online {
  background: #d1fae5;
  color: #065f46;
  border-color: #6ee7b7;
}
.klaos-supv-card__btn--busy {
  background: #fef3c7;
  color: #78350f;
  border-color: #fcd34d;
}
.klaos-supv-card__btn--offline {
  background: #fee2e2;
  color: #991b1b;
  border-color: #fca5a5;
}
.klaos-supv-card__btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
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
