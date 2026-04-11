<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TemplateEditor from './TemplateEditor.vue';
import EvolutionTemplateEditor from './EvolutionTemplateEditor.vue';
import TemplatePreview from './TemplatePreview.vue';

const props = defineProps({
  connectionId: { type: Number, required: true },
  templates: { type: Array, default: () => [] },
  provider: { type: String, default: 'meta_cloud' },
});

const isEvolution = computed(() => props.provider === 'evolution');
const isMeta = computed(() => props.provider === 'meta_cloud');

const { t } = useI18n();
const store = useStore();
const isSyncing = ref(false);
const searchQuery = ref('');
const showCreateModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const showPreviewModal = ref(false);
const selectedTemplate = ref(null);
const selectedTemplateName = ref('');
const isSubmitting = ref(false);
const expandedTemplateId = ref(null);

const filteredTemplates = computed(() => {
  if (!searchQuery.value) return props.templates;
  const q = searchQuery.value.toLowerCase();
  return props.templates.filter(
    tmpl =>
      tmpl.name?.toLowerCase().includes(q) ||
      tmpl.language?.toLowerCase().includes(q) ||
      tmpl.category?.toLowerCase().includes(q)
  );
});

async function syncTemplates() {
  isSyncing.value = true;
  try {
    await store.dispatch(
      'whatsappConnections/syncTemplates',
      props.connectionId
    );
    useAlert(t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.SYNC_SUCCESS'));
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isSyncing.value = false;
  }
}

function openCreateModal() {
  selectedTemplate.value = null;
  showCreateModal.value = true;
}

function openEditModal(template) {
  selectedTemplate.value = template;
  showEditModal.value = true;
}

function openPreviewModal(template) {
  selectedTemplate.value = template;
  showPreviewModal.value = true;
}

function openDeleteModal(templateName) {
  selectedTemplateName.value = templateName;
  showDeleteModal.value = true;
}

function toggleExpand(templateId) {
  expandedTemplateId.value =
    expandedTemplateId.value === templateId ? null : templateId;
}

async function handleCreate(payload) {
  isSubmitting.value = true;
  try {
    await store.dispatch('whatsappConnections/createTemplate', {
      connectionId: props.connectionId,
      params: payload,
    });
    showCreateModal.value = false;
    await store.dispatch(
      'whatsappConnections/fetchTemplates',
      props.connectionId
    );
    useAlert(t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.CREATE_SUCCESS'));
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isSubmitting.value = false;
  }
}

async function handleEdit(payload) {
  if (!selectedTemplate.value) return;
  isSubmitting.value = true;
  try {
    await store.dispatch('whatsappConnections/updateTemplate', {
      connectionId: props.connectionId,
      templateId: selectedTemplate.value.id,
      params: payload,
    });
    showEditModal.value = false;
    await store.dispatch(
      'whatsappConnections/fetchTemplates',
      props.connectionId
    );
    useAlert(t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.EDIT_SUCCESS'));
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isSubmitting.value = false;
  }
}

async function confirmDeleteTemplate() {
  try {
    await store.dispatch('whatsappConnections/deleteTemplate', {
      connectionId: props.connectionId,
      templateName: selectedTemplateName.value,
    });
    useAlert(t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.DELETE_SUCCESS'));
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    showDeleteModal.value = false;
    selectedTemplateName.value = '';
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
  // Evolution: body is a top-level field; Meta: nested in components
  if (template.provider === 'evolution' || template.body) return template.body || '';
  const body = template.components?.find(c => c.type === 'BODY');
  return body?.text || '';
}

function hasButtons(template) {
  if (template.provider === 'evolution') return template.buttons?.length > 0;
  const btns = template.components?.find(c => c.type === 'BUTTONS');
  return btns?.buttons?.length > 0;
}

function hasHeader(template) {
  if (template.provider === 'evolution') return !!template.header;
  return !!template.components?.find(c => c.type === 'HEADER');
}

function hasMedia(template) {
  return template.provider === 'evolution' && !!template.media_url;
}

function componentCount(template) {
  return template.components?.length || 0;
}

function templateDeleteId(template) {
  // Evolution uses id (UUID), Meta uses name
  return template.provider === 'evolution' ? template.id : template.name;
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
          v-if="isMeta"
          class="px-3 py-1.5 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-brand hover:text-white transition-colors"
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
          @click="openCreateModal"
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
        class="bg-white rounded-lg border border-n-weak"
      >
        <!-- Template Header Row -->
        <div
          class="p-4 cursor-pointer hover:bg-n-alpha-1 transition-colors"
          @click="toggleExpand(tmpl.id || tmpl.name)"
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
                <span
                  v-if="hasHeader(tmpl)"
                  class="text-xs text-n-slate-9 bg-blue-50 px-1.5 py-0.5 rounded"
                >
                  Header
                </span>
                <span
                  v-if="hasButtons(tmpl)"
                  class="text-xs text-n-slate-9 bg-purple-50 px-1.5 py-0.5 rounded"
                >
                  Buttons
                </span>
                <span
                  v-if="hasMedia(tmpl)"
                  class="text-xs text-n-slate-9 bg-green-50 px-1.5 py-0.5 rounded"
                >
                  Media
                </span>
                <span
                  v-if="isEvolution"
                  class="text-xs text-orange-600 bg-orange-50 px-1.5 py-0.5 rounded"
                >
                  Local
                </span>
              </div>
              <p class="text-sm text-n-slate-11 line-clamp-2">
                {{ extractBodyText(tmpl) }}
              </p>
            </div>
            <div class="flex items-center gap-2 ml-4">
              <button
                class="text-xs text-n-brand hover:text-n-brand-dark"
                @click.stop="openPreviewModal(tmpl)"
              >
                {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.PREVIEW') }}
              </button>
              <button
                v-if="tmpl.status === 'APPROVED' || isEvolution"
                class="text-xs text-n-slate-9 hover:text-n-slate-12"
                @click.stop="openEditModal(tmpl)"
              >
                {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.EDIT') }}
              </button>
              <button
                class="text-xs text-red-600 hover:text-red-800"
                @click.stop="openDeleteModal(templateDeleteId(tmpl))"
              >
                {{ t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE') }}
              </button>
            </div>
          </div>
        </div>

        <!-- Expanded: Inline Preview -->
        <div
          v-if="expandedTemplateId === (tmpl.id || tmpl.name)"
          class="border-t border-n-weak p-4"
        >
          <TemplatePreview :template="tmpl" />
        </div>
      </div>
    </div>

    <!-- Create Modal -->
    <woot-modal
      v-if="showCreateModal"
      :show="showCreateModal"
      :on-close="() => (showCreateModal = false)"
    >
      <div class="p-6 max-w-4xl">
        <h3 class="text-lg font-semibold mb-4">
          {{ isEvolution ? 'Criar Mensagem Salva' : t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.CREATE_TITLE') }}
        </h3>
        <EvolutionTemplateEditor
          v-if="isEvolution"
          @save="handleCreate"
          @cancel="showCreateModal = false"
        />
        <TemplateEditor
          v-else
          :connection-id="props.connectionId"
          @save="handleCreate"
          @cancel="showCreateModal = false"
        />
      </div>
    </woot-modal>

    <!-- Edit Modal -->
    <woot-modal
      v-if="showEditModal"
      :show="showEditModal"
      :on-close="() => (showEditModal = false)"
    >
      <div class="p-6 max-w-4xl">
        <h3 class="text-lg font-semibold mb-4">
          {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.EDIT_TITLE') }}
          <span class="text-n-slate-9 font-normal">
            — {{ selectedTemplate?.name }}
          </span>
        </h3>
        <EvolutionTemplateEditor
          v-if="isEvolution"
          :initial-template="selectedTemplate"
          :is-edit-mode="true"
          @save="handleEdit"
          @cancel="showEditModal = false"
        />
        <TemplateEditor
          v-else
          :initial-template="selectedTemplate"
          :is-edit-mode="true"
          :connection-id="props.connectionId"
          @save="handleEdit"
          @cancel="showEditModal = false"
        />
      </div>
    </woot-modal>

    <!-- Preview Modal -->
    <woot-modal
      v-if="showPreviewModal"
      :show="showPreviewModal"
      :on-close="() => (showPreviewModal = false)"
    >
      <div class="p-6">
        <h3 class="text-lg font-semibold mb-4">
          {{ selectedTemplate?.name }}
          <span
            class="px-2 py-0.5 text-xs rounded-full ml-2"
            :class="statusBadge(selectedTemplate?.status)"
          >
            {{ selectedTemplate?.status }}
          </span>
        </h3>
        <TemplatePreview :template="selectedTemplate" />
      </div>
    </woot-modal>

    <!-- Delete Confirmation -->
    <woot-delete-modal
      v-model:show="showDeleteModal"
      :on-close="() => { showDeleteModal = false; selectedTemplateName = ''; }"
      :on-confirm="confirmDeleteTemplate"
      :title="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :message="t('WHATSAPP_CONNECTIONS.CONFIRM.DELETE_TEMPLATE', { name: selectedTemplateName })"
      :confirm-text="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :reject-text="t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL')"
    />
  </div>
</template>
