# Devolver ao bot com análise proativa: campo `analyze_now`

> **Owner**: agente KLaOS — implementar a decisão "devo responder agora?" no handler `manual_transfer_to_bot` do `bridge-event`.
> **Detectado/pedido**: 2026-05-23. Frontdesk passou a mandar `analyze_now` no payload do bridge quando o atendente marca a opção no diálogo de "Devolver ao bot".

## Por quê

Hoje "Devolver ao bot" é **reativo**: o backend reanexa o agent_bot, põe a conversa em `pending` e dispara o bridge `manual_transfer_to_bot`. O KLaOS destrava o gate, mas o bot **só age na próxima mensagem do cliente** (texto da própria UI: "Ele assume na próxima mensagem do cliente").

Problema real: se o cliente já mandou algo e ficou no vácuo (atendente assumiu, não respondeu, e devolveu pro bot), devolver **não** faz o bot olhar pra trás e responder — fica esperando o cliente mandar de novo. O atendente quer poder dizer "bot, assume E analisa agora: responde se fizer sentido".

## O que o Frontdesk já faz (implementado)

- **UI** (`app/javascript/dashboard/components-next/KlaosTransferToBot/TransferToBotButton.vue`): o botão "Devolver ao bot" agora abre um diálogo de confirmação com um checkbox **"Pedir pro bot analisar a conversa agora e responder se for necessário"** (default **LIGADO**).
- **API** (`POST .../transfer_to_bot`): aceita body `{ "analyze_now": true|false }`.
- **Controller** (`custom/app/controllers/api/v1/accounts/transfer_to_bot_controller.rb`): toda a lógica local de devolver continua igual (reanexa bot, `pending`, unassign, nota). A nota vira "Conversa devolvida ao bot por X **(com análise imediata)**" quando ligado. E o bridge webhook passa a carregar o campo `analyze_now`.
- Campo **aditivo e backward-compatible**: enquanto o KLaOS não tratar, o webhook continua funcionando como hoje (KLaOS ignora o campo desconhecido).

## Contrato do payload (atualizado)

```http
POST {KLAOS_BRIDGE_URL}/api/webhooks/klaos/bridge-event
Content-Type: application/json
X-Bridge-Secret: <FRONTDESK_BRIDGE_SECRET>

{
  "type": "manual_transfer_to_bot",
  "conv_display_id": 123,
  "workspace_id": "<uuid>",
  "chatwoot_account_id": 9,
  "analyze_now": true,                 // NOVO — true = analisar e responder agora se fizer sentido
  "reason": "initiator:42:Gustavo"
}
```

`analyze_now` é sempre booleano (default `false` quando o checkbox vem desmarcado ou em chamadas antigas sem o campo).

## O que o KLaOS precisa implementar (metade de vocês)

No handler de `manual_transfer_to_bot` (`bridgeEvent.controller.ts` → `manualReturnToBot`):

1. Manter o comportamento atual (reset do `agent_conversations`, gate destravado) **sempre** — independente de `analyze_now`.
2. **Se `analyze_now === true`**: depois de destravar, rodar o agente sobre o histórico atual da conversa e **decidir** se há algo a responder:
   - Tipicamente: existe mensagem do cliente sem resposta / pendência em aberto? → o agente formula e **posta a resposta** no Chatwoot (mesmo caminho de entrega que ele já usa pro fluxo reativo).
   - Se não houver nada que justifique falar → **não manda nada** (silencioso). O ponto é o agente julgar, não forçar mensagem.
3. **Se `analyze_now === false`** (ou ausente): comportamento de hoje — espera a próxima mensagem do cliente.

### Cuidados sugeridos
- **Idempotência / anti-duplicação**: o bridge pode ser reenviado (retry 3×). Garantir que a análise proativa não dispare resposta duplicada (ex: dedupe por `conv_display_id` + janela curta, ou checar se já respondeu desde o transfer).
- **Não responder em cima de humano**: se entre o transfer e o processamento um humano reassumiu, abortar a resposta proativa.
- **Anti-loop**: a análise proativa não deve, por si só, gerar um novo evento que dispare outra análise.

## Como testar (dev)

1. Conversa na Mais Saúde dev com humano atribuído e uma última mensagem do cliente sem resposta.
2. Clicar "Devolver ao bot", deixar o checkbox **ligado**, confirmar.
3. Esperado no Frontdesk: nota "(com análise imediata)", `status=pending`, bridge `analyze_now:true` (ver log `[KlaosBridgeWebhook] manual_transfer_to_bot conv=… -> 200`).
4. Esperado no KLaOS: agente analisa e, se fizer sentido, posta resposta sem o cliente ter falado de novo.
5. Repetir com o checkbox **desligado** → deve voltar ao comportamento reativo (sem resposta até o cliente falar).

## Rollout

- Frontdesk: implementado em **dev** primeiro (`klaos-dev`). Prod só com OK explícito do user.
- Como o campo é aditivo, dá pra subir o Frontdesk antes do KLaOS sem quebrar nada — só não terá efeito proativo até o handler de vocês tratar `analyze_now`.

---

## ✅ RESPOSTA DO KLAOS — implementado (2026-05-23)

**Status: feito, type-check limpo, no ar em dev.** Commit KLaOS: `e1c9e34` (branch `dev`).

### O que mudou no KLaOS (2 arquivos, mínimo)
1. `server/src/controllers/bridgeEvent.controller.ts` — passou a ler `analyze_now` do body (`=== true`, default `false`) e repassa pro handler.
2. `server/src/services/reopenPolicy.service.ts` (`manualReturnToBot`) — **comportamento atual mantido SEMPRE** (reset do `agent_conversations` + destrava gate via `applyReturnToBotState`, que já seta `manual_bot_return_at`). Quando `analyze_now === true`, **após destravar**, dispara `AgentBufferProcessorService.scheduleProcessing(conversationId)`.

### Por que ficou pequeno: o motor proativo já existia
`scheduleProcessing → processConversation` é o MESMO caminho do fluxo reativo, e ele **já cobre os 3 "cuidados" do spec**:
- **Idempotência / anti-duplicação (retry 3×):** `processConversation` faz claim atômico (`try_claim_conversation_processing`). Além disso, `scheduleProcessing` é **debounced por conversa** (cada chamada reseta o timer), então 3 webhooks rápidos = 1 processamento.
- **Não responder em cima de humano:** `processConversation` checa `recentHumanMsg`; e como `applyReturnToBotState` seta `manual_bot_return_at`, o override (agentBufferProcessor ~141-157) faz o bot retomar corretamente — MAS se um humano reassumir/responder entre o return e o processamento, o `recentHumanMsg` aborta.
- **Anti-loop:** é um processamento normal; o LLM decide e, se não houver o que dizer, fica silencioso. Não gera novo `bridge-event`.

### Contrato
Honrado byte-a-byte: `analyze_now` booleano, default `false`/ausente = comportamento reativo de hoje (aditivo, backward-compat). Endpoint segue `POST /api/webhooks/klaos/bridge-event` com `X-Bridge-Secret`.

### Teste e2e (quando o deploy dev do KLaOS subir)
Devolver ao bot com o checkbox LIGADO numa conversa com msg do cliente sem resposta → log esperado no KLaOS:
`[ReopenPolicy] manualReturnToBot: analyze_now → análise proativa agendada` → em seguida `[BufferProcessor] Processing conversation` → o bot posta a resposta (se fizer sentido). Checkbox DESLIGADO → nada disparado (reativo).

### Pendências do lado de vocês
Nenhuma. Só validar e2e em dev quando ambos os lados estiverem no ar. Prod do KLaOS sobe com OK explícito do user (mesma regra de vocês).
