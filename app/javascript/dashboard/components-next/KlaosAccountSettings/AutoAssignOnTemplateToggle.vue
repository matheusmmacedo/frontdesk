<script setup>
// KLaOS — Toggle "Auto-atribuir conversa ao enviar template" (Item 2).
//
// Quando ligado, ao agente disparar um template (notificação ativa) numa
// conversa sem assignee, a conversa é atribuída automaticamente ao agente.
// Resultado: aparece em "Minhas" do agente imediatamente.
//
// Multi-tenant: salva em account.settings.auto_assign_on_template_send.
// Default OFF — opt-in por conta.
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
    isEnabled.value = value?.settings?.auto_assign_on_template_send === true;
  },
  { deep: true, immediate: true }
);

const handleToggle = async newValue => {
  isSubmitting.value = true;
  try {
    await updateAccount(
      {
        auto_assign_on_template_send: newValue ? true : null,
      },
      { silent: true }
    );
    useAlert(
      newValue
        ? 'Auto-atribuição ativada: ao enviar template, conversa cai em "Minhas".'
        : 'Auto-atribuição desativada.'
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
          Auto-atribuir ao enviar template
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
        Quando ligado, ao disparar um template (notificação ativa) numa
        conversa sem agente atribuído, a conversa é automaticamente atribuída
        ao agente que enviou. A conversa aparece em "Minhas" na hora — útil
        para operações de cobrança / disparo ativo onde quem mandou precisa
        acompanhar a resposta.
      </p>
    </div>
  </div>
</template>
