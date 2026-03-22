<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  connectionId: { type: Number, required: true },
  phoneNumbers: { type: Array, default: () => [] },
});

const { t } = useI18n();
const store = useStore();
const newInstanceName = ref('');
const isCreating = ref(false);
const qrCodeData = ref(null);
const qrCodePhoneId = ref(null);
const loading = ref({});
const showDeleteModal = ref(false);
const selectedInstance = ref(null);

async function createInstance() {
  if (!newInstanceName.value) return;
  isCreating.value = true;
  try {
    const { data } = await store.dispatch(
      'whatsappConnections/createInstance',
      {
        connectionId: props.connectionId,
        displayName: newInstanceName.value,
      }
    );
    newInstanceName.value = '';
    await store.dispatch(
      'whatsappConnections/fetchPhoneNumbers',
      props.connectionId
    );

    if (data?.phone_number?.id) {
      await showQRCode(data.phone_number.id);
    }
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    isCreating.value = false;
  }
}

async function showQRCode(phoneNumberId) {
  qrCodePhoneId.value = phoneNumberId;
  try {
    const data = await store.dispatch('whatsappConnections/getQRCode', {
      connectionId: props.connectionId,
      instanceId: phoneNumberId,
    });
    qrCodeData.value = data.qrcode || data.pairingCode;
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
    qrCodeData.value = null;
  }
}

async function checkStatus(phoneNumberId) {
  loading.value[phoneNumberId] = 'checking';
  try {
    await store.dispatch('whatsappConnections/checkInstanceStatus', {
      connectionId: props.connectionId,
      instanceId: phoneNumberId,
    });
    await store.dispatch(
      'whatsappConnections/fetchPhoneNumbers',
      props.connectionId
    );
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    delete loading.value[phoneNumberId];
  }
}

function openDeleteModal(pn) {
  selectedInstance.value = pn;
  showDeleteModal.value = true;
}

async function confirmDelete() {
  if (!selectedInstance.value) return;
  loading.value[selectedInstance.value.id] = 'deleting';
  try {
    await store.dispatch('whatsappConnections/deleteInstance', {
      connectionId: props.connectionId,
      instanceId: selectedInstance.value.id,
    });
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    delete loading.value[selectedInstance.value.id];
    showDeleteModal.value = false;
    selectedInstance.value = null;
  }
}

function connectionStatusColor(status) {
  const colors = {
    open: 'text-green-600',
    close: 'text-red-600',
    connecting: 'text-yellow-600',
    created: 'text-blue-600',
  };
  return colors[status] || 'text-gray-600';
}

function closeQRModal() {
  qrCodeData.value = null;
  qrCodePhoneId.value = null;
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.INSTANCES.TITLE') }}
      </h3>
    </div>

    <!-- Create new instance -->
    <div class="flex gap-2">
      <input
        v-model="newInstanceName"
        type="text"
        :placeholder="t('WHATSAPP_CONNECTIONS.INSTANCES.NAME_PLACEHOLDER')"
        class="flex-1 px-3 py-2 border border-n-weak rounded-lg text-sm"
      />
      <button
        class="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
        :disabled="isCreating || !newInstanceName"
        @click="createInstance"
      >
        {{
          isCreating
            ? t('WHATSAPP_CONNECTIONS.INSTANCES.CREATING')
            : t('WHATSAPP_CONNECTIONS.ACTIONS.CREATE_INSTANCE')
        }}
      </button>
    </div>

    <!-- Instances list -->
    <div
      v-if="phoneNumbers.length === 0"
      class="text-center py-8 text-n-slate-9"
    >
      {{ t('WHATSAPP_CONNECTIONS.EMPTY_STATE.NO_INSTANCES') }}
    </div>

    <div v-else class="flex flex-col gap-2">
      <div
        v-for="pn in phoneNumbers"
        :key="pn.id"
        class="p-4 bg-white rounded-lg border border-n-weak"
      >
        <div class="flex items-center justify-between">
          <div>
            <div class="flex items-center gap-2">
              <span class="font-semibold text-n-slate-12">
                {{ pn.display_name }}
              </span>
              <span
                class="text-xs font-medium capitalize"
                :class="
                  connectionStatusColor(
                    pn.provider_info?.connection_status
                  )
                "
              >
                {{ pn.provider_info?.connection_status || 'unknown' }}
              </span>
            </div>
            <div class="text-sm text-n-slate-9 mt-1">
              <span class="font-mono">{{ pn.phone_number }}</span>
              <span v-if="pn.inbox_name" class="ml-2">
                &rarr; {{ pn.inbox_name }}
              </span>
            </div>
          </div>

          <div class="flex gap-2">
            <button
              v-if="pn.provider_info?.connection_status !== 'open'"
              class="px-3 py-1 text-xs font-medium text-blue-600 border border-blue-300 rounded hover:bg-blue-50"
              @click="showQRCode(pn.id)"
            >
              {{ t('WHATSAPP_CONNECTIONS.ACTIONS.QR_CODE') }}
            </button>
            <button
              class="px-3 py-1 text-xs font-medium text-n-slate-9 border border-n-weak rounded hover:bg-n-alpha-1"
              :disabled="loading[pn.id] === 'checking'"
              @click="checkStatus(pn.id)"
            >
              {{
                loading[pn.id] === 'checking'
                  ? t('WHATSAPP_CONNECTIONS.INSTANCES.CHECKING')
                  : t('WHATSAPP_CONNECTIONS.ACTIONS.CHECK_STATUS')
              }}
            </button>
            <button
              class="px-3 py-1 text-xs font-medium text-red-600 border border-red-300 rounded hover:bg-red-50"
              :disabled="loading[pn.id] === 'deleting'"
              @click="openDeleteModal(pn)"
            >
              {{
                loading[pn.id] === 'deleting'
                  ? t('WHATSAPP_CONNECTIONS.INSTANCES.DELETING')
                  : t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')
              }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- QR Code Modal -->
    <woot-modal
      v-if="qrCodeData"
      :show="!!qrCodeData"
      :on-close="closeQRModal"
    >
      <div class="p-6 text-center">
        <h3 class="text-lg font-semibold mb-4">
          {{ t('WHATSAPP_CONNECTIONS.INSTANCES.QR_MODAL.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-9 mb-4">
          {{ t('WHATSAPP_CONNECTIONS.INSTANCES.QR_MODAL.DESCRIPTION') }}
        </p>
        <div class="flex justify-center mb-4">
          <img
            v-if="qrCodeData.startsWith && qrCodeData.startsWith('data:')"
            :src="qrCodeData"
            alt="QR Code"
            class="w-64 h-64"
          />
          <div
            v-else
            class="p-4 bg-gray-100 rounded text-xs font-mono break-all"
          >
            {{ qrCodeData }}
          </div>
        </div>
        <button
          class="px-4 py-2 text-sm border border-n-weak rounded-lg"
          @click="closeQRModal"
        >
          {{ t('WHATSAPP_CONNECTIONS.ACTIONS.CLOSE') }}
        </button>
      </div>
    </woot-modal>

    <!-- Delete Confirmation Modal -->
    <woot-delete-modal
      v-model:show="showDeleteModal"
      :on-close="() => { showDeleteModal = false; selectedInstance = null; }"
      :on-confirm="confirmDelete"
      :title="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :message="t('WHATSAPP_CONNECTIONS.CONFIRM.DELETE_INSTANCE')"
      :confirm-text="t('WHATSAPP_CONNECTIONS.ACTIONS.DELETE')"
      :reject-text="t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL')"
    />
  </div>
</template>
