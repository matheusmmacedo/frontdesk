<script setup>
// KLaOS — Dashboard de Saúde do WhatsApp por número (Fase 2 do fix de áudio).
//
// Mostra pra cada inbox WhatsApp Cloud da conta:
//   - Status Meta vivo (quality_rating, throughput, can_send_message)
//   - Counts 24h/7d/30d (sent/delivered/failed/read)
//   - Top contatos com falhas (24h)
//   - Top códigos de erro Meta (24h)
//
// Vive em /app/accounts/:id/settings/klaos-meta-health
// Permissão: administrator.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import axios from 'axios';

const { accountId } = useAccount();
const inboxes = ref([]);
const loading = ref(true);
const error = ref(null);
const generatedAt = ref(null);
let pollingTimer = null;

const fetchData = async () => {
  try {
    const resp = await axios.get(`/api/custom/v1/accounts/${accountId.value}/meta_health`);
    inboxes.value = resp.data.inboxes || [];
    generatedAt.value = resp.data.generated_at;
    error.value = null;
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
  } finally {
    loading.value = false;
  }
};

const qualityBadgeClass = rating => {
  switch ((rating || '').toUpperCase()) {
    case 'GREEN':
      return 'bg-n-teal-9 text-white';
    case 'YELLOW':
      return 'bg-n-amber-9 text-white';
    case 'RED':
      return 'bg-n-ruby-9 text-white';
    default:
      return 'bg-n-slate-7 text-n-slate-12';
  }
};

const failureRate = counts => {
  const total = counts.sent + counts.delivered + counts.failed + counts.read;
  if (total === 0) return 0;
  return Math.round((counts.failed / total) * 100);
};

const failureRateColor = rate => {
  if (rate >= 30) return 'text-n-ruby-11';
  if (rate >= 10) return 'text-n-amber-11';
  return 'text-n-teal-11';
};

const generatedAgo = computed(() => {
  if (!generatedAt.value) return '';
  const ago = Math.round((Date.now() - new Date(generatedAt.value).getTime()) / 1000);
  return `${ago}s atrás`;
});

onMounted(() => {
  fetchData();
  // Re-fetch a cada 60s pra dashboard ficar vivo (Meta API tem cache 5min server-side)
  pollingTimer = setInterval(fetchData, 60000);
});

onBeforeUnmount(() => {
  if (pollingTimer) clearInterval(pollingTimer);
});
</script>

<template>
  <div class="flex flex-col gap-6 p-6 max-w-6xl">
    <div class="flex justify-between items-end">
      <div>
        <h1 class="text-heading-1 text-n-slate-12 mb-1">Saúde do WhatsApp</h1>
        <p class="text-body-para text-n-slate-11 mb-0">
          Status ao vivo da Meta + falhas por número. Atualiza a cada minuto.
        </p>
      </div>
      <span v-if="generatedAt" class="text-body-small text-n-slate-10">
        Última atualização: {{ generatedAgo }}
      </span>
    </div>

    <div v-if="loading" class="text-body-para text-n-slate-11">Carregando...</div>

    <div
      v-else-if="error"
      class="p-4 rounded-lg bg-n-ruby-3 text-n-ruby-12 outline-1 outline outline-n-ruby-7"
    >
      Erro ao carregar: {{ error }}
    </div>

    <div v-else-if="inboxes.length === 0" class="text-body-para text-n-slate-11">
      Nenhuma inbox WhatsApp Cloud configurada.
    </div>

    <div
      v-for="inbox in inboxes"
      :key="inbox.inbox_id"
      class="flex flex-col gap-4 p-5 outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
    >
      <!-- Header da inbox: nome + status Meta -->
      <div class="flex justify-between items-start gap-4">
        <div class="flex flex-col">
          <h3 class="text-heading-2 text-n-slate-12 mb-1">{{ inbox.inbox_name }}</h3>
          <span class="text-body-small text-n-slate-11">{{ inbox.phone_number }}</span>
        </div>
        <div v-if="inbox.meta_status?.fetched_ok" class="flex gap-2 items-center flex-wrap">
          <span
            class="px-2 py-1 rounded text-body-small font-medium"
            :class="qualityBadgeClass(inbox.meta_status.quality_rating)"
          >
            Qualidade: {{ inbox.meta_status.quality_rating || '?' }}
          </span>
          <span
            v-if="inbox.meta_status.can_send_message === 'AVAILABLE'"
            class="px-2 py-1 rounded text-body-small bg-n-teal-3 text-n-teal-12"
          >
            ✓ Pode enviar
          </span>
          <span
            v-else
            class="px-2 py-1 rounded text-body-small bg-n-ruby-3 text-n-ruby-12"
          >
            ✗ {{ inbox.meta_status.can_send_message || 'Bloqueado' }}
          </span>
          <span class="px-2 py-1 rounded text-body-small bg-n-slate-3 text-n-slate-12">
            {{ inbox.meta_status.throughput_level || 'STANDARD' }}
          </span>
        </div>
        <div
          v-else
          class="px-2 py-1 rounded text-body-small bg-n-amber-3 text-n-amber-12"
        >
          ⚠ Erro ao consultar Meta
        </div>
      </div>

      <!-- Counts 24h / 7d / 30d -->
      <div class="grid grid-cols-3 gap-3">
        <div
          v-for="window in ['h24', 'd7', 'd30']"
          :key="window"
          class="p-3 rounded-lg bg-n-solid-1 outline-1 outline outline-n-weak"
        >
          <div class="text-body-small text-n-slate-11 mb-2">
            {{ window === 'h24' ? '24 horas' : window === 'd7' ? '7 dias' : '30 dias' }}
          </div>
          <div class="grid grid-cols-4 gap-1 text-body-small">
            <div class="text-center">
              <div class="text-n-slate-10 text-xs">Enviadas</div>
              <div class="text-n-slate-12 font-medium">{{ inbox.counts[window].sent }}</div>
            </div>
            <div class="text-center">
              <div class="text-n-slate-10 text-xs">Entregues</div>
              <div class="text-n-teal-11 font-medium">{{ inbox.counts[window].delivered }}</div>
            </div>
            <div class="text-center">
              <div class="text-n-slate-10 text-xs">Lidas</div>
              <div class="text-n-blue-11 font-medium">{{ inbox.counts[window].read }}</div>
            </div>
            <div class="text-center">
              <div class="text-n-slate-10 text-xs">Falhas</div>
              <div
                class="font-medium"
                :class="failureRateColor(failureRate(inbox.counts[window]))"
              >
                {{ inbox.counts[window].failed }}
                <span class="text-xs">({{ failureRate(inbox.counts[window]) }}%)</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Top falhas por código (24h) -->
      <div v-if="inbox.top_error_codes.length > 0">
        <h4 class="text-heading-3 text-n-slate-12 mb-2">
          Códigos de erro Meta (24h)
        </h4>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-2">
          <div
            v-for="ec in inbox.top_error_codes"
            :key="ec.code"
            class="p-2 rounded bg-n-solid-1 outline-1 outline outline-n-weak flex justify-between items-center"
          >
            <span
              class="text-body-small font-mono"
              :class="ec.code === 'sem_detalhe' ? 'text-n-amber-11' : 'text-n-slate-12'"
            >
              {{ ec.code === 'sem_detalhe' ? '⚠ sem motivo' : ec.code }}
            </span>
            <span class="text-body-small font-medium text-n-ruby-11">{{ ec.count }}</span>
          </div>
        </div>
      </div>

      <!-- Top contatos com mais falhas (24h) -->
      <div v-if="inbox.top_failing_contacts.length > 0">
        <h4 class="text-heading-3 text-n-slate-12 mb-2">
          Contatos com mais falhas (24h)
        </h4>
        <div class="flex flex-col gap-1">
          <div
            v-for="contact in inbox.top_failing_contacts"
            :key="contact.contact_id"
            class="p-2 rounded bg-n-solid-1 outline-1 outline outline-n-weak flex justify-between items-center"
          >
            <div class="flex flex-col">
              <span class="text-body-small text-n-slate-12">{{ contact.name }}</span>
              <span class="text-xs text-n-slate-10 font-mono">{{ contact.phone_number }}</span>
            </div>
            <span class="text-body-small font-medium text-n-ruby-11">{{ contact.failed }} falhas</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
