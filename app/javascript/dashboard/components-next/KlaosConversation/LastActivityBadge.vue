<script setup>
// KLaOS — Badge de "Tempo desde última mensagem" na card da conversa
// (O.9 do SDD, paridade Kualiz "Painel de Atendimentos").
//
// Substitui o TimeAgo padrão por um badge mais destacado e colorido por
// faixa de tempo, dando ao agente sinal visual claro de SLA na lista:
//   - verde: < 1h (recente)
//   - cinza: 1h ~ 6h (normal)
//   - âmbar: 6h ~ 24h (atenção)
//   - vermelho: > 24h (urgente)
//
// Multi-tenant nato — vale pra qualquer conta sem config.
//
// Tick 1s ao vivo (paridade Kualiz "relógio"): um único setInterval global
// (módulo-level) atualiza um ref reativo compartilhado entre TODAS as
// instâncias do badge — N cards na lista usam 1 timer, não N timers.
import { computed, ref, onUnmounted } from 'vue';

const sharedNow = ref(Date.now());
let tickerInterval = null;
let tickerRefs = 0;
const useTicker = () => {
  tickerRefs += 1;
  if (!tickerInterval) {
    tickerInterval = setInterval(() => {
      sharedNow.value = Date.now();
    }, 1000);
  }
  onUnmounted(() => {
    tickerRefs -= 1;
    if (tickerRefs <= 0 && tickerInterval) {
      clearInterval(tickerInterval);
      tickerInterval = null;
      tickerRefs = 0;
    }
  });
};

const props = defineProps({
  timestamp: { type: [Number, String], default: null },
});

useTicker();

const ageSeconds = computed(() => {
  if (!props.timestamp) return null;
  const ts = typeof props.timestamp === 'number'
    ? props.timestamp * 1000
    : new Date(props.timestamp).getTime();
  return Math.max(0, Math.floor((sharedNow.value - ts) / 1000));
});

const ageMinutes = computed(() =>
  ageSeconds.value === null ? null : Math.floor(ageSeconds.value / 60)
);

const label = computed(() => {
  const s = ageSeconds.value;
  if (s === null) return '';
  // Tick visível por segundo nas faixas curtas (paridade Kualiz "relógio").
  if (s < 60) return `há ${s}s`;
  const m = Math.floor(s / 60);
  const remS = s % 60;
  if (m < 60) return `há ${m}min ${remS}s`;
  const h = Math.floor(m / 60);
  const remM = m % 60;
  if (h < 24) {
    return remS > 0 || remM > 0
      ? `há ${h}h ${remM}min ${remS}s`
      : `há ${h}h`;
  }
  const d = Math.floor(h / 24);
  const remH = h % 24;
  if (d < 7) return remH > 0 ? `há ${d}d ${remH}h` : `há ${d}d`;
  return `há ${d}d`;
});

const colorClass = computed(() => {
  const m = ageMinutes.value;
  if (m === null) return 'text-n-slate-10';
  if (m < 60) return 'text-n-teal-11 font-semibold';
  if (m < 360) return 'text-n-slate-11';
  if (m < 1440) return 'text-n-amber-11 font-semibold';
  return 'text-n-ruby-11 font-bold';
});
</script>

<template>
  <span :class="['text-xxs whitespace-nowrap', colorClass]">{{ label }}</span>
</template>
