<script setup>
// KLaOS — Ícone manifest (NÃO RENDERIZADO em runtime, só pra Tailwind JIT)
//
// Tailwind/@egoist/tailwindcss-icons só geram CSS pros ícones que
// aparecem como string em arquivos-fonte (.vue, .js) listados no
// `content` do tailwind.config.js.
//
// Como vários itens KLaOS (Central, Canais, Formato do Nome, Motivos de
// Pausa, etc) são injetados em runtime via klaos-patches.js (string-replace
// no bundle Vite), os nomes dos ícones NÃO aparecem nos arquivos-fonte
// originais → JIT não gera o CSS → ícones renderizam vazios na sidebar.
//
// Este arquivo lista TODAS as classes `i-lucide-*` usadas pelos patches
// custom. Ele é importado por um arquivo top-level mas a renderização
// está sob v-if="false" pra não consumir DOM. O JIT escaneia o template
// e gera o CSS dos ícones.
//
// Pra adicionar um ícone novo num patch klaos:
//   1. Adicionar o nome aqui (i-lucide-foo)
//   2. Usar 'i-lucide-foo' no patch
</script>

<template>
  <!-- Renderiza nada em runtime, mas o JIT escaneia este template -->
  <div v-if="false" aria-hidden="true">
    <!-- Sidebar primária -->
    <span class="i-lucide-blocks"></span>
    <span class="i-lucide-megaphone"></span>
    <span class="i-lucide-house"></span>
    <span class="i-lucide-radio-tower"></span>

    <!-- Items de Configurações KLaOS -->
    <span class="i-lucide-id-card"></span>
    <span class="i-lucide-coffee"></span>
    <span class="i-lucide-activity"></span>

    <!-- Reserva pra próximas telas (KPI, tarefas, agendas) -->
    <span class="i-lucide-bar-chart-3"></span>
    <span class="i-lucide-list-checks"></span>
    <span class="i-lucide-calendar-clock"></span>
    <span class="i-lucide-newspaper"></span>
    <span class="i-lucide-radio"></span>
    <span class="i-lucide-antenna"></span>
    <span class="i-lucide-home"></span>
    <span class="i-lucide-target"></span>
    <span class="i-lucide-trending-up"></span>
    <span class="i-lucide-trending-down"></span>

    <!-- Classes Tailwind usadas em patches (string-replace runtime) que o
         JIT não detecta porque não aparecem nos arquivos-fonte do dashboard.
         Mesma lógica dos ícones lucide acima. -->
    <span class="bg-amber-500"></span>
    <span class="bg-amber-400"></span>
    <span class="bg-amber-600"></span>
    <span class="text-amber-700"></span>
    <span class="text-amber-800"></span>
    <span class="text-amber-900"></span>
  </div>
</template>
