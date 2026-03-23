<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from '../inbox/channels/whatsapp/utils';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const isConnecting = ref(false);
const connectionName = ref('');

async function startEmbeddedSignup() {
  isConnecting.value = true;

  try {
    const chatwootConfig = window.chatwootConfig || {};
    const appId = chatwootConfig.whatsappAppId;
    const configId = chatwootConfig.whatsappConfigurationId;
    const apiVersion = chatwootConfig.whatsappApiVersion || 'v22.0';

    if (!appId || !configId) {
      useAlert(t('WHATSAPP_CONNECTIONS.NEW_META.ERROR_NO_CONFIG'));
      isConnecting.value = false;
      return;
    }

    await setupFacebookSdk(appId, apiVersion);

    const cleanup = createMessageHandler(async data => {
      if (!isValidBusinessData(data)) return;

      try {
        const connection = await store.dispatch(
          'whatsappConnections/createMetaConnection',
          {
            code: data.code,
            waba_id: data.waba_id,
            business_id: data.business_id,
            name: connectionName.value || `WABA ${data.waba_id}`,
          }
        );

        cleanup();
        router.push({
          name: 'whatsapp_connections_detail',
          params: { connectionId: connection.id },
        });
      } catch (err) {
        useAlert(err.message || t('WHATSAPP_CONNECTIONS.NEW_META.ERROR_NO_CONFIG'));
      } finally {
        isConnecting.value = false;
      }
    });

    initWhatsAppEmbeddedSignup(configId);
  } catch (err) {
    useAlert(err.message || t('WHATSAPP_CONNECTIONS.NEW_META.ERROR_NO_CONFIG'));
    isConnecting.value = false;
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
        {{ t('WHATSAPP_CONNECTIONS.NEW_META.TITLE') }}
      </h1>
    </div>

    <div class="max-w-lg flex flex-col gap-6">
      <div class="p-6 bg-white rounded-lg border border-n-weak">
        <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
          {{ t('WHATSAPP_CONNECTIONS.NEW_META.HEADING') }}
        </h2>
        <p class="text-sm text-n-slate-9 mb-6">
          {{ t('WHATSAPP_CONNECTIONS.NEW_META.DESCRIPTION') }}
        </p>

        <div class="flex flex-col gap-4">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              {{ t('WHATSAPP_CONNECTIONS.NEW_META.CONNECTION_NAME') }}
            </span>
            <input
              v-model="connectionName"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.NEW_META.CONNECTION_NAME_PLACEHOLDER')"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>

          <button
            class="px-6 py-3 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50"
            :disabled="isConnecting"
            @click="startEmbeddedSignup"
          >
            {{
              isConnecting
                ? t('WHATSAPP_CONNECTIONS.NEW_META.CONNECTING')
                : t('WHATSAPP_CONNECTIONS.ACTIONS.CONNECT_FACEBOOK')
            }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
