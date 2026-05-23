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
