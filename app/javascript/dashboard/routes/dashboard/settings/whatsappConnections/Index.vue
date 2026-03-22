<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import SettingsLayout from '../SettingsLayout.vue';

const store = useStore();
const router = useRouter();
const activeTab = ref('meta_cloud');

onMounted(() => {
  store.dispatch('whatsappConnections/fetchConnections');
});

const connections = computed(() =>
  store.getters['whatsappConnections/getConnections']
);
const metaConnections = computed(() =>
  store.getters['whatsappConnections/getMetaConnections']
);
const evolutionConnections = computed(() =>
  store.getters['whatsappConnections/getEvolutionConnections']
);
const uiFlags = computed(() =>
  store.getters['whatsappConnections/getUIFlags']
);

const currentConnections = computed(() =>
  activeTab.value === 'meta_cloud'
    ? metaConnections.value
    : evolutionConnections.value
);

function navigateToNewMeta() {
  router.push({ name: 'whatsapp_connections_new_meta' });
}

function navigateToNewEvolution() {
  router.push({ name: 'whatsapp_connections_new_evolution' });
}

function navigateToDetail(connectionId) {
  router.push({
    name: 'whatsapp_connections_detail',
    params: { connectionId },
  });
}

async function deleteConnection(connectionId) {
  if (!window.confirm('Are you sure you want to delete this connection?'))
    return;
  await store.dispatch('whatsappConnections/deleteConnection', connectionId);
}

function statusBadgeClass(status) {
  const classes = {
    active: 'bg-green-100 text-green-800',
    disconnected: 'bg-yellow-100 text-yellow-800',
    error: 'bg-red-100 text-red-800',
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
}
</script>

<template>
  <SettingsLayout>
    <template #header>
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-semibold text-n-slate-12">
          WhatsApp Connections
        </h1>
      </div>
    </template>

    <template #body>
      <div class="flex flex-col gap-6">
        <!-- Tabs -->
        <div class="flex gap-2 border-b border-n-strong pb-0">
          <button
            class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeTab === 'meta_cloud'
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTab = 'meta_cloud'"
          >
            Meta WABA ({{ metaConnections.length }})
          </button>
          <button
            class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeTab === 'evolution'
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
            "
            @click="activeTab = 'evolution'"
          >
            Evolution API ({{ evolutionConnections.length }})
          </button>
        </div>

        <!-- Action Button -->
        <div class="flex justify-end">
          <button
            v-if="activeTab === 'meta_cloud'"
            class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
            @click="navigateToNewMeta"
          >
            + New Meta WABA Connection
          </button>
          <button
            v-else
            class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
            @click="navigateToNewEvolution"
          >
            + New Evolution Connection
          </button>
        </div>

        <!-- Loading -->
        <div v-if="uiFlags.isFetching" class="text-center py-8 text-n-slate-11">
          Loading connections...
        </div>

        <!-- Empty State -->
        <div
          v-else-if="currentConnections.length === 0"
          class="text-center py-12 bg-n-background rounded-lg border border-n-weak"
        >
          <p class="text-n-slate-11 text-lg">
            No {{ activeTab === 'meta_cloud' ? 'Meta WABA' : 'Evolution API' }}
            connections yet.
          </p>
          <p class="text-n-slate-9 mt-2">
            Click the button above to add your first connection.
          </p>
        </div>

        <!-- Connections List -->
        <div v-else class="flex flex-col gap-4">
          <div
            v-for="connection in currentConnections"
            :key="connection.id"
            class="p-4 bg-white rounded-lg border border-n-weak hover:border-n-brand cursor-pointer transition-colors"
            @click="navigateToDetail(connection.id)"
          >
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="flex flex-col">
                  <span class="font-semibold text-n-slate-12">
                    {{ connection.name }}
                  </span>
                  <span class="text-sm text-n-slate-9">
                    {{ connection.phone_numbers_count }} numbers &middot;
                    {{ connection.linked_count }} linked &middot;
                    {{ connection.available_count }} available
                  </span>
                </div>
              </div>
              <div class="flex items-center gap-3">
                <span
                  class="px-2 py-1 text-xs font-medium rounded-full"
                  :class="statusBadgeClass(connection.status)"
                >
                  {{ connection.status }}
                </span>
                <button
                  class="text-n-slate-9 hover:text-red-600 text-sm"
                  @click.stop="deleteConnection(connection.id)"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
