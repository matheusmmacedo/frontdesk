<script setup>
import { ref } from 'vue';
import { useStore } from 'vuex';

const props = defineProps({
  connectionId: { type: Number, required: true },
  phoneNumbers: { type: Array, default: () => [] },
  provider: { type: String, required: true },
});

const emit = defineEmits(['sync']);
const store = useStore();
const loading = ref({});

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
    alert(err?.response?.data?.error || err.message);
  } finally {
    delete loading.value[phoneNumberId];
  }
}

async function unlinkNumber(phoneNumberId) {
  if (!window.confirm('Unlink this number? The inbox will be deleted.')) return;
  loading.value[phoneNumberId] = 'unlinking';
  try {
    await store.dispatch('whatsappConnections/unlinkPhoneNumber', {
      connectionId: props.connectionId,
      phoneNumberId,
    });
    await store.dispatch(
      'whatsappConnections/fetchPhoneNumbers',
      props.connectionId
    );
  } catch (err) {
    alert(err?.response?.data?.error || err.message);
  } finally {
    delete loading.value[phoneNumberId];
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
      <h3 class="text-lg font-semibold text-n-slate-12">Phone Numbers</h3>
      <button
        class="px-3 py-1.5 text-sm font-medium text-n-brand border border-n-brand rounded-lg hover:bg-n-brand hover:text-white transition-colors"
        @click="emit('sync')"
      >
        Sync Numbers
      </button>
    </div>

    <div v-if="phoneNumbers.length === 0" class="text-center py-8 text-n-slate-9">
      No phone numbers found. Click "Sync Numbers" to refresh.
    </div>

    <table v-else class="w-full text-sm">
      <thead>
        <tr class="border-b border-n-weak text-left text-n-slate-11">
          <th class="py-2 px-3">Phone</th>
          <th class="py-2 px-3">Name</th>
          <th class="py-2 px-3">Status</th>
          <th class="py-2 px-3">Inbox</th>
          <th class="py-2 px-3 text-right">Actions</th>
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
            <span :class="statusColor(pn.status)" class="font-medium capitalize">
              {{ pn.status }}
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
              {{ loading[pn.id] === 'linking' ? 'Linking...' : 'Link' }}
            </button>
            <button
              v-else-if="pn.status === 'linked'"
              class="px-3 py-1 text-xs font-medium text-red-600 border border-red-300 rounded hover:bg-red-50 disabled:opacity-50"
              :disabled="loading[pn.id]"
              @click="unlinkNumber(pn.id)"
            >
              {{ loading[pn.id] === 'unlinking' ? 'Unlinking...' : 'Unlink' }}
            </button>
            <span v-else-if="pn.status === 'pending'" class="text-xs text-yellow-600">
              Awaiting connection
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
