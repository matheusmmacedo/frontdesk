<script setup>
// KLaOS — Central do Agente (Painel pessoal)
//
// Página inicial do agente — substitui/complementa a "Mentions" como home.
// 4 blocos MVP:
//   - Saudação + relógio gigante + status do turno
//   - Novidades feed (placeholder com texto fixo até #157 puxar de DB)
//   - Minhas Tarefas mini-cards (placeholder: pendentes/hoje/atrasadas/vencidas)
//   - Atalhos rápidos (Minhas conversas, Não atribuídas, Adiadas)
//
// Visual: usa as utility classes do polish enterprise injetadas no App.vue
// (.klaos-card, .klaos-clock, .klaos-pill, .klaos-kpi-delta).
//
// Rota: /app/accounts/:accountId/central — registrada via patch no
// dashboard.routes.js (custom/vite/klaos-patches.js).

import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const router = useRouter();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const currentAccountId = useMapGetter('getCurrentAccountId');

const now = ref(new Date());
let clockInterval = null;

const hh = computed(() => now.value.getHours().toString().padStart(2, '0'));
const mm = computed(() => now.value.getMinutes().toString().padStart(2, '0'));

const greeting = computed(() => {
  const h = now.value.getHours();
  if (h < 5) return 'Boa madrugada';
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
});

const userName = computed(() => {
  const u = currentUser.value;
  return (u?.available_name || u?.name || '').split(' ')[0] || 'agente';
});

// Placeholder até wiring real (#155 Tarefas + #157 Novidades)
const myTaskStats = ref({
  pendentes: 0,
  hoje: 0,
  atrasadas: 0,
  vencidas: 0,
  agenda: 0,
});

const newsItems = ref([
  // placeholder vazio — vai puxar de uma futura tabela klaos_news
]);

// Navegação programática via Vue Router + Vuex.
// "Mine/Unassigned/Snoozed" não têm URL própria — são filtros locais no
// `home`. Logo navegamos pra `home` e setamos o store via dispatch.
// "Mentions" e "Unattended" têm rota dedicada (no plural — atenção).
const goTo = async where => {
  const acct = currentAccountId.value;
  if (!acct) return;
  try {
    switch (where) {
      case 'mine':
        store.dispatch('setChatStatusFilter', 'open');
        store.dispatch('setActiveInbox', null);
        await router.push({ name: 'home', params: { accountId: acct } });
        break;
      case 'unassigned':
        // Mesma página, filtro local mudará na próxima interação
        store.dispatch('setChatStatusFilter', 'open');
        await router.push({ name: 'home', params: { accountId: acct } });
        break;
      case 'snoozed':
        store.dispatch('setChatStatusFilter', 'snoozed');
        await router.push({ name: 'home', params: { accountId: acct } });
        break;
      case 'mentions':
        await router.push({
          name: 'conversation_mentions',
          params: { accountId: acct }
        });
        break;
      case 'unattended':
        await router.push({
          name: 'conversation_unattended',
          params: { accountId: acct }
        });
        break;
    }
  } catch (e) {
    // Router pode lançar NavigationDuplicated — silencioso
  }
};

onMounted(() => {
  clockInterval = setInterval(() => { now.value = new Date(); }, 1000);
});
onBeforeUnmount(() => {
  if (clockInterval) clearInterval(clockInterval);
});
</script>

<template>
  <div class="klaos-central klaos-enterprise">
    <!-- ============================================================ -->
    <!-- HERO: saudação + relógio gigante + status -->
    <!-- ============================================================ -->
    <header class="klaos-central__hero">
      <div class="klaos-central__greeting">
        <p class="klaos-central__hello">{{ greeting }}, {{ userName }}</p>
        <h1 class="klaos-clock">{{ hh }}<span class="klaos-central__colon">:</span>{{ mm }}</h1>
        <p class="klaos-central__subtitle">
          Sua central de atendimento — tudo o que importa pra você hoje.
        </p>
      </div>
    </header>

    <!-- ============================================================ -->
    <!-- GRID: novidades + tarefas -->
    <!-- ============================================================ -->
    <section class="klaos-central__grid">
      <!-- Novidades feed -->
      <article class="klaos-card klaos-central__news">
        <header class="klaos-central__card-header">
          <h2 class="klaos-central__card-title">Novidades</h2>
          <span class="klaos-pill klaos-central__pill-soft">{{ newsItems.length }}</span>
        </header>
        <div class="klaos-central__news-body">
          <template v-if="newsItems.length === 0">
            <p class="klaos-central__empty">Sem novidades por enquanto.</p>
          </template>
          <template v-else>
            <div
              v-for="item in newsItems"
              :key="item.id"
              class="klaos-central__news-item"
            >
              <strong>{{ item.title }}</strong>
              <span>{{ item.summary }}</span>
            </div>
          </template>
        </div>
      </article>

      <!-- Minhas tarefas mini-cards -->
      <article class="klaos-card klaos-central__tasks">
        <header class="klaos-central__card-header">
          <h2 class="klaos-central__card-title">Minhas tarefas</h2>
        </header>
        <div class="klaos-central__tasks-grid">
          <div class="klaos-central__mini">
            <span class="klaos-central__mini-num">{{ myTaskStats.pendentes }}</span>
            <span class="klaos-central__mini-label">pendentes</span>
          </div>
          <div class="klaos-central__mini">
            <span class="klaos-central__mini-num">{{ myTaskStats.hoje }}</span>
            <span class="klaos-central__mini-label">para hoje</span>
          </div>
          <div class="klaos-central__mini">
            <span class="klaos-central__mini-num">{{ myTaskStats.atrasadas }}</span>
            <span class="klaos-central__mini-label">atrasadas</span>
          </div>
          <div class="klaos-central__mini">
            <span class="klaos-central__mini-num">{{ myTaskStats.vencidas }}</span>
            <span class="klaos-central__mini-label">vencidas</span>
          </div>
          <div class="klaos-central__mini">
            <span class="klaos-central__mini-num">{{ myTaskStats.agenda }}</span>
            <span class="klaos-central__mini-label">agenda hoje</span>
          </div>
        </div>
      </article>
    </section>

    <!-- ============================================================ -->
    <!-- ATALHOS RÁPIDOS pra abas do Frontdesk -->
    <!-- ============================================================ -->
    <section class="klaos-central__shortcuts">
      <h2 class="klaos-central__section-title">Atalhos</h2>
      <div class="klaos-central__shortcuts-grid">
        <button class="klaos-card klaos-central__shortcut" @click="goTo('mine')">
          <span class="klaos-central__shortcut-icon">📋</span>
          <span class="klaos-central__shortcut-text">
            <strong>Minhas conversas</strong>
            <small>Em atendimento por você</small>
          </span>
        </button>
        <button class="klaos-card klaos-central__shortcut" @click="goTo('unassigned')">
          <span class="klaos-central__shortcut-icon">📥</span>
          <span class="klaos-central__shortcut-text">
            <strong>Não atribuídas</strong>
            <small>Aguardando alguém pegar</small>
          </span>
        </button>
        <button class="klaos-card klaos-central__shortcut" @click="goTo('snoozed')">
          <span class="klaos-central__shortcut-icon">⏰</span>
          <span class="klaos-central__shortcut-text">
            <strong>Adiadas</strong>
            <small>Vão reabrir em breve</small>
          </span>
        </button>
        <button class="klaos-card klaos-central__shortcut" @click="goTo('mentions')">
          <span class="klaos-central__shortcut-icon">@</span>
          <span class="klaos-central__shortcut-text">
            <strong>Menções</strong>
            <small>Onde você foi mencionado</small>
          </span>
        </button>
      </div>
    </section>
  </div>
</template>

<style scoped>
.klaos-central {
  height: 100%;
  overflow-y: auto;
  padding: 32px 40px 48px;
  max-width: 1200px;
  margin: 0 auto;
  width: 100%;
}

.klaos-central__hero {
  margin-bottom: 32px;
}
.klaos-central__greeting {
  text-align: left;
}
.klaos-central__hello {
  font-size: 14px;
  font-weight: 500;
  color: rgb(100 116 139);
  margin: 0 0 6px;
  letter-spacing: -0.01em;
}
.klaos-central__colon {
  color: rgb(100 116 139);
  font-weight: 300;
  margin: 0 4px;
}
.klaos-central__subtitle {
  margin: 10px 0 0;
  font-size: 13px;
  color: rgb(100 116 139);
  letter-spacing: -0.01em;
}

.klaos-central__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 32px;
}

.klaos-central__card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 18px;
  border-bottom: 1px solid var(--klaos-hairline-color);
}
.klaos-central__card-title {
  margin: 0;
  font-size: 14px;
  font-weight: 600;
  letter-spacing: -0.011em;
  color: rgb(15 23 42);
}
.klaos-central__pill-soft {
  background: rgb(241 245 249);
  color: rgb(71 85 105);
}

.klaos-central__news-body { padding: 16px 18px; min-height: 80px; }
.klaos-central__empty { color: rgb(148 163 184); font-size: 13px; margin: 0; }
.klaos-central__news-item {
  display: flex; flex-direction: column; gap: 4px;
  padding: 10px 0;
  border-bottom: 1px solid var(--klaos-hairline-color);
}
.klaos-central__news-item:last-child { border-bottom: 0; }

.klaos-central__tasks-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 8px;
  padding: 18px;
}
.klaos-central__mini {
  display: flex; flex-direction: column;
  align-items: center;
  text-align: center;
  padding: 12px 8px;
  border-radius: var(--klaos-radius-sm);
}
.klaos-central__mini-num {
  font-size: 24px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.025em;
  color: rgb(15 23 42);
  line-height: 1;
}
.klaos-central__mini-label {
  margin-top: 6px;
  font-size: 11px;
  color: rgb(100 116 139);
  letter-spacing: -0.01em;
  text-align: center;
}

.klaos-central__section-title {
  margin: 0 0 12px;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: rgb(100 116 139);
}

.klaos-central__shortcuts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 12px;
}
.klaos-central__shortcut {
  display: flex; align-items: center; gap: 12px;
  padding: 14px 16px;
  cursor: pointer;
  text-align: left;
  transition: transform 0.08s, box-shadow 0.08s;
}
.klaos-central__shortcut:hover {
  box-shadow: var(--klaos-shadow-sm);
  transform: translateY(-1px);
}
.klaos-central__shortcut-icon { font-size: 22px; flex-shrink: 0; }
.klaos-central__shortcut-text {
  display: flex; flex-direction: column;
}
.klaos-central__shortcut-text strong {
  font-size: 13px; font-weight: 600;
  letter-spacing: -0.01em;
  color: rgb(15 23 42);
}
.klaos-central__shortcut-text small {
  font-size: 11px; color: rgb(100 116 139);
  letter-spacing: -0.01em;
}

/* Dark mode */
:global(.dark) .klaos-central__hello,
:global(.dark) .klaos-central__subtitle,
:global(.dark) .klaos-central__mini-label,
:global(.dark) .klaos-central__shortcut-text small {
  color: rgb(148 163 184);
}
:global(.dark) .klaos-central__card-title,
:global(.dark) .klaos-central__mini-num,
:global(.dark) .klaos-central__shortcut-text strong {
  color: rgb(226 232 240);
}
:global(.dark) .klaos-central__pill-soft {
  background: rgb(30 41 59);
  color: rgb(148 163 184);
}

@media (max-width: 768px) {
  .klaos-central { padding: 20px; }
  .klaos-central__grid { grid-template-columns: 1fr; }
  .klaos-central__tasks-grid { grid-template-columns: repeat(2, 1fr); }
}
</style>
