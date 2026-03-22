<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  connectionId: { type: Number, required: true },
  phoneNumbers: { type: Array, default: () => [] },
});

const store = useStore();
const newInstanceName = ref('');
const isCreating = ref(false);
const qrCodeData = ref(null);
const qrCodePhoneId = ref(null);
const loading = ref({});

async function createInstance() {
  if (!newInstanceName.value) return;
  isCreating.value = true;
  try {
    const { data } = await store.dispatch('whatsappConnections/createInstance', {
      connectionId: props.connectionId,
      displayName: newInstanceName.value,
    });
    newInstanceName.value = '';
    await store.dispatch('whatsappConnections/fetchPhoneNumbers', props.connectionId);

    // Auto-show QR code for the new instance
    if (data?.phone_number?.id) {
      await showQRCode(data.phone_number.id);
    }
  } catch (err) {
    alert(err?.response?.data?.error || 'Failed to create instance');
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
    alert(err?.response?.data?.error || 'Failed to get QR code');
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
    await store.dispatch('whatsappConnections/fetchPhoneNumbers', props.connectionId);
  } catch (err) {
    alert(err?.response?.data?.error || 'Failed to check status');
  } finally {
    delete loading.value[phoneNumberId];
  }
}

async function deleteInstance(phoneNumberId) {
  if (!window.confirm('Delete this instance? This cannot be undone.')) return;
  loading.value[phoneNumberId] = 'deleting';
  try {
    await store.dispatch('whatsappConnections/deleteInstance', {
      connectionId: props.connectionId,
      instanceId: phoneNumberId,
    });
  } catch (err) {
    alert(err?.response?.data?.error || 'Failed to delete instance');
  } finally {
    delete loading.value[phoneNumberId];
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
      <h3 class="text-lg font-semibold text-n-slate-12">Evolution Instances</h3>
    </div>

    <!-- Create new instance -->
    <div class="flex gap-2">
      <input
        v-model="newInstanceName"
        type="text"
        placeholder="Instance name (e.g., Sales, Support)"
        class="flex-1 px-3 py-2 border border-n-weak rounded-lg text-sm"
      />
      <button
        class="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50"
        :disabled="isCreating || !newInstanceName"
        @click="createInstance"
      >
        {{ isCreating ? 'Creating...' : '+ Create Instance' }}
      </button>
    </div>

    <!-- Instances list -->
    <div v-if="phoneNumbers.length === 0" class="text-center py-8 text-n-slate-9">
      No instances yet. Create one above.
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
              <span class="font-semibold text-n-slate-12">{{ pn.display_name }}</span>
              <span
                class="text-xs font-medium capitalize"
                :class="connectionStatusColor(pn.provider_info?.connection_status)"
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
              QR Code
            </button>
            <button
              class="px-3 py-1 text-xs font-medium text-n-slate-9 border border-n-weak rounded hover:bg-n-alpha-1"
              :disabled="loading[pn.id] === 'checking'"
              @click="checkStatus(pn.id)"
            >
              {{ loading[pn.id] === 'checking' ? '...' : 'Check Status' }}
            </button>
            <button
              class="px-3 py-1 text-xs font-medium text-red-600 border border-red-300 rounded hover:bg-red-50"
              :disabled="loading[pn.id] === 'deleting'"
              @click="deleteInstance(pn.id)"
            >
              {{ loading[pn.id] === 'deleting' ? '...' : 'Delete' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- QR Code Modal -->
    <div
      v-if="qrCodeData"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="closeQRModal"
    >
      <div class="bg-white rounded-xl p-6 w-full max-w-sm shadow-xl text-center">
        <h3 class="text-lg font-semibold mb-4">Scan QR Code</h3>
        <p class="text-sm text-n-slate-9 mb-4">
          Open WhatsApp on your phone and scan this QR code.
        </p>
        <div class="flex justify-center mb-4">
          <img
            v-if="qrCodeData.startsWith('data:')"
            :src="qrCodeData"
            alt="QR Code"
            class="w-64 h-64"
          />
          <div v-else class="p-4 bg-gray-100 rounded text-xs font-mono break-all">
            {{ qrCodeData }}
          </div>
        </div>
        <button
          class="px-4 py-2 text-sm border border-n-weak rounded-lg"
          @click="closeQRModal"
        >
          Close
        </button>
      </div>
    </div>
  </div>
</template>
