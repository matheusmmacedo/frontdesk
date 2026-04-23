# SDD — Botão "Devolver ao bot" na UI da conversa

| Campo | Valor |
|---|---|
| Status | **Draft** |
| Prioridade | 🟡 Alta |
| Responsável | Agente Frontdesk |
| Data | 2026-04-23 |

## Problema

Quando um humano assumiu a conversa e percebe que não é caso pra ele (ex: cliente mudou de intent, pergunta simples que bot resolve), hoje **não há botão** pra devolver ao bot. Agente tem que manualmente: (1) alterar status pra pending, (2) remover assignee. Via UI do Chatwoot isso não é trivial.

## Solução

Botão visível na sidebar direita da conversa (área "Conversation Actions"), só pra:
- Admins e colaboradores da inbox
- Conversas cujo inbox tem bot ativo (`agent_bot_inboxes.status = active`)
- Conversas com `assignee_id != null` (não faz sentido devolver conv sem humano)

Ao clicar:
1. Modal de confirmação: "Devolver a conversa ao bot {Lara/Klaus/...}? Ele retoma na próxima mensagem do cliente."
2. Confirma → `POST /api/v1/accounts/:aid/conversations/:id/transfer_to_bot` (ver `SDD_TRANSFER_TO_BOT_API.md`)
3. Feedback: toast "Conversa devolvida ao {Bot}. Ele vai assumir na próxima mensagem."

## Implementação

### Arquivo upstream tocado (mínimo)

`app/javascript/dashboard/components/widgets/conversation/ConversationCardComponents/ConversationActions.vue`  
(ou equivalente — o componente que renderiza "Status Controls" + "Agent Assign" na sidebar)

Diff:
- Adicionar um slot/botão novo condicional à existência de bot na inbox
- Chama `store.dispatch('transferConversationToBot', { id })`

### Código novo em `custom/`

`custom/app/javascript/dashboard/store/modules/transferToBot.js` (novo)
```js
import ApiClient from 'dashboard/api/ApiClient.js';

export default {
  actions: {
    async transferConversationToBot({ dispatch }, { conversationId, accountId }) {
      await ApiClient.post(
        `/api/v1/accounts/${accountId}/conversations/${conversationId}/transfer_to_bot`
      );
      dispatch('updateConversation', { id: conversationId, status: 'pending', assignee: null });
    },
  },
};
```

Registrar no store via initializer (não tocar `store/index.js` upstream):
```js
// custom/app/javascript/dashboard/store/register_transfer_to_bot.js
import transferToBot from './modules/transferToBot';
if (window.__VUE_STORE__) {
  window.__VUE_STORE__.registerModule('transferToBot', transferToBot);
}
```

(detalhe de boot — ver se há um hook Rails de boot Vue que a gente já usa em `custom/`)

### Visibilidade do botão

```js
showTransferButton() {
  const hasBot = this.currentInbox.agent_bot_inbox?.status === 'active';
  const hasAssignee = this.currentConversation.assignee?.id != null;
  return hasBot && hasAssignee;
}
```

### i18n (upstream mínimo)

Adicionar em `app/javascript/dashboard/i18n/locale/pt_BR/conversation.json` (ou criar arquivo custom que faz merge):
```json
{
  "CONVERSATION_ACTIONS": {
    "TRANSFER_TO_BOT": "Devolver ao bot",
    "TRANSFER_TO_BOT_CONFIRM": "Devolver esta conversa ao bot {botName}? Ele assumirá na próxima mensagem do cliente.",
    "TRANSFER_TO_BOT_SUCCESS": "Conversa devolvida ao bot."
  }
}
```

Idem en.

## Feature flag (opt-in por workspace)

Adicionar em `account.custom_attributes.manual_bot_transfer_enabled = true`. Botão só aparece se true.

Admin liga via `Configurações → Automação → Permitir agentes transferirem conversas pro bot` (UI já prevista no SDD de reopen policy).

## Critérios de sucesso

- [ ] Botão aparece SÓ em inbox com bot ativo + conversa com assignee
- [ ] Botão NÃO aparece em inbox sem bot
- [ ] Click chama endpoint; lista de conversas atualiza (conv some da tab "Minhas", volta pra "Ativas" caso esteja lá)
- [ ] Mobile: botão acessível em telas < 768px (ou escondido se não couber)
- [ ] Localização pt_BR e en funcionam

## Relação com outros SDDs

- Requer `SDD_TRANSFER_TO_BOT_API.md` implementado primeiro (endpoint)
- Relação com `../para-klaos-agent/SDD_REOPEN_POLICY.md` — essa é a mesma ação "manual_transfer_to_bot" que dispara o webhook pro KLaOS
