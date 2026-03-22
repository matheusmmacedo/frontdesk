<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute } from 'vue-router';
import SettingsLayout from '../SettingsLayout.vue';
import PhoneNumberPool from './components/PhoneNumberPool.vue';
import TemplateManager from './components/TemplateManager.vue';
import EvolutionInstanceManager from './components/EvolutionInstanceManager.vue';

const store = useStore();
const route = useRoute();
const connectionId = computed(() => Number(route.params.connectionId));
const activeSection = ref('numbers');

onMounted(async () => {
  await store.dispatch('whatsappConnections/fetchConnections');
  await store.dispatch(
    'whatsappConnections/fetchPhoneNumbers',
    connectionId.value
  );
  if (connection.value?.provider === 'meta_cloud') {
    await store.dispatch(
      'whatsappConnections/fetchTemplates',
      connectionId.value
    );
  }
});

const connection = computed(() =>
  store.getters['whatsappConnections/getConnectionById'](connectionId.value)
);
const phoneNumbers = computed(() =>
  store.getters['whatsappConnections/getPhoneNumbers'](connectionId.value)
);
const templates = computed(() =>
  store.getters['whatsappConnections/getTemplates'](connectionId.value)
);

const isMetaCloud = computed(() => connection.value?.provider === 'meta_cloud');
const isEvolution = computed(() => connection.value?.provider === 'evolution');

async function syncNumbers() {
  await store.dispatch('whatsappConnections/syncNumbers', connectionId.value);
  await store.dispatch(
    'whatsappConnections/fetchPhoneNumbers',
    connectionId.value
  );
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
          {{ connection?.name || 'Connection' }}
        </h1>
        <span
          class="px-2 py-1 text-xs font-medium rounded-full"
          :class="{
            'bg-green-100 text-green-800': connection?.status === 'active',
            'bg-red-100 text-red-800': connection?.status === 'error',
          }"
        >
          {{ connection?.status }}
        </span>
      </div>
    </template>

    <template #body>
      <div class="flex flex-col gap-6" v-if="connection">
        <!-- Section Tabs -->
        <div class="flex gap-2 border-b border-n-strong pb-0">
          <button
            class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeSection === 'numbers'
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11'
            "
            @click="activeSection = 'numbers'"
          >
            Phone Numbers ({{ phoneNumbers.length }})
          </button>
          <button
            v-if="isMetaCloud"
            class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeSection === 'templates'
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11'
            "
            @click="activeSection = 'templates'"
          >
            Templates ({{ templates.length }})
          </button>
          <button
            v-if="isEvolution"
            class="px-4 py-2 text-sm font-medium border-b-2 transition-colors"
            :class="
              activeSection === 'instances'
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-11'
            "
            @click="activeSection = 'instances'"
          >
            Instâncias
          </button>
        </div>

        <!-- Phone Numbers Pool -->
        <PhoneNumberPool
          v-if="activeSection === 'numbers'"
          :connection-id="connectionId"
          :phone-numbers="phoneNumbers"
          :provider="connection.provider"
          @sync="syncNumbers"
        />

        <!-- Templates (Meta only) -->
        <TemplateManager
          v-if="activeSection === 'templates' && isMetaCloud"
          :connection-id="connectionId"
          :templates="templates"
        />

        <!-- Evolution Instance Manager -->
        <EvolutionInstanceManager
          v-if="activeSection === 'instances' && isEvolution"
          :connection-id="connectionId"
          :phone-numbers="phoneNumbers"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
