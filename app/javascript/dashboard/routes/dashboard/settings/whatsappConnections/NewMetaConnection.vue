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
const activeMode = ref('embedded');

// Direct token fields
const accessToken = ref('');
const wabaId = ref('');
const businessId = ref('');
const directName = ref('');
const isDirectConnecting = ref(false);

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

async function connectDirectToken() {
  if (!accessToken.value || !wabaId.value) return;
  isDirectConnecting.value = true;

  try {
    const connection = await store.dispatch(
      'whatsappConnections/createMetaConnection',
      {
        access_token: accessToken.value,
        waba_id: wabaId.value,
        business_id: businessId.value || undefined,
        name: directName.value || `WABA ${wabaId.value}`,
      }
    );

    router.push({
      name: 'whatsapp_connections_detail',
      params: { connectionId: connection.id },
    });
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isDirectConnecting.value = false;
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

    <!-- Mode Tabs -->
    <div class="flex gap-2 border-b border-n-strong pb-0 max-w-lg">
      <button
        class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
        :class="
          activeMode === 'embedded'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
        "
        @click="activeMode = 'embedded'"
      >
        {{ t('WHATSAPP_CONNECTIONS.NEW_META.TAB_EMBEDDED') }}
      </button>
      <button
        class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
        :class="
          activeMode === 'direct'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-11 hover:text-n-slate-12'
        "
        @click="activeMode = 'direct'"
      >
        {{ t('WHATSAPP_CONNECTIONS.NEW_META.TAB_DIRECT') }}
      </button>
    </div>

    <!-- Embedded Signup Mode -->
    <div v-if="activeMode === 'embedded'" class="max-w-lg flex flex-col gap-6">
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

    <!-- Direct Token Mode -->
    <div v-if="activeMode === 'direct'" class="max-w-lg flex flex-col gap-6">
      <div class="p-6 bg-white rounded-lg border border-n-weak">
        <h2 class="text-lg font-semibold text-n-slate-12 mb-4">
          {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HEADING') }}
        </h2>
        <p class="text-sm text-n-slate-9 mb-6">
          {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_DESCRIPTION') }}
        </p>

        <div class="flex flex-col gap-4">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_NAME') }}
            </span>
            <input
              v-model="directName"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_NAME_PLACEHOLDER')"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            />
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              WABA ID <span class="text-red-500">*</span>
            </span>
            <input
              v-model="wabaId"
              type="text"
              placeholder="ex: 735467396201142"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm font-mono"
            />
            <span class="text-xs text-n-slate-9">
              {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_WABA_HINT') }}
            </span>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              Access Token <span class="text-red-500">*</span>
            </span>
            <textarea
              v-model="accessToken"
              placeholder="EAAxxxxxx..."
              class="px-3 py-2 border border-n-weak rounded-lg text-sm font-mono min-h-[80px] resize-y"
            />
            <span class="text-xs text-n-slate-9">
              {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_TOKEN_HINT') }}
            </span>
          </label>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-11">
              Business ID
              <span class="text-xs text-n-slate-9 font-normal ml-1">
                ({{ t('WHATSAPP_CONNECTIONS.NEW_META.OPTIONAL') }})
              </span>
            </span>
            <input
              v-model="businessId"
              type="text"
              placeholder="ex: 1670699556853947"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm font-mono"
            />
          </label>

          <button
            class="px-6 py-3 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
            :disabled="isDirectConnecting || !accessToken || !wabaId"
            @click="connectDirectToken"
          >
            {{
              isDirectConnecting
                ? t('WHATSAPP_CONNECTIONS.NEW_META.CONNECTING')
                : t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_CONNECT')
            }}
          </button>
        </div>
      </div>

      <!-- Help Card -->
      <div class="p-4 bg-blue-50 rounded-lg border border-blue-200">
        <h3 class="text-sm font-semibold text-blue-900 mb-2">
          {{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HELP_TITLE') }}
        </h3>
        <ol class="text-sm text-blue-800 list-decimal list-inside space-y-1">
          <li>{{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HELP_STEP1') }}</li>
          <li>{{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HELP_STEP2') }}</li>
          <li>{{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HELP_STEP3') }}</li>
          <li>{{ t('WHATSAPP_CONNECTIONS.NEW_META.DIRECT_HELP_STEP4') }}</li>
        </ol>
      </div>
    </div>
  </div>
</template>
