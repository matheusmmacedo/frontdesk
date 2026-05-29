<script setup>
// KLaOS — Banner janela 24h WhatsApp (O.10 Onda 2).
//
// WhatsApp Business API só permite responder com texto livre dentro de
// 24h da última mensagem do cliente. Depois disso, só com template
// aprovado. O banner upstream do Chatwoot pra esse aviso é rosa claro e
// passa BATIDO (vi em prod com agente ficando travado tentando enviar
// texto e não saca o motivo).
//
// Banner KLaOS reforçado:
//   - Cor: âmbar escuro com listra lateral âmbar
//   - Ícone de relógio piscando
//   - Texto curto e direto em PT-BR
//   - Link clicável pra abrir o picker de template
//
// Multi-tenant nato. Aparece em qualquer inbox WhatsApp quando
// currentChat.can_reply === false.

defineProps({
  // Permite custom message override. Default: copy PT-BR padrão.
  messageOverride: { type: String, default: '' },
});

const openTemplatePicker = () => {
  // Emite evento que ReplyBox escuta pra abrir modal de template.
  // ReplyBox.vue já tem listener pra 'klaos:open-template-picker'.
  document.dispatchEvent(new CustomEvent('klaos:open-template-picker'));
};
</script>

<template>
  <div
    class="klaos-wa24h-banner flex items-center gap-3 mx-2 mt-2 px-4 py-3 rounded-lg"
    role="alert"
  >
    <span class="klaos-wa24h-banner__icon" aria-hidden="true">⏱️</span>
    <div class="flex-1 min-w-0">
      <div class="klaos-wa24h-banner__title">
        Janela 24h do WhatsApp expirou
      </div>
      <div class="klaos-wa24h-banner__desc">
        {{
          messageOverride ||
          'Só dá pra responder com TEMPLATE aprovado até o cliente mandar uma mensagem nova.'
        }}
      </div>
    </div>
    <button
      type="button"
      class="klaos-wa24h-banner__btn"
      @click="openTemplatePicker"
    >
      Usar template
    </button>
  </div>
</template>

<style scoped>
.klaos-wa24h-banner {
  background: linear-gradient(90deg, #fef3c7 0%, #fde68a 100%);
  border: 1px solid #f59e0b;
  border-left: 4px solid #d97706;
  color: #78350f;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}
.klaos-wa24h-banner__icon {
  font-size: 22px;
  animation: klaos-wa24h-pulse 1.5s ease-in-out infinite;
}
.klaos-wa24h-banner__title {
  font-weight: 700;
  font-size: 14px;
  color: #78350f;
}
.klaos-wa24h-banner__desc {
  font-size: 13px;
  margin-top: 2px;
  color: #92400e;
}
.klaos-wa24h-banner__btn {
  background: #d97706;
  color: white;
  font-weight: 600;
  font-size: 13px;
  padding: 6px 12px;
  border-radius: 6px;
  border: none;
  cursor: pointer;
  white-space: nowrap;
}
.klaos-wa24h-banner__btn:hover {
  background: #b45309;
}
@keyframes klaos-wa24h-pulse {
  0%, 100% { opacity: 0.6; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.1); }
}
</style>
