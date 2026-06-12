<script setup>
// KLaOS — Canais & Números (visão consolidada multi-canal)
//
// Inspirado no "Filas" do Qualizap: uma tabela única lista TODAS as inboxes
// da conta (WhatsApp Oficial/Não-oficial, Facebook, Instagram, Telegram,
// Email, API, etc) com status de autenticação numa coluna.
//
// MVP read-only: lê de /api/v1/accounts/:id/inboxes (endpoint Chatwoot
// existente). Sem backend custom.
//
// Rota: /app/accounts/:accountId/canais

import { ref, computed, onMounted } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import axios from 'axios';

const currentAccountId = useMapGetter('getCurrentAccountId');

const inboxes = ref([]);
const loading = ref(true);
const error = ref(null);

const CHANNEL_LABEL = {
  'Channel::Whatsapp':       { label: 'WhatsApp', icon: '🟢', kind: 'oficial' },
  'Channel::Api':            { label: 'API',      icon: '🔌', kind: 'custom' },
  'Channel::FacebookPage':   { label: 'Facebook', icon: '📘', kind: 'social' },
  'Channel::Instagram':      { label: 'Instagram',icon: '📷', kind: 'social' },
  'Channel::Telegram':       { label: 'Telegram', icon: '✈️', kind: 'social' },
  'Channel::TwilioSms':      { label: 'SMS',      icon: '💬', kind: 'sms' },
  'Channel::Email':          { label: 'Email',    icon: '✉️', kind: 'email' },
  'Channel::WebWidget':      { label: 'WebChat',  icon: '🌐', kind: 'web' },
  'Channel::Sms':            { label: 'SMS',      icon: '💬', kind: 'sms' },
  'Channel::Line':           { label: 'LINE',     icon: '🟢', kind: 'social' },
  'Channel::TikTok':         { label: 'TikTok',   icon: '⚫', kind: 'social' },
};

const fetchInboxes = async () => {
  loading.value = true;
  try {
    const acct = currentAccountId.value;
    const r = await axios.get(`/api/v1/accounts/${acct}/inboxes`);
    inboxes.value = r.data?.payload || [];
    error.value = null;
  } catch (e) {
    error.value = e?.response?.data?.error || e.message || 'Erro ao carregar';
  } finally {
    loading.value = false;
  }
};

const stats = computed(() => {
  const total = inboxes.value.length;
  const byKind = {};
  for (const ib of inboxes.value) {
    const k = CHANNEL_LABEL[ib.channel_type]?.kind || 'outros';
    byKind[k] = (byKind[k] || 0) + 1;
  }
  return { total, byKind };
});

const channelMeta = ib => CHANNEL_LABEL[ib.channel_type] || { label: ib.channel_type, icon: '🔧', kind: 'outros' };

const phoneOf = ib => {
  if (ib.phone_number) return ib.phone_number;
  if (ib.provider_config?.phone_number) return ib.provider_config.phone_number;
  return '—';
};

const isWhatsappOfficial = ib => {
  if (ib.channel_type !== 'Channel::Whatsapp') return false;
  const provider = (ib.provider || ib.provider_config?.api_key) ?? '';
  return /whatsapp_cloud|whatsapp$/i.test(String(ib.provider || '')) ||
         (ib.provider_config?.api_key && ib.provider === 'whatsapp_cloud');
};

const statusOf = ib => {
  if (ib.reauthorization_required) return { label: 'Reautenticar', tone: 'warn' };
  if (ib.channel_type === 'Channel::Whatsapp' && !ib.provider_config) return { label: 'Pendente', tone: 'warn' };
  return { label: 'Autenticado', tone: 'ok' };
};

const lastUpdated = ib => {
  const ts = ib.updated_at || ib.created_at;
  if (!ts) return '—';
  try {
    const d = new Date(ts);
    return d.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
  } catch (e) { return '—'; }
};

onMounted(() => { fetchInboxes(); });
</script>

<template>
  <div class="klaos-channels klaos-enterprise">
    <header class="klaos-channels__header">
      <div>
        <h1 class="klaos-channels__title">Canais & Números</h1>
        <p class="klaos-channels__subtitle">
          Visão consolidada de todas as inboxes da conta — WhatsApp, Facebook,
          Instagram, API e outros.
        </p>
      </div>
      <button
        class="klaos-channels__refresh klaos-card"
        :disabled="loading"
        @click="fetchInboxes"
      >
        <span v-if="loading">Atualizando…</span>
        <span v-else>↻ Atualizar</span>
      </button>
    </header>

    <!-- KPI strip -->
    <div class="klaos-channels__kpi-strip">
      <div class="klaos-card klaos-channels__kpi">
        <span class="klaos-channels__kpi-num">{{ stats.total }}</span>
        <span class="klaos-channels__kpi-label">canais totais</span>
      </div>
      <div
        v-for="(count, kind) in stats.byKind"
        :key="kind"
        class="klaos-card klaos-channels__kpi"
      >
        <span class="klaos-channels__kpi-num">{{ count }}</span>
        <span class="klaos-channels__kpi-label">{{ kind }}</span>
      </div>
    </div>

    <!-- Erro -->
    <div v-if="error" class="klaos-card klaos-channels__error">
      Falha ao carregar canais: {{ error }}
    </div>

    <!-- Tabela canais -->
    <article class="klaos-card klaos-channels__table-card">
      <div class="klaos-channels__table-header">
        <h2 class="klaos-channels__table-title">Inboxes</h2>
        <span class="klaos-pill klaos-channels__count-pill">{{ inboxes.length }}</span>
      </div>

      <div v-if="loading && inboxes.length === 0" class="klaos-channels__empty">
        Carregando…
      </div>
      <div v-else-if="!loading && inboxes.length === 0" class="klaos-channels__empty">
        Nenhum canal configurado ainda.
      </div>

      <div v-else class="klaos-channels__table-wrap">
        <table class="klaos-channels__table">
          <thead>
            <tr class="klaos-table-row">
              <th>Nome</th>
              <th>Canal</th>
              <th>Telefone</th>
              <th>Status</th>
              <th>Última atualização</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="ib in inboxes"
              :key="ib.id"
              class="klaos-table-row klaos-channels__row"
            >
              <td>
                <strong>{{ ib.name }}</strong>
                <small class="klaos-channels__id">#{{ ib.id }}</small>
              </td>
              <td>
                <span class="klaos-pill klaos-channels__channel-pill">
                  <span>{{ channelMeta(ib).icon }}</span>
                  <span>{{ channelMeta(ib).label }}</span>
                  <small v-if="isWhatsappOfficial(ib)">Oficial</small>
                </span>
              </td>
              <td class="klaos-channels__mono">{{ phoneOf(ib) }}</td>
              <td>
                <span
                  class="klaos-pill"
                  :class="{
                    'klaos-channels__status-ok':   statusOf(ib).tone === 'ok',
                    'klaos-channels__status-warn': statusOf(ib).tone === 'warn',
                  }"
                >
                  {{ statusOf(ib).label }}
                </span>
              </td>
              <td class="klaos-channels__mono klaos-channels__dim">{{ lastUpdated(ib) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </article>
  </div>
</template>

<style scoped>
.klaos-channels {
  height: 100%;
  overflow-y: auto;
  padding: 32px 40px 48px;
  max-width: 1280px;
  margin: 0 auto;
  width: 100%;
}

.klaos-channels__header {
  display: flex; align-items: flex-start; justify-content: space-between; gap: 16px;
  margin-bottom: 24px;
}
.klaos-channels__title {
  margin: 0 0 6px;
  font-size: 22px; font-weight: 600;
  letter-spacing: -0.022em;
  color: rgb(15 23 42);
}
.klaos-channels__subtitle {
  margin: 0;
  font-size: 13px; color: rgb(100 116 139);
  max-width: 600px;
  letter-spacing: -0.01em;
}

.klaos-channels__refresh {
  cursor: pointer; padding: 8px 14px;
  font-size: 13px; font-weight: 500;
  letter-spacing: -0.01em;
  color: rgb(30 41 59);
  white-space: nowrap;
}
.klaos-channels__refresh:disabled { opacity: 0.5; cursor: wait; }

.klaos-channels__kpi-strip {
  display: flex; gap: 12px; flex-wrap: wrap;
  margin-bottom: 16px;
}
.klaos-channels__kpi {
  flex: 0 0 auto;
  min-width: 110px;
  padding: 14px 16px;
  display: flex; flex-direction: column; gap: 4px;
}
.klaos-channels__kpi-num {
  font-size: 22px; font-weight: 600;
  letter-spacing: -0.022em;
  font-variant-numeric: tabular-nums;
  color: rgb(15 23 42); line-height: 1;
}
.klaos-channels__kpi-label {
  font-size: 11px; color: rgb(100 116 139);
  text-transform: capitalize;
  letter-spacing: -0.01em;
}

.klaos-channels__error {
  padding: 12px 16px; margin-bottom: 12px;
  background: rgb(254 226 226);
  color: rgb(153 27 27);
  border-color: rgb(252 165 165);
  font-size: 13px;
}

.klaos-channels__table-card { padding: 0; overflow: hidden; }
.klaos-channels__table-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 14px 18px;
  border-bottom: 1px solid var(--klaos-hairline-color);
}
.klaos-channels__table-title {
  margin: 0; font-size: 14px; font-weight: 600;
  letter-spacing: -0.011em; color: rgb(15 23 42);
}
.klaos-channels__count-pill { background: rgb(241 245 249); color: rgb(71 85 105); }

.klaos-channels__empty { padding: 32px; text-align: center; color: rgb(148 163 184); font-size: 13px; }

.klaos-channels__table-wrap { width: 100%; overflow-x: auto; }
.klaos-channels__table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
}
.klaos-channels__table thead th {
  text-align: left;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgb(100 116 139);
  padding: 8px 18px;
  background: rgb(248 250 252);
}
.klaos-channels__table tbody td {
  padding: 8px 18px;
  font-size: 13px;
  color: rgb(15 23 42);
  vertical-align: middle;
  letter-spacing: -0.01em;
}
.klaos-channels__id { display: block; color: rgb(148 163 184); font-size: 11px; font-variant-numeric: tabular-nums; }
.klaos-channels__mono { font-variant-numeric: tabular-nums; }
.klaos-channels__dim { color: rgb(100 116 139); }

.klaos-channels__channel-pill {
  background: rgb(248 250 252);
  color: rgb(30 41 59);
  border: 1px solid var(--klaos-hairline-color);
}
.klaos-channels__channel-pill small {
  margin-left: 4px;
  font-size: 9px;
  font-weight: 700;
  padding: 1px 4px;
  border-radius: 4px;
  background: rgb(34 197 94 / 0.1);
  color: rgb(22 101 52);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.klaos-channels__status-ok {
  background: rgb(34 197 94 / 0.1);
  color: rgb(22 101 52);
}
.klaos-channels__status-warn {
  background: rgb(245 158 11 / 0.1);
  color: rgb(133 77 14);
}

/* Dark mode */
:global(.dark) .klaos-channels__title,
:global(.dark) .klaos-channels__kpi-num,
:global(.dark) .klaos-channels__table tbody td,
:global(.dark) .klaos-channels__table-title { color: rgb(226 232 240); }
:global(.dark) .klaos-channels__subtitle,
:global(.dark) .klaos-channels__kpi-label,
:global(.dark) .klaos-channels__dim,
:global(.dark) .klaos-channels__id { color: rgb(148 163 184); }
:global(.dark) .klaos-channels__table thead th { background: rgb(15 17 22); color: rgb(148 163 184); }

@media (max-width: 768px) {
  .klaos-channels { padding: 20px; }
  .klaos-channels__header { flex-direction: column; }
}
</style>
