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
import { computed } from 'vue';

const props = defineProps({
  timestamp: { type: [Number, String], default: null },
});

const ageMinutes = computed(() => {
  if (!props.timestamp) return null;
  const ts = typeof props.timestamp === 'number'
    ? props.timestamp * 1000
    : new Date(props.timestamp).getTime();
  return Math.floor((Date.now() - ts) / 60000);
});

const label = computed(() => {
  const m = ageMinutes.value;
  if (m === null) return '';
  if (m < 1) return 'agora';
  if (m < 60) return `há ${m}min`;
  const h = Math.floor(m / 60);
  const remM = m % 60;
  if (h < 24) {
    return remM > 0 ? `há ${h}h${remM}min` : `há ${h}h`;
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
