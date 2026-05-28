<script setup>
// KLaOS — Rótulo customizável da aba "Não atribuídas" (multi-tenant).
//
// Permite cada conta digitar um nome próprio para a aba "Não atribuídas"
// da lista de conversas. Exemplo Mais Saúde: "Inteligência Artificial"
// (conversas atribuídas ao bot). Outros clientes podem usar "Triagem",
// "Bot", "Aguardando humano", etc. Em branco = volta ao padrão i18n.
//
// Salva em `account.settings.unassigned_label`. Lido pelo patch em
// ChatList.vue (custom/vite/klaos-patches.js).
import { ref, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Input from 'next/input/Input.vue';
import Button from 'next/button/Button.vue';

const { currentAccount, updateAccount } = useAccount();

const labelValue = ref('');
const isSubmitting = ref(false);

watch(
  currentAccount,
  value => {
    labelValue.value = value?.settings?.unassigned_label || '';
  },
  { deep: true, immediate: true }
);

const handleSubmit = async () => {
  isSubmitting.value = true;
  try {
    const trimmed = labelValue.value.trim();
    await updateAccount(
      {
        // string vazia → null limpa o override (volta ao padrão i18n)
        unassigned_label: trimmed === '' ? null : trimmed,
      },
      { silent: true }
    );
    useAlert(
      trimmed === ''
        ? 'Rótulo restaurado ao padrão.'
        : `Aba "${trimmed}" salva com sucesso.`
    );
  } catch (error) {
    useAlert('Não foi possível salvar o rótulo. Tente novamente.');
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <div class="flex flex-col gap-3 items-start px-5 py-4">
      <div class="flex justify-between items-center w-full gap-4">
        <h3 class="text-heading-2 text-n-slate-12">
          Rótulo da aba "Não atribuídas"
        </h3>
      </div>
      <p class="mb-0 text-body-para text-n-slate-11">
        Personalize o nome da aba "Não atribuídas" da lista de conversas para a
        sua operação. Exemplos: "Inteligência Artificial" (se você usa bot),
        "Triagem", "Aguardando humano". Deixe em branco para usar o padrão.
      </p>
      <div class="flex gap-2 items-end w-full">
        <Input
          v-model="labelValue"
          type="text"
          class="flex-grow"
          placeholder="Não atribuídas (padrão)"
          :disabled="isSubmitting"
          @keydown.enter="handleSubmit"
        />
        <Button
          blue
          :is-loading="isSubmitting"
          label="Salvar"
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>
