# BUG — Lara entra em loop de tokens e estoura limite do WhatsApp (4096 chars)

| Campo | Valor |
|---|---|
| Status | **Reportado — aguarda fix no KLaOS** |
| Prioridade | 🔴 Crítica (bot fica mudo do ponto de vista do cliente) |
| Descoberto | 2026-04-23 |
| Evidência | Conv 36 dev Mais Saúde, msg id 10458 |

## Sintoma percebido

Cliente (Gustavo, contact_id=312) manda "Gentileza me transferir para um humano". Do ponto de vista do cliente, **Lara para de responder** — não chega nada no WhatsApp dele.

## Diagnóstico real

A Lara **está respondendo** — o guard webhook do Frontdesk dispara e registra 200 OK no `additional_attributes.agent_bot_guard_log`. O problema é **no output do LLM**.

O content da msg 10458 saiu assim (trecho, total 4.096+ caracteres):

```
*Lara*:
{"team_name":"contratos","reason":"cliente solicitou transferência para atendimento humano"}namespace=functions.transferir_para_time<commentary 全民彩票天天送json 久久热json mixed to=functions.transferir_para_time code ...
[repete em centenas de idiomas até estourar 4096]
```

O LLM:
1. **Tentou invocar** a tool `transferir_para_time` (vazou o JSON como texto em vez de chamada real — mesmo bug já reportado em `SDD_HANDOFF_TOOL_INVOCATION.md`)
2. **Entrou em loop** de token garbage (chinês, russo, árabe, tailandês, georgiano... misturado com `namespace=functions.transferir_para_time to=functions.transferir_para_time` em repetição)
3. Gerou **mais de 4.096 caracteres**
4. Chatwoot tentou mandar pra WhatsApp Meta API → Meta **rejeitou** com:

```json
"content_attributes": {
  "external_error": "Param text.body must be at most 4096 characters long."
}
```

5. Meta 400 → mensagem fica salva no Chatwoot com status "failed", mas nunca chega no celular do cliente
6. Do lado do cliente: silêncio. Do lado do admin: a conv fica `pending`, sem team, sem assignee, com uma msg enorme lixo no meio.

## Caminho reprodutor

1. Cliente manda algo que dispara intent de handoff (ex: "me transfere pra um humano")
2. Lara tenta emitir tool call `transferir_para_time`
3. Por algum motivo (parsing? token sampling? formato do system prompt?) o LLM degrada e começa a repetir em múltiplos idiomas até bater max_tokens ou hard limit

Hipóteses de causa raiz:
- **Prompt engineering** — o system prompt da Lara pode estar instruindo algo que confunde o modelo (ex: instruções sobre tool call em múltiplos idiomas geram completions multi-idioma)
- **tool_choice** setado errado — modelo alucina a chamada em vez de executar
- **LLM provider bug** — Sonnet/GPT-4 às vezes loopa com repetition penalty baixo. Verificar se a Lara tem `frequency_penalty` / `presence_penalty` configurados
- **Stop tokens ausentes** — sem stop sequence pros delimiters internos (`namespace=functions`, `to=functions.`), modelo continua gerando

## Ações recomendadas no KLaOS

### Imediato (bloqueante do usuário)

1. **Guard de tamanho** na pipeline da Lara — **antes** de enviar pro Chatwoot:
   ```ts
   if (message.content.length > 4000) {
     logger.error('[LaraGuard] LLM output truncated — too long', { len: message.content.length });
     // Substituir por mensagem padrão
     message.content = 'Um momento, estou te transferindo pro atendimento.';
     // Forçar tool call manualmente (ver SDD_HANDOFF_TOOL_INVOCATION.md)
     await executeToolCall('transferir_para_time', { team_name: 'contratos', reason: 'auto-recovery tokens loop' });
   }
   ```

2. **Detecção de loop** — se a resposta contém `namespace=functions` ou `to=functions.` em texto (padrão OpenAI interno vazado), é loop garantido:
   ```ts
   if (/namespace=functions|to=functions\./.test(message.content)) {
     // Mesmo caminho de recovery acima
   }
   ```

### Estrutural (fix real)

- Revisar o **system prompt da Lara** — simplificar instruções sobre tool calling
- Configurar **stop sequences** explícitas no LLM client (`namespace=`, `to=functions.`)
- Adicionar **frequency_penalty: 0.5** e **presence_penalty: 0.3** pra reduzir loop risk
- Se estiver usando **tool_choice: "auto"**, considerar migrar pra `tool_choice: {"type": "function", "name": "transferir_para_time"}` quando intent de handoff for detectado por classificador antes do LLM

## Ações imediatas já tomadas no Frontdesk (hoje)

- Msg 10458 (garbage loop) **soft-deletada** no DB dev (content="Esta mensagem foi deletada")
- Resposta manual enviada pro Gustavo: *"Desculpa a demora! Vou te transferir agora pro setor de contratos."*
- Conv 36 **aberta**, **transferida pro team Contratos (id 8)**, **assignee Gustavo (user 13)**

Cliente foi desbloqueado manualmente. Mas o bug vai repetir.

## Critérios de sucesso

- [ ] Guard de tamanho na pipeline KLaOS (>4000 chars → mensagem padrão + force tool exec)
- [ ] Guard de detecção de vazamento de tool marker (`namespace=functions`, `to=functions.`)
- [ ] Config stop sequences no LLM client
- [ ] Testar reprodução: "gentileza me transferir pra um humano" → Lara transfere em <3 segundos sem vazar texto

## Dependência cruzada

- `SDD_HANDOFF_TOOL_INVOCATION.md` — esse bug é **agravamento** do bug lá: além de não invocar a tool, o LLM entra em loop
- `BUG_LIMPAR_INBOX_DELETION.md` — não relacionado, mas descoberto na mesma sessão
