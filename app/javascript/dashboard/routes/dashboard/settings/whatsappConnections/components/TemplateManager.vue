<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  connectionId: { type: Number, required: true },
  templates: { type: Array, default: () => [] },
});

const { t } = useI18n();
const store = useStore();
const isSyncing = ref(false);
const searchQuery = ref('');
const showCreateModal = ref(false);
const showDeleteModal = ref(false);
const selectedTemplateName = ref('');
const newTemplate = ref({
  name: '',
  language: 'pt_BR',
  category: 'MARKETING',
  components: [],
});
const isCreating = ref(false);

const filteredTemplates = computed(() => {
  if (!searchQuery.value) return props.templates;
  const q = searchQuery.value.toLowerCase();
  return props.templates.filter(
    tmpl =>
      tmpl.name?.toLowerCase().includes(q) ||
      tmpl.language?.toLowerCase().includes(q)
  );
});

async function syncTemplates() {
  isSyncing.value = true;
  try {
    await store.dispatch(
      'whatsappConnections/syncTemplates',
      props.connectionId
    );
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isSyncing.value = false;
  }
}

function openDeleteModal(templateName) {
  selectedTemplateName.value = templateName;
  showDeleteModal.value = true;
}

async function confirmDeleteTemplate() {
  try {
    await store.dispatch('whatsappConnections/deleteTemplate', {
      connectionId: props.connectionId,
      templateName: selectedTemplateName.value,
    });
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    showDeleteModal.value = false;
    selectedTemplateName.value = '';
  }
}

async function createTemplate() {
  isCreating.value = true;
  try {
    await store.dispatch('whatsappConnections/createTemplate', {
      connectionId: props.connectionId,
      params: newTemplate.value,
    });
    showCreateModal.value = false;
    newTemplate.value = {
      name: '',
      language: 'pt_BR',
      category: 'MARKETING',
      components: [],
    };
    await store.dispatch(
      'whatsappConnections/fetchTemplates',
      props.connectionId
    );
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isCreating.value = false;
  }
}

function statusBadge(status) {
  const classes = {
    APPROVED: 'bg-green-100 text-green-800',
    PENDING: 'bg-yellow-100 text-yellow-800',
    REJECTED: 'bg-red-100 text-red-800',
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
}

function extractBodyText(template) {
  const body = template.components?.find(c => c.type === 'BODY');
  return body?.text || '';
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.TITLE') }}
      </h3>
      <div class="flex gap-2">
        <button
          class="px-3 py-1.5 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-brand hover:text-white"
          :disabled="isSyncing"
          @click="syncTemplates"
        >
          {{
            isSyncing
              ? t('WHATSAPP_CONNECTIONS.TEMPLATES.SYNCING')
              : t('WHATSAPP_CONNECTIONS.ACTIONS.SYNC_TEMPLATES')
          }}
        </button>
        <button
          class="px-3 py-1.5 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
          @click="showCreateModal = true"
        >
          {{ t('WHATSAPP_CONNECTIONS.ACTIONS.CREATE_TEMPLATE') }}
        </button>
      </div>
    </div>

    <!-- Search -->
    <input
      v-model="searchQuery"
      type="text"
      :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATES.SEARCH')"
      class="px-3 py-2 border border-n-weak rounded-lg text-sm w-full max-w-sm"
    />

    <!-- Templates List -->
    <div
      v-if="filteredTemplates.length === 0"
      class="text-center py-8 text-n-slate-9"
    >
      {{ t('WHATSAPP_CONNECTIONS.EMPTY_STATE.NO_TEMPLATES') }}
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="tmpl in filteredTemplates"
        :key="tmpl.id || tmpl.name"
        class="p-4 bg-white rounded-lg border border-n-weak"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <span class="font-semibold text-n-slate-12">
                {{ tmpl.name }}
              </span>
              <span
                class="px-2 py-0.5 text-xs rounded-full"
                :class="statusBadge(tmpl.status)"
              >
                {{ tmpl.status }}
              </span>
              <span class="text-xs text-n-slate-9">{{ tmpl.language }}</span>
              <span
                class="text-xs text-n-slate-9 bg-n-alpha-1 px-1.5 py-0.5 rounded"
              >
                {{ tmpl.category }}
              </span>
            </div>
            <p class="text-sm text-n-slate-11 line-clamp-2">
              {{ extractBodyText(tmpl) }}
            </p>
          </div>
          <button
            class="text-xs text-red-600 hover:text-red-800 ml-4"
            @click="openDeleteModal(tmpl.name)"
          >
            {{ t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE') }}
          </button>
        </div>
      </div>
    </div>

    <!-- Create Modal -->
    <woot-modal
      v-if="showCreateModal"
      :show="showCreateModal"
      :on-close="() => (showCreateModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-semibold mb-4">
          {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.TITLE') }}
        </h3>

        <div class="flex flex-col gap-3">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.NAME') }}
            </span>
            <input
              v-model="newTemplate.name"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.NAME_PLACEHOLDER')"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.LANGUAGE') }}
            </span>
            <input
              v-model="newTemplate.language"
              type="text"
              placeholder="pt_BR"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">
              {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.CATEGORY') }}
            </span>
            <select
              v-model="newTemplate.category"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            >
              <option value="MARKETING">
                {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.CATEGORIES.MARKETING') }}
              </option>
              <option value="UTILITY">
                {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.CATEGORIES.UTILITY') }}
              </option>
              <option value="AUTHENTICATION">
                {{ t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.CATEGORIES.AUTHENTICATION') }}
              </option>
            </select>
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <button
              class="px-4 py-2 text-sm border border-n-weak rounded-lg"
              @click="showCreateModal = false"
            >
              {{ t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL') }}
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg disabled:opacity-50"
              :disabled="isCreating || !newTemplate.name"
              @click="createTemplate"
            >
              {{
                isCreating
                  ? t('WHATSAPP_CONNECTIONS.TEMPLATES.CREATE_MODAL.CREATING')
                  : t('WHATSAPP_CONNECTIONS.ACTIONS.CREATE')
              }}
            </button>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Delete Confirmation -->
    <woot-confirm-delete-modal
      v-if="showDeleteModal"
      v-model:show="showDeleteModal"
      :title="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :message="t('WHATSAPP_CONNECTIONS.CONFIRM.DELETE_TEMPLATE', { name: selectedTemplateName })"
      :confirm-text="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :reject-text="t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL')"
      :confirm-value="selectedTemplateName"
      :confirm-place-holder-text="selectedTemplateName"
      @on-confirm="confirmDeleteTemplate"
      @on-close="showDeleteModal = false"
    />
  </div>
</template>
