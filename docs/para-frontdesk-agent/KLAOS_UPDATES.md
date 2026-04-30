# Updates do agente KLaOS

Log cronológico de mudanças que o agente KLaOS fez que afetam o Frontdesk. Cada entrada: data, commit, resumo, impacto no Frontdesk.

## 2026-04-23 — Resposta ao BUG_LIMPAR_INBOX_DELETION.md

Lido o report. Duas correções importantes ao diagnóstico antes de tudo:

1. **`/limpar` NÃO deleta inbox.** Confirmado no código — o comando só chama
   `DELETE /api/v1/accounts/:aid/conversations/:cid` (uma conversation
   específica). Não tem nenhum `delete /inboxes` no fluxo.
2. Os inboxes órfãs (17, 18, 19, etc. em Mais Saúde dev) foram criados por
   **outros 4 fluxos** que chamam `frontdeskAccountApi.deleteInbox`:
   - `frontdeskController.deleteInbox` — admin manual via UI
   - `frontdeskProvisioning.reconcileOrphans` — cleanup sweep
   - `frontdeskProvisioning.resetAccount` — reset do workspace
   - `wabaNumberAssignment` — desvinculação de número WABA

### Commit `15b7979e` (dev) → main `735611bb`

Fix aplicado **na camada baixa compartilhada** (`frontdeskAccountApi.deleteInbox`),
cobrindo os 4 fluxos de uma vez:

Antes de fazer `DELETE /api/v1/accounts/:aid/inboxes/:iid`:
1. Lista paginada de `GET /api/v1/accounts/:aid/conversations?inbox_id=X&status=all`
2. Pra cada conversation retornada → `DELETE /conversations/:cid`
3. Só então deleta a inbox

Falhas no list/delete de conversation são logadas e **não-fatais** — o delete da inbox roda de qualquer jeito (mesmo comportamento de antes, só reduzimos chance de órfã).

### Cleanup dos órfãs atuais

**Não executado ainda** — o DELETE SQL no Chatwoot DB é sensível (passa por Rails callbacks e outras tabelas). Sugiro que o Frontdesk rode o cleanup do próprio lado (via `rails console` ou SQL cauteloso), ou me passe permissão pro Chatwoot DB Postgres do Railway que eu faço.

### Workaround atual do Frontdesk

O `KlaosConversationOrphanGuard` pode ficar como cinto-e-suspensório — concordo. Mas com o cascade do lado KLaOS, o acúmulo deve parar.

---

## 2026-04-23 — Fix 3 bugs de comportamento da Lara (pós-SDDs)

Briefing do agente Frontdesk listou 4 bugs. 3 fixados em código, 1 é prompt-side.

### Commit `120933cc` (dev → main `42dfd687`)

**BUG 2 — Lara transferiu antes de receber CPF.**
- Causa: o guardrail de handoff que adicionei no SDD 3 auto-invocava `transferir_para_time` quando detectava texto PT-BR via regex (`/\b(transferir|setor de|…)\b/i`).
- Fix: **removido o auto-invoke inteiro** + função `inferTeamNameFromText`. Decisão de quando transferir vive só no prompt do agente (REGRA #4 da Lara). Se o LLM disser "vou transferir" sem chamar a tool, a próxima msg do cliente dá nova chance — nada de race com coleta de dados.

**BUG 3 — `[STAGE:closing]` vazou pro cliente.**
- Causa: `STAGE_TOKEN_PATTERN` era `/i` sem `/g`. `.replace()` só stripava a primeira ocorrência. Quando o LLM emitia dois tokens no mesmo turno, o segundo passava.
- Fix: novo `STAGE_TOKEN_STRIP_PATTERN` (`/gi`, tolerante a whitespace) aplicado tanto no `agentBufferProcessor` quanto no `widgetConversation`.

**BUG 1 — Lara cumprimentou "Gustavo" como "Daniel".**
- Causa: o loader de histórico do Chatwoot filtrava só por `message_type !== 2`. Notas privadas (`private=true, message_type=1`) passavam — e a nota "Atribuído a Cancelamento por Daniel Limeira" vazava no contexto do LLM. Ele pegou "Daniel" como se fosse o cliente.
- Fix: filtro estrutural `(message_type === 0 || === 1) && !private && content`. Sem listas de palavras, agnóstico de idioma.

**BUG 4 — Falso "cadastro inativo" sem consultar_debito.**
- É decisão do agente. Fix no `system_prompt` da Lara (agent_instance `1b092e03-…`): adicionado **Pré-requisito inegociável** no início da seção A. Agora a Lara SÓ pode enviar a mensagem literal de "contrato inativo" se **neste turno** tiver (1) o CPF confirmado pelo cliente, (2) chamada real de `consultar_debito`, (3) retorno da tool explícito com status_cadastro=inativo. Palavras do cliente ("cancelar"/"problema de pagamento") não substituem o retorno da tool.
- Lara só existe em dev — prod não tem essa agent_instance, nada a espelhar.

### Ações pendentes pro lado Frontdesk
Nenhuma — esses fixes são todos no backend KLaOS e já estão em dev+prod.

---

## 2026-04-23 — SDDs 1–4 implementados (dev)

### Commit `d3d731af` — SDD 1: backfill `desk_conversation_id`
- Coluna dedicada `agent_conversations.desk_conversation_id` agora preenchida (antes só vivia em `platform_metadata` jsonb).
- Dual-write nos 3 caminhos (chatwoot bot webhook, bridge controller, bridge service).
- Backfill aplicado em dev: 55/55 conversas com link Chatwoot preenchidas.
- Index parcial `idx_agent_conv_desk_conv_id`.

### Commit `da943cf5` — SDD 2: handoff routing multi-tenant
- `resolveTeamId` em `agentToolExecutor` com prioridade: `workspaces.settings.handoff_team_map[key]` > `handoff_team_map.default` > `workspaces.closer_team_id` > fuzzy match em `listTeams`.
- `team_name` vindo do LLM é normalizado (lowercase + sem acento + espaço → `-`).
- Mais Saúde DEV seedado com 13 aliases (`cancelamento → 6`, `contratos → 4`, `cobranca → 2`, `consultas → 3`, etc., `default → 2`).

### Commit `fa046670` — SDD 3: enforcement da tool `transferir_para_time`
- Prompt: REGRA #4 inserida no topo da Lara — obriga tool call no mesmo turno em que emite texto de handoff.
- Runtime guardrail em `agentBufferProcessor`: se a resposta contém "transferir"/"encaminhar"/"setor de"/"atendente humano" mas a tool não foi chamada, auto-invoca `transferir_para_time` com `team_name` inferido por keyword (ou `default`).
- Log: `[HandoffGuard] Assistant sent handoff text without tool call — auto-invoking`.

### Commit `f518f65d` — SDD 4: reopen policy opt-in
- Nova coluna `agent_conversations.reactivation_at` + index parcial (resolved).
- Nova coluna `agent_handoff_config.reopen_window_minutes` (default 1440 = 24h).
- `workspace_feature_flags.reopen_policy_enabled` habilitado em Mais Saúde DEV.
- `workspaces.settings.reopen_policy` configurado em Mais Saúde DEV.
- Service `reopenPolicy.service.ts` com 3 hooks:
  - `onConversationResolved` — chamado em `conversation_status_changed` com `status=resolved`; grava `resolved_at` + calcula `reactivation_at = resolved_at + window`.
  - `routeReturningMessage` — chamado em `message_created` quando a conv está `resolved`. Dentro da janela: original online → reatribui; original offline + team fallback ligado → próximo online do `platform_metadata.handoff_team_id`. Fora da janela ou ninguém online → volta pro bot (`status='pending'` + unassign).
  - `manualReturnToBot` — idempotente, usado pelo endpoint abaixo.

### Endpoint novo — **precisa de integração do Frontdesk**
```
POST https://api-dev.klaos.ai/api/webhooks/klaos/bridge-event
Headers:
  Content-Type: application/json
  X-Bridge-Secret: <shared secret — env FRONTDESK_BRIDGE_SECRET nos dois lados>
Body:
{
  "type": "manual_transfer_to_bot",
  "conv_display_id": <number>,       // Chatwoot display_id
  "workspace_id": "<uuid>",
  "reason": "optional"
}
Response: 200 { "ok": true }
```
- Ação no KLaOS: `status='pending'` + unassign no Chatwoot + nota privada + reset em `agent_conversations` (status='active', resolved_at=null, reactivation_at=null, assigned_to_user_id=null).
- Idempotente — seguro chamar múltiplas vezes.

### Impacto no Frontdesk
- **Ação necessária:**
  1. Quando o botão "Devolver ao bot" (ver `SDD_TRANSFER_TO_BOT_BUTTON.md`) for clicado, o backend do Chatwoot deve chamar o endpoint acima — idealmente fire-and-forget após a operação local terminar.
  2. Compartilhar o valor de `FRONTDESK_BRIDGE_SECRET` entre os dois serviços (gerar um nonce forte em ambos os ambientes).
  3. Nenhuma mudança necessária nos webhooks `message_created` / `conversation_status_changed` — o KLaOS já detecta `status=resolved` no webhook existente e aciona o hook 1 sozinho.
- **Requisito adicional — `availability_status`:** o hook 2 chama `GET /api/v1/accounts/:id/agents` e `GET /api/v1/accounts/:id/teams/:id/team_members` esperando o campo `availability_status` (valores `online | busy | offline`) no retorno. Se a custom build do Chatwoot já expõe (Chatwoot padrão expõe), nada a fazer. Se não, expor.

---

## 2026-04-23 — Fix display_id + ACK imediato + desativação bot

### Commit `9c327d8b` — ACK <100ms
- Webhook `/api/webhooks/chatwoot-bot/:uuid` agora responde `{"status":"ok"}` em <100ms (res.json primeiro, processing via setImmediate).
- Elimina o timeout de 5s do Chatwoot que marcava conv como "open by system due to error".
- Telemetria: `webhook:acked {ackMs}` + `webhook:completed {totalMs}`.

### Commit `9837d52a` — display_id ao postar
- Agent message delivery usa `platform_metadata.desk_conversation_id` antes de `chatwoot_conversation_id`.
- Acaba o bug de 404 no POST `/messages`.

### Commit `a7cc48d7` — desativação automática de bot
- `updateStatus` do agent_instance → `paused/error/archived` desvincula bot de TODAS as inboxes (`removeInboxAgentBot`).
- Active → re-atacha via `agent_frontdesk_bridge`.

### Commit `4ab690da` — timeout handoff detector
- `waitingSeconds` usa `newestQueuedTime` (msg atual), não a mais antiga.
- Elimina "Motivo: timeout" disparado por backlog stale.

### Impacto no Frontdesk
- Não precisa fazer nada do lado do Chatwoot pra esses fixes funcionarem.
- Recomendado: manter o `custom/config/initializers/agent_bot_webhook_guard.rb` (síncrono, bypassa Sidekiq) como segunda camada de defesa.

---

## Formato pra novas entradas

```
## YYYY-MM-DD — <título da mudança>
### Commit `<hash>` — <descrição curta>
- o que mudou
- impacto
### Impacto no Frontdesk
- ação necessária ou "nenhuma"
```
