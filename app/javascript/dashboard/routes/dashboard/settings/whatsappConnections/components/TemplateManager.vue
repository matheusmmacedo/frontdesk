<script setup>
import { ref, computed } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  connectionId: { type: Number, required: true },
  templates: { type: Array, default: () => [] },
});

const store = useStore();
const isSyncing = ref(false);
const searchQuery = ref('');
const showCreateModal = ref(false);
const newTemplate = ref({ name: '', language: 'en', category: 'MARKETING', components: [] });
const isCreating = ref(false);
const createError = ref('');

const filteredTemplates = computed(() => {
  if (!searchQuery.value) return props.templates;
  const q = searchQuery.value.toLowerCase();
  return props.templates.filter(
    t => t.name?.toLowerCase().includes(q) || t.language?.toLowerCase().includes(q)
  );
});

async function syncTemplates() {
  isSyncing.value = true;
  try {
    await store.dispatch('whatsappConnections/syncTemplates', props.connectionId);
  } catch (err) {
    alert(err?.response?.data?.error || 'Sync failed');
  } finally {
    isSyncing.value = false;
  }
}

async function deleteTemplate(templateName) {
  if (!window.confirm(`Delete template "${templateName}"?`)) return;
  try {
    await store.dispatch('whatsappConnections/deleteTemplate', {
      connectionId: props.connectionId,
      templateName,
    });
  } catch (err) {
    alert(err?.response?.data?.error || 'Delete failed');
  }
}

async function createTemplate() {
  createError.value = '';
  isCreating.value = true;
  try {
    await store.dispatch('whatsappConnections/createTemplate', {
      connectionId: props.connectionId,
      params: newTemplate.value,
    });
    showCreateModal.value = false;
    newTemplate.value = { name: '', language: 'en', category: 'MARKETING', components: [] };
    await store.dispatch('whatsappConnections/fetchTemplates', props.connectionId);
  } catch (err) {
    createError.value = err?.response?.data?.error || 'Create failed';
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
      <h3 class="text-lg font-semibold text-n-slate-12">Message Templates</h3>
      <div class="flex gap-2">
        <button
          class="px-3 py-1.5 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-brand hover:text-white"
          :disabled="isSyncing"
          @click="syncTemplates"
        >
          {{ isSyncing ? 'Syncing...' : 'Sync Templates' }}
        </button>
        <button
          class="px-3 py-1.5 text-sm font-medium text-white bg-n-brand rounded-lg hover:bg-n-brand-dark"
          @click="showCreateModal = true"
        >
          + Create Template
        </button>
      </div>
    </div>

    <!-- Search -->
    <input
      v-model="searchQuery"
      type="text"
      placeholder="Search templates..."
      class="px-3 py-2 border border-n-weak rounded-lg text-sm w-full max-w-sm"
    />

    <!-- Templates List -->
    <div v-if="filteredTemplates.length === 0" class="text-center py-8 text-n-slate-9">
      No templates found.
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="template in filteredTemplates"
        :key="template.id || template.name"
        class="p-4 bg-white rounded-lg border border-n-weak"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center gap-2 mb-1">
              <span class="font-semibold text-n-slate-12">{{ template.name }}</span>
              <span class="px-2 py-0.5 text-xs rounded-full" :class="statusBadge(template.status)">
                {{ template.status }}
              </span>
              <span class="text-xs text-n-slate-9">{{ template.language }}</span>
              <span class="text-xs text-n-slate-9 bg-n-alpha-1 px-1.5 py-0.5 rounded">
                {{ template.category }}
              </span>
            </div>
            <p class="text-sm text-n-slate-11 line-clamp-2">
              {{ extractBodyText(template) }}
            </p>
          </div>
          <button
            class="text-xs text-red-600 hover:text-red-800 ml-4"
            @click="deleteTemplate(template.name)"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Create Modal -->
    <div
      v-if="showCreateModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="showCreateModal = false"
    >
      <div class="bg-white rounded-xl p-6 w-full max-w-lg shadow-xl">
        <h3 class="text-lg font-semibold mb-4">Create Template</h3>

        <div class="flex flex-col gap-3">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Name</span>
            <input
              v-model="newTemplate.name"
              type="text"
              placeholder="e.g., order_confirmation"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Language</span>
            <input
              v-model="newTemplate.language"
              type="text"
              placeholder="en"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium">Category</span>
            <select
              v-model="newTemplate.category"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            >
              <option value="MARKETING">Marketing</option>
              <option value="UTILITY">Utility</option>
              <option value="AUTHENTICATION">Authentication</option>
            </select>
          </label>

          <div v-if="createError" class="text-sm text-red-600 bg-red-50 p-2 rounded">
            {{ createError }}
          </div>

          <div class="flex justify-end gap-2 mt-2">
            <button
              class="px-4 py-2 text-sm border border-n-weak rounded-lg"
              @click="showCreateModal = false"
            >
              Cancel
            </button>
            <button
              class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg disabled:opacity-50"
              :disabled="isCreating || !newTemplate.name"
              @click="createTemplate"
            >
              {{ isCreating ? 'Creating...' : 'Create' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
