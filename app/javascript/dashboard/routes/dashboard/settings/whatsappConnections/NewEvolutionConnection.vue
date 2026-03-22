<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const connectionName = ref(t('WHATSAPP_CONNECTIONS.TABS.UNOFFICIAL'));
const isCreating = ref(false);

async function createConnection() {
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
    useAlert(
      err?.response?.data?.error ||
        err.message ||
        t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.ERROR_NO_CONFIG')
    );
  } finally {
    isCreating.value = false;
  }
}
</script>

<template>
  <div class="flex flex-col gap-6 w-full">
    <div class="flex items-center gap-3">
      <router-link
        :to="{ name: 'whatsapp_connections_index' }"
        class="text-n-slate-9 hover:text-n-slate-12"
      >
        {{ t('WHATSAPP_CONNECTIONS.DETAIL.BACK') }}
      </router-link>
      <h1 class="text-2xl font-semibold text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.TITLE') }}
      </h1>
    </div>

    <div class="max-w-lg flex flex-col gap-6">
      <div class="p-6 bg-white rounded-lg border border-n-weak">
        <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
          {{ t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.HEADING') }}
        </h2>
        <p class="text-sm text-n-slate-9 mb-6">
          {{ t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.DESCRIPTION') }}
        </p>

        <div class="flex flex-col gap-4">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              {{ t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.CONNECTION_NAME') }}
            </span>
            <input
              v-model="connectionName"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.CONNECTION_NAME_PLACEHOLDER')"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>

          <button
            class="px-6 py-3 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
            :disabled="isCreating || !connectionName"
            @click="createConnection"
          >
            {{
              isCreating
                ? t('WHATSAPP_CONNECTIONS.NEW_EVOLUTION.CREATING')
                : t('WHATSAPP_CONNECTIONS.ACTIONS.CREATE_CONNECTION')
            }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
