<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  connectionId: { type: Number, required: true },
  phoneNumbers: { type: Array, default: () => [] },
  provider: { type: String, required: true },
});

const emit = defineEmits(['sync']);
const { t } = useI18n();
const store = useStore();
const loading = ref({});
const showUnlinkModal = ref(false);
const selectedNumber = ref(null);

async function linkNumber(phoneNumberId) {
  loading.value[phoneNumberId] = 'linking';
  try {
    await store.dispatch('whatsappConnections/linkPhoneNumber', {
      connectionId: props.connectionId,
      phoneNumberId,
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

function openUnlinkModal(pn) {
  selectedNumber.value = pn;
  showUnlinkModal.value = true;
}

async function confirmUnlink() {
  if (!selectedNumber.value) return;
  loading.value[selectedNumber.value.id] = 'unlinking';
  try {
    await store.dispatch('whatsappConnections/unlinkPhoneNumber', {
      connectionId: props.connectionId,
      phoneNumberId: selectedNumber.value.id,
    });
    await store.dispatch(
      'whatsappConnections/fetchPhoneNumbers',
      props.connectionId
    );
  } catch (err) {
    useAlert(err?.response?.data?.error || err.message);
  } finally {
    delete loading.value[selectedNumber.value.id];
    showUnlinkModal.value = false;
    selectedNumber.value = null;
  }
}

function statusColor(status) {
  const colors = {
    available: 'text-green-600',
    linked: 'text-blue-600',
    error: 'text-red-600',
    pending: 'text-yellow-600',
  };
  return colors[status] || 'text-gray-600';
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center justify-between">
      <h3 class="text-lg font-semibold text-n-slate-12">
        {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TITLE') }}
      </h3>
      <button
        class="px-3 py-1.5 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-brand hover:text-white transition-colors"
        @click="emit('sync')"
      >
        {{ t('WHATSAPP_CONNECTIONS.ACTIONS.SYNC_NUMBERS') }}
      </button>
    </div>

    <div
      v-if="phoneNumbers.length === 0"
      class="text-center py-8 text-n-slate-9"
    >
      {{ t('WHATSAPP_CONNECTIONS.EMPTY_STATE.NO_PHONE_NUMBERS') }}
    </div>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="border-b border-n-weak text-left text-n-slate-11">
          <th class="py-2 px-3">
            {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TABLE.PHONE') }}
          </th>
          <th class="py-2 px-3">
            {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TABLE.NAME') }}
          </th>
          <th class="py-2 px-3">
            {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TABLE.STATUS') }}
          </th>
          <th class="py-2 px-3">
            {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TABLE.INBOX') }}
          </th>
          <th class="py-2 px-3 text-right">
            {{ t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.TABLE.ACTIONS') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="pn in phoneNumbers"
          :key="pn.id"
          class="border-b border-n-weak hover:bg-n-alpha-1"
        >
          <td class="py-3 px-3 font-mono">{{ pn.phone_number }}</td>
          <td class="py-3 px-3">{{ pn.display_name }}</td>
          <td class="py-3 px-3">
            <span
              :class="statusColor(pn.status)"
              class="font-medium capitalize"
            >
              {{ t(`WHATSAPP_CONNECTIONS.STATUS.${pn.status.toUpperCase()}`) }}
            </span>
          </td>
          <td class="py-3 px-3">
            <span v-if="pn.inbox_name" class="text-n-slate-12">
              {{ pn.inbox_name }}
            </span>
            <span v-else class="text-n-slate-9">&mdash;</span>
          </td>
          <td class="py-3 px-3 text-right">
            <button
              v-if="pn.status === 'available'"
              class="px-3 py-1 text-xs font-medium text-white bg-green-600 rounded hover:bg-green-700 disabled:opacity-50"
              :disabled="loading[pn.id]"
              @click="linkNumber(pn.id)"
            >
              {{
                loading[pn.id] === 'linking'
                  ? t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.LINKING')
                  : t('WHATSAPP_CONNECTIONS.ACTIONS.LINK')
              }}
            </button>
            <button
              v-else-if="pn.status === 'linked'"
              class="px-3 py-1 text-xs font-medium text-red-600 border border-red-300 rounded hover:bg-red-50 disabled:opacity-50"
              :disabled="loading[pn.id]"
              @click="openUnlinkModal(pn)"
            >
              {{
                loading[pn.id] === 'unlinking'
                  ? t('WHATSAPP_CONNECTIONS.PHONE_NUMBERS.UNLINKING')
                  : t('WHATSAPP_CONNECTIONS.ACTIONS.UNLINK')
              }}
            </button>
            <span
              v-else-if="pn.status === 'pending'"
              class="text-xs text-yellow-600"
            >
              {{ t('WHATSAPP_CONNECTIONS.STATUS.AWAITING_CONNECTION') }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Unlink Confirmation Modal -->
    <woot-confirm-delete-modal
      v-if="showUnlinkModal"
      v-model:show="showUnlinkModal"
      :title="t('WHATSAPP_CONNECTIONS.ACTIONS.UNLINK')"
      :message="t('WHATSAPP_CONNECTIONS.CONFIRM.UNLINK_NUMBER')"
      :confirm-text="t('WHATSAPP_CONNECTIONS.ACTIONS.UNLINK')"
      :reject-text="t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL')"
      :confirm-value="selectedNumber?.phone_number"
      :confirm-place-holder-text="selectedNumber?.phone_number"
      @on-confirm="confirmUnlink"
      @on-close="showUnlinkModal = false"
    />
  </div>
</template>
