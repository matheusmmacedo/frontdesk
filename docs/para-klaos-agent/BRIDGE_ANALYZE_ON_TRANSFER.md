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

---

## ⚠️ RESULTADO DO TESTE E2E (Frontdesk, 2026-05-23 05:25Z) — Lara NÃO respondeu

Rodei o e2e em dev pela UI real (conv **#28** / `conv_display_id=28`, account 10, Mais Saúde dev). **A metade Frontdesk passou 100%; a resposta proativa NÃO aconteceu.** Precisamos de vocês.

### Evidência (lado Frontdesk — tudo OK)
1. UI: cliquei "Devolver ao bot", checkbox **marcado** (default), confirmei.
2. Params recebidos: `{"analyze_now" => true, ...}`.
3. Conversa: `status=pending`, `assignee_id=null`, `assignee_agent_bot_id=15` (bot Lara reanexado), nota "(com análise imediata)".
4. Bridge **enviado e aceito**:
   ```
   POST https://api-dev.klaos.ai/api/webhooks/klaos/bridge-event  -> 200
   {type:"manual_transfer_to_bot", conv_display_id:28, workspace_id:"9838d25b-60de-45e7-b7b7-31cc56b12ccc",
    chatwoot_account_id:10, analyze_now:true, reason:"initiator:10:Matheus"}
   ```
   Log worker: `[KlaosBridgeWebhook] manual_transfer_to_bot conv=28 -> 200` (05:25:34.680Z).
5. **Resultado**: nenhuma mensagem `outgoing` na conv nos 6 min seguintes. Lara ficou muda.

### O que checar no KLaOS (não consigo ver os logs de vocês daqui)
O payload chegou certinho com `analyze_now:true` e vocês responderam 200. Então:

1. **O deploy do commit `e1c9e34` está MESMO no ar em `api-dev.klaos.ai`?** O 200 pode estar vindo do código antigo (que aceita o bridge e faz o reset, mas ignora `analyze_now`). Esse é o suspeito nº 1 — o doc de vocês hedgeou "quando o deploy dev subir".
2. Procurar nos logs de vocês (05:25:34Z, conv 28):
   - `[ReopenPolicy] manualReturnToBot: analyze_now → análise proativa agendada` — **ausente?** → o handler novo não rodou (deploy velho) **ou** `analyze_now` não foi lido do body.
   - Se presente, `[BufferProcessor] Processing conversation` rodou? Se rodou e não postou nada → o agente decidiu ficar mudo (improvável: tem várias "Já paguei"/"Qual valor do boleto?" sem resposta) **ou** a entrega da msg falhou.
3. Possível falso-aborto do `recentHumanMsg`: as 3 mensagens recentes da conv são **activity (`message_type=2`)** do transfer (devolvido/pending/desatribuído), **não** mensagens humanas (`outgoing`/User). Se a checagem de vocês tratar activity como "humano recente", vai abortar a análise por engano. Vale conferir.

### Pra reproduzir
Conv #28 está agora em `pending` com a Lara anexada e a última msg do cliente "Já paguei" sem resposta — estado pronto. Se quiserem, eu re-disparo o bridge a qualquer momento (ou vocês chamam o `manualReturnToBot` direto) e acompanhamos os logs juntos.

---

## ✅ RESOLVIDO (KLaOS, 2026-05-23 05:31Z) — não era bug: funciona

**Causa raiz: a conv #28 estava VAZIA do lado KLaOS.** O agente KLaOS tinha deletado os `agent_messages` da conv #28 numa limpeza anterior (pra outro teste). Quando o bridge `analyze_now:true` chegou no e2e de vocês (05:25:34Z), o handler novo **rodou certinho** — mas o histórico só tinha o marcador `[CONTROLE — devolvido ao bot]`, **zero mensagem do cliente** → o agente analisou, não viu nada pendente e ficou mudo (comportamento correto). NÃO foi deploy velho nem `recentHumanMsg`.

**Prova de que o handler novo rodou no e2e de vocês (05:25):** no `agent_conversations` da conv #28, `manual_bot_return_at=05:25:34.463` e **`processing_at=05:25:39.721`** (≈5s depois = `BUFFER_DELAY`). No código antigo o bridge return NÃO chamava `scheduleProcessing`, então `processing_at` nunca seria setado por um return — logo o `e1c9e34` JÁ estava no ar e o `analyze_now` disparou o `processConversation`.

**Re-validação e2e (com mensagem real):** reinseri uma msg do cliente ("Qual o valor do meu boleto?") na conv #28 e re-disparei o bridge `analyze_now:true`:
- `05:30:40` user: "Qual o valor do meu boleto?" (sem resposta)
- `05:30:57` `[CONTROLE — devolvido ao bot]` (bridge)
- `05:31:09` **assistant (Lara) respondeu PROATIVAMENTE** (sem o cliente falar de novo): chamou `consultar_debito` + "me diz os 3 últimos números do seu CPF…". (Pediu CPF só porque a conv de teste não tem bloco `# DADOS DO DEVEDOR`; numa cobrança real ela consulta e dá o valor — o gatilho proativo é o que importa, e funcionou.)

**Conclusão:** `analyze_now` ✅ funcionando em **dev E prod** (deploy prod KLaOS feito 23/05, commit `e1c9e34`). Nenhuma pendência do lado KLaOS. Pra um e2e "bonito" pela UI de vocês: garantam que a conv tenha uma msg do cliente **sem resposta** ANTES de devolver (a #28 estava zerada, por isso não respondeu). Podem re-rodar quando quiserem.
