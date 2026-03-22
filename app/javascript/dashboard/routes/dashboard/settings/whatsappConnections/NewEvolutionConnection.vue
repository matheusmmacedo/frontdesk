<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import SettingsLayout from '../SettingsLayout.vue';

const store = useStore();
const router = useRouter();
const connectionName = ref('Evolution API');
const isCreating = ref(false);
const error = ref('');

async function createConnection() {
  error.value = '';
  isCreating.value = true;

  try {
    const connection = await store.dispatch(
      'whatsappConnections/createEvolutionConnection',
      { name: connectionName.value }
    );

    router.push({
      name: 'whatsapp_connections_detail',
      params: { connectionId: connection.id },
    });
  } catch (err) {
    error.value =
      err?.response?.data?.error ||
      err.message ||
      'Failed to create connection. Make sure Evolution API is configured in Super Admin.';
  } finally {
    isCreating.value = false;
  }
}
</script>

<template>
  <SettingsLayout>
    <template #header>
      <div class="flex items-center gap-3">
        <router-link
          :to="{ name: 'whatsapp_connections_index' }"
          class="text-n-slate-9 hover:text-n-slate-12"
        >
          &larr; Back
        </router-link>
        <h1 class="text-2xl font-semibold text-n-slate-12">
          New Evolution API Connection
        </h1>
      </div>
    </template>

    <template #body>
      <div class="max-w-lg mx-auto flex flex-col gap-6">
        <div class="p-6 bg-white rounded-lg border border-n-weak">
          <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
            Connect to Evolution API
          </h2>
          <p class="text-sm text-n-slate-9 mb-6">
            The Evolution API is configured globally by the Super Admin. This
            will create a connection for your account and import your existing
            instances.
          </p>

          <div class="flex flex-col gap-4">
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-11">
                Connection Name
              </span>
              <input
                v-model="connectionName"
                type="text"
                placeholder="e.g., Evolution API"
                class="px-3 py-2 border border-n-weak rounded-lg text-sm"
              />
            </label>

            <button
              class="px-6 py-3 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
              :disabled="isCreating || !connectionName"
              @click="createConnection"
            >
              {{ isCreating ? 'Creating...' : 'Create Connection' }}
            </button>

            <div v-if="error" class="text-sm text-red-600 bg-red-50 p-3 rounded">
              {{ error }}
            </div>
          </div>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
