<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const activeTab = ref('meta_cloud');
const showDeleteModal = ref(false);
const selectedConnection = ref(null);
const isDeleting = ref(false);

onMounted(() => {
  store.dispatch('whatsappConnections/fetchConnections');
});

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

// Evolution: só permite 1 conexão por account
const canCreateEvolution = computed(
  () => evolutionConnections.value.length === 0
);

function navigateToNewMeta() {
  router.push({ name: 'whatsapp_connections_new_meta' });
}

function navigateToNewEvolution() {
  if (!canCreateEvolution.value) {
    useAlert(t('WHATSAPP_CONNECTIONS.ERRORS.EVOLUTION_ALREADY_EXISTS'));
    return;
  }
  router.push({ name: 'whatsapp_connections_new_evolution' });
}

function navigateToDetail(connectionId) {
  router.push({
    name: 'whatsapp_connections_detail',
    params: { connectionId },
  });
}

function openDeleteModal(connection) {
  selectedConnection.value = connection;
  showDeleteModal.value = true;
}

async function confirmDelete() {
  if (!selectedConnection.value) return;
  isDeleting.value = true;
  try {
    await store.dispatch(
      'whatsappConnections/deleteConnection',
      selectedConnection.value.id
    );
  } catch (error) {
    useAlert(error?.response?.data?.error || error.message);
  } finally {
    isDeleting.value = false;
    showDeleteModal.value = false;
    selectedConnection.value = null;
  }
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
  <div class="flex flex-col gap-6 w-full">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-semibold text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.TITLE') }}
      </h1>
    </div>

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
        {{ t('WHATSAPP_CONNECTIONS.TABS.OFFICIAL') }}
        ({{ metaConnections.length }})
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
        {{ t('WHATSAPP_CONNECTIONS.TABS.UNOFFICIAL') }}
        ({{ evolutionConnections.length }})
      </button>
    </div>

    <!-- Action Button -->
    <div class="flex justify-end">
      <button
        v-if="activeTab === 'meta_cloud'"
        class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
        @click="navigateToNewMeta"
      >
        {{ t('WHATSAPP_CONNECTIONS.ACTIONS.NEW_OFFICIAL') }}
      </button>
      <button
        v-else-if="canCreateEvolution"
        class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
        @click="navigateToNewEvolution"
      >
        {{ t('WHATSAPP_CONNECTIONS.ACTIONS.NEW_UNOFFICIAL') }}
      </button>
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags.isFetching"
      class="text-center py-8 text-n-slate-11"
    >
      {{ t('WHATSAPP_CONNECTIONS.LOADING') }}
    </div>

    <!-- Empty State -->
    <div
      v-else-if="currentConnections.length === 0"
      class="text-center py-12 bg-n-background rounded-lg border border-n-weak"
    >
      <p class="text-n-slate-11 text-lg">
        {{
          activeTab === 'meta_cloud'
            ? t('WHATSAPP_CONNECTIONS.EMPTY_STATE.NO_CONNECTIONS_OFFICIAL')
            : t('WHATSAPP_CONNECTIONS.EMPTY_STATE.NO_CONNECTIONS_UNOFFICIAL')
        }}
      </p>
      <p class="text-n-slate-9 mt-2">
        {{ t('WHATSAPP_CONNECTIONS.EMPTY_STATE.ADD_FIRST') }}
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
          <div class="flex flex-col">
            <span class="font-semibold text-n-slate-12">
              {{ connection.name }}
            </span>
            <span class="text-sm text-n-slate-9">
              {{ connection.phone_numbers_count }}
              {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.STATS.NUMBERS') }}
              &middot; {{ connection.linked_count }}
              {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.STATS.LINKED') }}
              &middot; {{ connection.available_count }}
              {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.STATS.AVAILABLE') }}
            </span>
          </div>
          <div class="flex items-center gap-3">
            <span
              class="px-2 py-1 text-xs font-medium rounded-full"
              :class="statusBadgeClass(connection.status)"
            >
              {{ t(`WHATSAPP_CONNECTIONS.STATUS.${connection.status.toUpperCase()}`) }}
            </span>
            <button
              class="text-n-slate-9 hover:text-red-600 text-sm"
              @click.stop="openDeleteModal(connection)"
            >
              {{ t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Confirmation Modal (simple, no name typing) -->
    <woot-delete-modal
      v-model:show="showDeleteModal"
      :on-close="() => { showDeleteModal = false; selectedConnection = null; }"
      :on-confirm="confirmDelete"
      :title="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :message="t('WHATSAPP_CONNECTIONS.CONFIRM.DELETE_CONNECTION')"
      :confirm-text="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :reject-text="t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL')"
    />
  </div>
</template>
