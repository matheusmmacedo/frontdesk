<script setup>
// KLaOS — Toggle "Alerta sonoro ao reabrir conversa adiada" (multi-tenant).
//
// Liga/desliga o componente SnoozeReopenAlert que detecta transições
// snoozed→open e dispara som + pulse na card. Default OFF (opt-in por
// conta — silencioso por padrão pra não atrapalhar contas que não usam
// snooze intensivamente).
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
    isEnabled.value = value?.settings?.snooze_reopen_alert === true;
  },
  { deep: true, immediate: true }
);

const handleToggle = async newValue => {
  isSubmitting.value = true;
  try {
    await updateAccount(
      {
        snooze_reopen_alert: newValue ? true : null,
      },
      { silent: true }
    );
    useAlert(
      newValue
        ? 'Alerta de retorno de conversa adiada ativado.'
        : 'Alerta desativado.'
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
          Alerta sonoro ao reabrir conversa adiada
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
        Quando ligado, ao voltar uma conversa do estado "Adiada" para "Aberta",
        toca um som e a card da conversa fica pulsando na lista por 1 minuto
        para chamar atenção do agente. Útil para operações que usam o adiamento
        como follow-up agendado.
      </p>
    </div>
  </div>
</template>
