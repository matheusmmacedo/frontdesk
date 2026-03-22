<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import SettingsLayout from '../SettingsLayout.vue';
import {
  setupFacebookSdk,
  initWhatsAppEmbeddedSignup,
  createMessageHandler,
  isValidBusinessData,
} from '../inbox/channels/whatsapp/utils';

const store = useStore();
const router = useRouter();
const isConnecting = ref(false);
const error = ref('');
const connectionName = ref('');

async function startEmbeddedSignup() {
  error.value = '';
  isConnecting.value = true;

  try {
    const chatwootConfig = window.chatwootConfig || {};
    const appId = chatwootConfig.whatsappAppId;
    const configId = chatwootConfig.whatsappConfigurationId;
    const apiVersion = chatwootConfig.whatsappApiVersion || 'v22.0';

    if (!appId || !configId) {
      error.value =
        'WhatsApp App ID or Configuration ID not set. Contact Super Admin.';
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
        error.value = err.message || 'Failed to create connection';
      } finally {
        isConnecting.value = false;
      }
    });

    initWhatsAppEmbeddedSignup(configId);
  } catch (err) {
    error.value = err.message || 'Failed to start Facebook login';
    isConnecting.value = false;
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
          Nova Conexão WhatsApp Oficial
        </h1>
      </div>
    </template>

    <template #body>
      <div class="max-w-lg mx-auto flex flex-col gap-6">
        <div class="p-6 bg-white rounded-lg border border-n-weak">
          <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
            Conectar sua Conta WhatsApp Business
          </h2>
          <p class="text-sm text-n-slate-9 mb-6">
            Click the button below to authenticate with Facebook and connect
            your WABA. All phone numbers from your WABA will be imported
            automatically.
          </p>

          <div class="flex flex-col gap-4">
            <label class="flex flex-col gap-1">
              <span class="text-sm font-medium text-n-slate-11">
                Connection Name (optional)
              </span>
              <input
                v-model="connectionName"
                type="text"
                placeholder="e.g., My Business WABA"
                class="px-3 py-2 border border-n-weak rounded-lg text-sm"
              />
            </label>

            <button
              class="px-6 py-3 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 disabled:opacity-50"
              :disabled="isConnecting"
              @click="startEmbeddedSignup"
            >
              {{ isConnecting ? 'Connecting...' : 'Connect with Facebook' }}
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
