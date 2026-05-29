<script setup>
// KLaOS — Modal "Adiar até" customizado (multi-tenant).
//
// Substitui o upstream CustomSnoozeModal.vue corrigindo 3 bugs reportados:
//   B1 — Calendário em inglês (lang hardcoded "Sun/Mon/..." na versão antiga
//        do vue-datepicker-next). Aqui usamos `lang="pt-br"` registrado via
//        import do locale shipado pela biblioteca.
//   B2 — Prop `inline` não existe na DatePicker v1.x (não renderiza calendário
//        expandido — abre como popup). Aqui forçamos `:open="true"` +
//        `:append-to-body="false"` pra o calendário aparecer sempre aberto
//        dentro do modal.
//   B3 — `type="datetime"` da v1.x mostra só data. Aqui ficamos com
//        `type="datetime"` e configuração explícita de minuto step=5 pra
//        UX limpa.
//
// Mantém o mesmo contrato de eventos (close, chooseTime) do upstream
// pra ser drop-in replacement via klaos-patches.js.
import { ref } from 'vue';
import DatePicker from 'vue-datepicker-next';
import 'vue-datepicker-next/locale/pt-br.es.js';
import 'vue-datepicker-next/index.css';
import NextButton from 'dashboard/components-next/button/Button.vue';

defineEmits(['close', 'chooseTime']);

const snoozeTime = ref(null);

const disabledDate = date => {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return date < yesterday;
};

const disabledTime = date => {
  // permite escolher a partir de "agora + 5min" pra dar tempo do agente
  // confirmar sem cair na janela bloqueada
  const now = new Date();
  now.setMinutes(now.getMinutes() + 5);
  return date < now;
};
</script>

<template>
  <div class="flex flex-col">
    <woot-modal-header :header-title="$t('CONVERSATION.CUSTOM_SNOOZE.TITLE')" />
    <form
      class="modal-content w-full pt-2 px-5 pb-6"
      @submit.prevent="$emit('chooseTime', snoozeTime)"
    >
      <div class="klaos-snooze-picker-wrapper">
        <DatePicker
          v-model:value="snoozeTime"
          type="datetime"
          lang="pt-br"
          :open="true"
          :append-to-body="false"
          :disabled-date="disabledDate"
          :disabled-time="disabledTime"
          :minute-step="5"
          :show-second="false"
          format="DD/MM/YYYY HH:mm"
          time-title-format="dddd, DD [de] MMMM"
          confirm
          :confirm-text="$t('CONVERSATION.CUSTOM_SNOOZE.APPLY')"
        />
      </div>
      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2 mt-4">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('CONVERSATION.CUSTOM_SNOOZE.CANCEL')"
          @click.prevent="$emit('close')"
        />
        <NextButton
          type="submit"
          :disabled="!snoozeTime"
          :label="$t('CONVERSATION.CUSTOM_SNOOZE.APPLY')"
        />
      </div>
    </form>
  </div>
</template>

<style scoped>
/* Força o popup do datepicker a aparecer inline dentro do modal,
 * já que a v1.x não tem prop `inline` nativa. Combina com :open=true
 * + :append-to-body=false pra ficar embedded. */
.klaos-snooze-picker-wrapper {
  position: relative;
  min-height: 320px;
}
.klaos-snooze-picker-wrapper :deep(.mx-datepicker) {
  width: 100%;
}
.klaos-snooze-picker-wrapper :deep(.mx-datepicker-main) {
  position: static !important;
  box-shadow: none;
  border: 1px solid var(--n-weak, #e5e7eb);
  border-radius: 0.5rem;
}
.klaos-snooze-picker-wrapper :deep(.mx-input-wrapper) {
  margin-bottom: 0.5rem;
}
</style>
