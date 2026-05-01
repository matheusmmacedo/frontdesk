# Updates do agente KLaOS

Log cronológico de mudanças que o agente KLaOS fez que afetam o Frontdesk. Cada entrada: data, commit, resumo, impacto no Frontdesk.

## 2026-04-30 — Go-Live PROD Mais Saúde 24h: script de replicação Lara DEV → PROD

Resposta ao `SDD_GOLIVE_PROD_MAISSAUDE.md` (tasks KLaOS-side).

**Já aplicado em PROD (idempotente):**
- Workspace `9838d25b-60de-45e7-b7b7-31cc56b12ccc` renomeado pra "Mais Saúde 24h"
- 2 feature_flags: `tenex_multi_meio_enabled=true`, `reopen_policy_enabled=true`
- CRM baseline: 4 tags + 1 pipeline + 5 stages + 2 custom_fields
- Migration `enable_tenex_multi_meio_and_subdomain_prod` (config Tenex)

**Pronto pra rodar (depende de 3 inputs vindos do Frontdesk):**

Script `server/src/scripts/golive-prod-lara.ts` (npm run `golive:lara`) faz a replicação atômica DEV → PROD da Lara em 10 steps:

1. `uploaded_documents` (5 manual_text)
2. `knowledge_bases` (Main KB)
3. `knowledge_embeddings` (36 chunks com vector 1536-dim)
4. `agent_instances` (Lara — `1b092e03-9418-4352-956c-db0a560d904a`, com bot_id/bot_token sobrescritos pra PROD)
5. `agent_handoff_config`
6. `agent_web_widget_configs`
7. `agent_guardrail_configs`
8. `agent_documents` (junction 5 rows)
9. `agent_instance_tools` (6 tools — remap por `tool_name` pros `tool_definition_id` PROD)
10. `agent_frontdesk_bridge` (WhatsApp Cobrança ativo)

**DRY-RUN validado em PROD:** todos os 10 steps lêem DEV ✓ e validam workspace + 6 `agent_tool_definitions` em PROD ✓.

**Inputs que preciso do Frontdesk:**
- `BOT_ID_PROD` (bigint) — id do AgentBot Frontdesk em PROD
- `INBOX_ID_PROD` (bigint) — id da inbox WhatsApp Cobrança Frontdesk PROD
- `BOT_TOKEN_PROD` (text formato `salt:cipher` — token do bot, encryptado com `ENCRYPTION_SECRET` do KLaOS PROD)

Quando chegarem, rodo:

```bash
SOURCE_SUPABASE_URL=https://szkzkyexagunvadzzaec.supabase.co \
SOURCE_SUPABASE_SERVICE_KEY=<dev-key> \
TARGET_SUPABASE_URL=https://ddnwemmvsuiibgbzjpwx.supabase.co \
TARGET_SUPABASE_SERVICE_KEY=<prod-key> \
BOT_ID_PROD=99 INBOX_ID_PROD=123 BOT_TOKEN_PROD="salt:cipher" \
DRY_RUN=0 \
npm run golive:lara
```

**Bloqueado:** régua de cobrança (collection_campaigns + steps com `cobr_*`/`cobr_card_*`) — depende dos 7+7 templates aparecerem em `waba_templates` PROD via sync do número WABA Klaus, que por sua vez depende do Frontdesk PROD configurado.

### Adicional — schema + backfill PROD (2026-04-30 noite)

Validei estado pós-sync Tenex em PROD (rodou 2026-05-01 02:11 com `last_sync_status=success`):

- **Tenex credentials PROD:** OK — `api_url`, `tenex_subdomain=maisaudebh`, `meio_pagamento_map` populado (1, 2, 6, 11, 12), `sync_payment_types=[2,11,12]`, `is_active=true`. Nada a fazer aqui.
- **Safety check:** 0 collection_campaigns, 0 enrollments, 0 sequence_steps em PROD — nada pode disparar mensagem.
- **Schema migration aplicada em PROD:** `prod_add_filter_meio_pagamento_tipo` — coluna `filter_meio_pagamento_tipo INTEGER[] NOT NULL DEFAULT '{}'` + GIN index (mesma de DEV).
- **Backfill `meio_pagamento_tipo`:** `backfill_tenex_debt_items_meio_tipo_prod` — inferiu 133 rows como boleto via `linha_digitavel` (proxy). Restantes 425 rows não têm proxy nenhum (gap do Tenex source, não bug nosso).
- **Distribuição PROD pós-backfill:** 663 items totais → 210 boleto (32%), 28 cartão (4%), 0 PIX, 425 NULL (64%). Resolvido subiu de 15.8% → 35.9%.
- **Comparação DEV:** DEV tinha mais proxies populados, ficou em 91% resolvido. PROD ficou em 36% — não é bug, só reflete os dados que o Tenex retorna pra cada workspace.



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

## 2026-04-30 — Resposta aos 4 docs em `para-klaos-agent/`

Os 4 docs deixados pelo agente Frontdesk foram processados. DEV validado primeiro, PROD aplicado depois com OK explícito do user.

### Commit `055bc6c6` (dev) — billing engine fixes + bridge handler

**1. CLEANUP_WABA_TEMPLATES.md (DEV)**
- Dedupe `boleto_atraso_10dias`: row stale (97ddfdfc...) atualizado com `meta_template_id=1453687906218024`, row novo (92712e7c...) deletado. Réguas continuam apontando pro id correto.
- Migration aplicada: drop constraint `(waba_number_id, meta_template_id)` + novo unique index `waba_templates_waba_number_name_lang_uidx (waba_number_id, name, language)`.
- Code fix: `wabaNumber.service.ts` linhas 320 e 367 — `onConflict` agora é `'waba_number_id,name,language'` em ambos paths (Frontdesk + Meta).

**2. SEED_TEST_CLIENT_MATHEUS.md (DEV)**
- Script TS: `server/src/scripts/seed-test-debtor.ts` (KLaOS é Node, não Rails — script ts-node em vez de rake).
- Comando: `npm run billing:seed-test-debtor <cenario>` ou `--cleanup`.
- Bloqueio dupla camada: `NODE_ENV !== production` E `SUPABASE_URL` precisa conter `szkzkyexagunvadzzaec`.
- Constraints já existem (não foi preciso criar): `tenex_debtors (workspace_id, external_id)` + `tenex_debt_items (workspace_id, debtor_id, external_id)` — ajustei o `onConflict` do debt_items pra incluir `debtor_id`.
- Smoke test: 2 fixtures criados em DEV (`atraso_10d`, `cartao_recusado`).

**3. BRIDGE_TEMPLATE_CHANGE_EVENT.md (DEV)**
- Service novo: `server/src/services/waba/wabaTemplateBridge.service.ts`.
- Controller estendido: `bridgeEvent.controller.ts` agora aceita `type=waba_template_changed` (curto-circuito da validação `conv_display_id` que outros tipos exigem).
- Resolve workspace via `waba_numbers.waba_id`, chama `wabaNumberService.syncTemplates(numberId, workspaceId)`, e em eventos críticos (`REJECTED`, `PAUSED`, `DISABLED`, `PENDING_DELETION`, `FLAGGED`) ou reclassificação pra `MARKETING`: pausa `collection_enrollments` ativos vinculados ao template + envia `Sentry.captureMessage` (level warning) com contexto.
- Schema constraint atual de `collection_enrollments.status` não inclui `paused_template_broken` — usei `'paused'` (válido) e o "porquê" rico vai pro Sentry/log. Se quiser status dedicado, é nova migration + `addBlockedBy` pra rever auto-pause.
- Idempotência: re-sync sobrescreve `last_synced_at`, e o auto-pause filtra `.eq('status','active')` (já-pausados não viram pausados de novo).
- TS compila zero erros.
- Endpoint pronto pra receber payloads do Frontdesk em `https://api-dev.klaos.ai/api/webhooks/klaos/bridge-event` com `X-Bridge-Secret`. Confirmem no lado de vocês: `KLAOS_BRIDGE_URL` e `FRONTDESK_BRIDGE_SECRET` setadas no Frontdesk DEV.

### Commit `055bc6c6` aplicado em PROD após OK explícito do user

**4. SCHEMA_DRIFT_BILLING.md (PROD)**
- `ALTER TABLE collection_campaigns ADD COLUMN permanent_labels text[] NOT NULL DEFAULT '{}'` aplicado em `ddnwemmvsuiibgbzjpwx` (idempotente, < 1s, tabela com 0 rows).
- `CREATE INDEX idx_collection_campaigns_permanent_labels ON collection_campaigns USING gin (permanent_labels)` criado.
- Diagnóstico: `waba_numbers=0` e `waba_templates=0` em PROD são **estado esperado** (cliente WABA Atend Med BH não foi provisionado em prod ainda), não bug de sync. Quando o cliente migrar, segue o passo-a-passo do doc (provision → sync → campaigns).

### Impacto no Frontdesk
- **Bridge handler**: confirmar env vars `KLAOS_BRIDGE_URL=https://api-dev.klaos.ai` e `FRONTDESK_BRIDGE_SECRET=<shared>` no Frontdesk DEV. Em prod, vão precisar `KLAOS_BRIDGE_URL=https://api.klaos.ai`.
- **Teste e2e (sugerido por vocês)**: editar texto de `fatura_emissao` na UI Templates Settings → status volta pra PENDING → webhook Meta dispara → Frontdesk re-sync local + POST pro KLaOS. Esperado: `last_synced_at` em `waba_templates` dentro de ~30s do webhook.
- Cleanup deste round: nada do lado de vocês.

---

## 2026-04-30 — MIGRATE_REGUA_TO_COBR.md aplicado em DEV

Doc `docs/para-klaos-agent/MIGRATE_REGUA_TO_COBR.md` processado. Todos os 7 templates `cobr_*` já APPROVED na Meta foram propagados pra `waba_templates` do KLaOS DEV e a régua das 2 campaigns foi remapeada.

### Migration Supabase: `seed_cobr_templates_dev` + `migrate_regua_to_cobr_dev`

Sem commit em git (mudanças foram via `apply_migration` direto no projeto `szkzkyexagunvadzzaec`).

**Step 1 — Seed `waba_templates`**
7 rows inseridas via UPSERT na nova unique key `(waba_number_id, name, language)` (criada na rodada anterior pra fechar o ciclo do `CLEANUP_WABA_TEMPLATES.md`):

| name | meta_template_id | status |
|---|---|---|
| cobr_d5_lembrete    | 967573122486341    | APPROVED |
| cobr_d0_vencimento  | 26984168144553305  | APPROVED |
| cobr_d1_vencido     | 1892848914751505   | APPROVED |
| cobr_d7_atraso      | 967806542305040    | APPROVED |
| cobr_d15_atraso     | 1483433960183870   | APPROVED |
| cobr_d21_transbordo | 960619686455342    | APPROVED |
| cobr_pagto_ok       | 1254671323072863   | APPROVED |

`components=[]` em todas — sync diário (4h UTC) ou bridge `waba_template_changed` vai popular components reais quando rodar. Não bloqueia a migration; campaigns paused → dispatch não roda.

**Steps 2/3/4 — `collection_sequence_steps`** (atomicamente, em 1 migration)
- DELETE step com `boleto_atraso_10dias` (D+10) em ambas campaigns.
- UPDATE FKs legacy → cobr_* nos 5 mappings: `fatura_lembrete_5dias→cobr_d5_lembrete`, `cobranca_vencimento_hoje→cobr_d0_vencimento`, `cobranca_atraso_5dias→cobr_d7_atraso` (com `day_offset 5→7`), `fatura_atraso_15dias→cobr_d15_atraso`, `fatura_atraso_21dias→cobr_d21_transbordo`.
- INSERT step novo D+1 `cobr_d1_vencido` em ambas campaigns (`due_date_offset`, `stop_condition='on_payment'`, `chatwoot_label='cobranca-1d'`).
- Renumeração `step_order` 1..N por campaign ordenado por `(day_offset asc, trigger_type='enrollment_offset' DESC tiebreaker)`.

### Step 5 — Validação

**Apresentação Gustavo** (paused, 7 steps):
```
1  -5  due_date_offset    cobr_d5_lembrete       lembrete-5d
2   0  enrollment_offset  fatura_emissao         pendente        ← preservado
3   0  due_date_offset    cobr_d0_vencimento     cobranca-0d
4   1  due_date_offset    cobr_d1_vencido        cobranca-1d     ← NOVO
5   7  due_date_offset    cobr_d7_atraso         cobranca-5d     ← era D+5
6  15  due_date_offset    cobr_d15_atraso        cobranca-15d
7  21  due_date_offset    cobr_d21_transbordo    cobranca-21d
```

**Demo Cliente — Régua WABA** (paused, 6 steps, handoff preservado em D+21):
```
1   0  enrollment_offset  fatura_emissao         pendente            ← preservado
2   0  due_date_offset    cobr_d0_vencimento     cobranca-0d
3   1  due_date_offset    cobr_d1_vencido        cobranca-1d         ← NOVO
4   7  due_date_offset    cobr_d7_atraso         cobranca-5d         ← era D+5
5  15  due_date_offset    cobr_d15_atraso        cobranca-15d
6  21  due_date_offset    cobr_d21_transbordo    transbordo-humano   (is_handoff_step=true)
```

### Notas / coisas pra atenção do Frontdesk

1. **`fatura_emissao` preservado** nos dois primeiros steps "D+0 enrollment_offset" das duas campaigns. Não está no `PLANO_TEMPLATES_META_FINAL.md` do Gustavo, mas o `MIGRATE_REGUA_TO_COBR.md` também não pediu remoção. Não toquei. Se for pra remover/substituir, mande novo doc com SQL específico ou eu olho com vocês.
2. **`chatwoot_label` herdado** — o step que era D+5 (`cobranca-5d`) hoje aponta D+7 com `cobr_d7_atraso`, mas mantive o label original. Não afeta dispatch (label é só pro Chatwoot/UI), mas se quiser renomear pra `cobranca-7d` é ajuste cosmético — me digam.
3. **`components=[]`** nas 7 rows cobr_*. Quando o Frontdesk POSTar `waba_template_changed` pra `KLAOS_BRIDGE_URL/api/webhooks/klaos/bridge-event` (mecanismo do round anterior), o handler vai chamar `wabaNumberService.syncTemplates` e popular components reais. Alternativa: aguardar sync diário 4h UTC.
4. **Campaigns continuam `paused`** — nada de auto_enroll, nada de active, nada de enrollments criados. Conforme guard rails do briefing.
5. **Templates legacy ainda em `waba_templates`** — não dropei (guard rail). Frontdesk deleta via Meta API → sync rasga sozinho.

Pronto pro teste e2e com fixture `+5521964798660` (rake `klaos:billing:seed_test_client` ↔ `npm run billing:seed-test-debtor` no KLaOS) quando quiser, com triple-guard do `TEST_SAFETY_GUARDS.md`.

---

## 2026-04-30 — REGUA_CARTAO_E_LARA_FIX.md aplicado em DEV

Doc `docs/para-klaos-agent/REGUA_CARTAO_E_LARA_FIX.md` processado. Todas as 4 ações executadas via `apply_migration` no Supabase DEV (`szkzkyexagunvadzzaec`). Sem commit no repo klaos — mudanças foram só DDL/DML.

### Migrations aplicadas
- `dev_drop_fatura_emissao_steps`
- `dev_add_filter_meio_pagamento_and_create_regua_cartao`
- (`UPDATE` direto pra Lara prompt — sem migration)

### Ação 1 — DROP `fatura_emissao` ✅

DELETE 2 rows (Apresentação Gustavo step 2 + Demo Cliente step 1). Renumeração `step_order` 1..N por campaign.

`fatura_emissao_usage = 0` confirmado. **Frontdesk pode finalizar DELETE do template legacy `fatura_emissao` na Meta API + sync.**

Régua final pós-Ação 1:
- **Apresentação Gustavo** (paused, filter `[2]`, 6 steps): -5 d5 / 0 d0 / 1 d1 / 7 d7 / 15 d15 / 21 d21
- **Demo Cliente — Régua WABA** (paused, filter `[2]`, 5 steps): 0 d0 / 1 d1 / 7 d7 / 15 d15 / 21 d21 (handoff em D+21 preservado)

### Ação 2a — Schema `filter_meio_pagamento_tipo` ✅

```sql
ALTER TABLE collection_campaigns ADD COLUMN filter_meio_pagamento_tipo integer[] NOT NULL DEFAULT '{}';
CREATE INDEX idx_collection_campaigns_filter_meio_pagamento_tipo ON ... USING gin (...);
```

Semântica: array `'{}'` = sem filtro (aceita qualquer modalidade — comportamento legado preservado por default); array com valores = só essas modalidades. NULL handling de `meio_pagamento_tipo` fica a critério do dispatcher (a definir após Ação 4).

### Ação 2b — Filtro nas campaigns boleto ✅

`filter_meio_pagamento_tipo = ARRAY[2]` em Apresentação Gustavo + Demo Cliente. Os 2418 nulls (mais detalhes na Ação 4) + 15 cartão tipo 11 + 2 PIX tipo 6 NÃO entram nessas réguas até decisão de produto. Comportamento conservador: zero risco de tocar cartão na régua errada.

### Ação 2c — Régua Cartão criada ✅

**7 rows seedadas em `waba_templates`** com `status='PENDING'` (estado real — Meta ainda não aprovou):

| name | meta_template_id |
|---|---|
| cobr_card_d5_lembrete    | 2001794427103401 |
| cobr_card_d0_vencimento  | 982392961155241 |
| cobr_card_d1_recusado    | 1274433947657535 |
| cobr_card_d7_atraso      | 934853362713163 |
| cobr_card_d15_atraso     | 750587544711681 |
| cobr_card_d21_transbordo | 5414433888782575 |
| cobr_card_pagto_ok       | 1450363883504132 |

Quando approval chegar, sync diário (4h UTC) ou bridge `waba_template_changed` atualiza `status` pra APPROVED.

**Campaign `Régua Cartão`** (paused, auto_enroll=false, filter `[1, 11, 12]`, filter_min_days_overdue=-5, filter_has_active_plan=true).

**6 steps inseridos** (cobr_card_pagto_ok event-driven, fora):
```
1  -5  due_date_offset    cobr_card_d5_lembrete      cartao-lembrete-5d
2   0  due_date_offset    cobr_card_d0_vencimento    cartao-cobranca-0d
3   1  due_date_offset    cobr_card_d1_recusado      cartao-recusado-1d
4   7  due_date_offset    cobr_card_d7_atraso        cartao-cobranca-7d
5  15  due_date_offset    cobr_card_d15_atraso       cartao-cobranca-15d
6  21  due_date_offset    cobr_card_d21_transbordo   cartao-transbordo  (is_handoff_step=true)
```

`stop_condition`: `on_payment` em todos os steps regulares; `on_handoff` no step de transbordo.

### Ação 3 — Lara `collection_system_prompt` atualizado ✅

Substituição focada nas regras 1 e 3 (modalidades), mantendo regras 2/4/5/6 intactas. Antes só `boleto e/ou PIX`; agora inclui `Link de atualização de cartão` pra modalidade cartão recorrência.

Aplicado direto em `agent_instances` (id `1b092e03-...`, status active). Verificado: `agent_collection_prompt_versions` table NÃO existe — sem mecanismo de versionamento. Diferente de `system_prompt` que tem `agent_prompt_versions` com is_active. UPDATE em `collection_system_prompt` é efetivo imediatamente.

### Ação 4 — Findings sobre `meio_pagamento_tipo IS NULL`

Investigação revelou **bug de sync** no campo `meio_pagamento_tipo`, com proxies confiáveis pra inferir modalidade.

**Quantitativos** (com filtro: `status != 'paid'` AND `phone_e164 IS NOT NULL`):

| Métrica | Valor |
|---|---|
| Total de itens com `meio_pagamento_tipo IS NULL` | **2418** |
| Com `tenex_data->>'meio_pagamento_tipo'` populado | **0** (zero!) |
| Com `tenex_data` populado mas sem o campo `tipo` | 2418 (100%) |
| Com `linha_digitavel IS NOT NULL` (proxy: boleto) | 1049 (43%) |
| Com `pix_codigo IS NOT NULL` (proxy: PIX) | 577 (24%) |
| Com `pagamento_online_codigo IS NOT NULL` (proxy: cartão) | 1317 (54%) |

(Há overlap — alguns itens têm múltiplos canais.)

**Achado-chave (sample inspecionado):** `Selma Maria Leite` tem `meio_pagamento_id=12` mas `meio_pagamento_tipo=NULL`. A coluna `id` veio do tenex, mas o `tipo` não. Quando o `tipo` deveria ser derivável via `tenex_credentials.meio_pagamento_map[id] -> tipo`. **Bug de sync confirmado.**

**Caminhos pra decisão de produto:**

| Opção | Implementação | Risco |
|---|---|---|
| **A — Backfill via `meio_pagamento_id` lookup** | `UPDATE tenex_debt_items SET tipo = lookup(meio_pagamento_id)` quando `id IS NOT NULL AND tipo IS NULL` | Baixo — fonte mesmo do tenex. Cobre os com `id` populado. |
| **B — Backfill por proxy de campos** | `tipo = 2 (boleto)` quando `linha_digitavel IS NOT NULL`; `tipo = 6 (PIX)` quando `pix_codigo IS NOT NULL`; `tipo = 11 (cartão)` quando `pagamento_online_codigo IS NOT NULL` (com tiebreaker — boleto+PIX coexistem) | Médio — proxies não são contrato. Boleto e PIX coexistem, regra de tiebreaker importa. |
| **C — Aceitar NULL como "qualquer"** | Ajustar dispatcher pra incluir `meio_pagamento_tipo IS NULL` no match das campaigns boleto. Régua Cartão não pega esses casos. | Alto — manda boleto pra clientes cartão recorrência misturados nos nulls. |
| **D — Fix do sync upstream** | Investigar `tenexConnector.service.ts` (sync), garantir que sempre tagueie `tipo` baseado no `id` ou no map. | Mais correto, mas não retroativo — só fixa novos. |

**Recomendação:** A + D combinados. A resolve histórico, D evita re-acúmulo. Aguardo decisão antes de aplicar.

### Estado final do workspace (validação)

| Campaign | Status | auto_enroll | filter_meio | n_steps |
|---|---|---|---|---|
| Apresentação Gustavo | paused | false | `{2}` | 6 |
| Demo Cliente — Régua WABA | paused | false | `{2}` | 5 |
| Régua Cartão | paused | false | `{1,11,12}` | 6 |

**Guards respeitados:** todas paused, `auto_enroll=false`, zero `collection_enrollments` criados, zero DELETE em `waba_templates` legacy. Frontdesk roda DELETE legacy (`fatura_emissao` + 7 ms24h_*) via Meta API quando confirmar.

### Pendentes do lado Frontdesk
1. DELETE `fatura_emissao` na Meta API + sync (KLaOS confirmou 0 uso).
2. Aguardar approval dos 7 `cobr_card_*` PENDING. Quando aprovados: bridge `waba_template_changed` atualiza KLaOS automaticamente (handler do round 1).
3. Decisão de produto sobre Ação 4 (caminhos A/B/C/D acima).

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
