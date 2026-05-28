<script setup>
// KLaOS — Toggle "Manter agentes online até logout manual" (multi-tenant).
//
// Liga/desliga o override de auto_offline por conta. Quando ON, salva
// `account.settings.auto_offline_default = false`, o que faz o backend
// (KlaosAutoOfflineOverride em AccountUser) tratar todos os agentes desta
// conta como auto_offline=false — sem cair pra offline automático por
// inatividade.
//
// Default OFF (comportamento Chatwoot nativo preservado).
import { ref, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Switch from 'next/switch/Switch.vue';

const { currentAccount, updateAccount } = useAccount();

const isEnabled = ref(false);
const isSubmitting = ref(false);

watch(
  currentAccount,
  value => {
    const flag = value?.settings?.auto_offline_default;
    isEnabled.value = flag === false;
  },
  { deep: true, immediate: true }
);

const handleToggle = async newValue => {
  isSubmitting.value = true;
  try {
    await updateAccount(
      {
        // null limpa o override (volta pro comportamento Chatwoot nativo)
        // false ativa o override (agentes sempre online até logout manual)
        auto_offline_default: newValue ? false : null,
      },
      { silent: true }
    );
    useAlert(
      newValue
        ? 'Agentes desta conta ficarão online até clicarem para sair.'
        : 'Comportamento padrão restaurado (offline automático por inatividade).'
    );
  } catch (error) {
    isEnabled.value = !newValue;
    useAlert('Não foi possível atualizar a configuração. Tente novamente.');
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <div class="flex flex-col gap-2 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full gap-4">
        <h3 class="text-heading-2 text-n-slate-12">
          Manter agentes online até logout manual
        </h3>
        <div class="flex justify-end">
          <Switch
            v-model="isEnabled"
            :disabled="isSubmitting"
            @change="handleToggle"
          />
        </div>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        Quando ligado, agentes desta conta não saem para offline automaticamente
        por inatividade — permanecem online até clicarem em Sair. Útil para
        operações onde o atendente fica logado o turno todo. O comportamento
        individual de cada agente em "Perfil" volta a valer se este toggle for
        desligado.
      </p>
    </div>
  </div>
</template>
