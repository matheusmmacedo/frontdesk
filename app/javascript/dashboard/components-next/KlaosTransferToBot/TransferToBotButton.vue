<script setup>
// KLaOS custom — botão "Devolver ao bot" com diálogo de confirmação + opção de
// pedir análise proativa do agente.
//
// Hoje, devolver ao bot é REATIVO: o bot só age na próxima mensagem do cliente.
// O checkbox "analisar agora" (default ligado) manda analyze_now=true pro
// backend, que repassa no webhook bridge pro KLaOS. O agente KLaOS então olha a
// conversa na hora e decide se responde algo ou não — sem esperar o cliente.
//
// Componente isolado (não mexe na lógica do ResolveAction): toda complexidade
// do diálogo/checkbox/API vive aqui. Pasta KlaosTransferToBot/ pra sobreviver
// a merges do upstream (upstream nunca toca pastas Klaos*).
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ConversationApi from 'dashboard/api/inbox/conversation';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const getters = useStoreGetters();

const currentChat = computed(() => getters.getSelectedChat.value);

const dialogRef = ref(null);
const isLoading = ref(false);
// Default LIGADO — comportamento escolhido: "analisar e responder se fizer sentido".
const analyzeNow = ref(true);

const openDialog = () => {
  analyzeNow.value = true;
  dialogRef.value?.open();
};

const confirmTransfer = async () => {
  isLoading.value = true;
  try {
    await ConversationApi.transferToBot(currentChat.value.id, {
      analyzeNow: analyzeNow.value,
    });
    useAlert(
      analyzeNow.value
        ? 'Conversa devolvida ao bot. Ele vai analisar e responder se for necessário.'
        : 'Conversa devolvida ao bot. Ele assume na próxima mensagem do cliente.'
    );
    dialogRef.value?.close();
  } catch (e) {
    useAlert('Falha ao devolver ao bot. Tente novamente.');
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <Button
    :label="t('CONVERSATION.RESOLVE_DROPDOWN.TRANSFER_TO_BOT')"
    icon="i-lucide-bot"
    size="sm"
    color="slate"
    class="mr-3 outline outline-1 outline-n-container shadow rounded-lg"
    @click="openDialog"
  />
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="t('CONVERSATION.RESOLVE_DROPDOWN.TRANSFER_TO_BOT')"
    description="Devolver esta conversa ao bot? Ele reassume o atendimento."
    confirm-button-label="Devolver"
    :is-loading="isLoading"
    @confirm="confirmTransfer"
  >
    <label class="flex items-start gap-2 cursor-pointer select-none">
      <input v-model="analyzeNow" type="checkbox" class="mt-1 cursor-pointer" />
      <span class="text-sm text-n-slate-12">
        Pedir pro bot analisar a conversa agora e responder se for necessário
      </span>
    </label>
  </Dialog>
</template>
