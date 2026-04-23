# SDD — Política de Reabertura de Conversas (modular, por tenant)

| Campo | Valor |
|---|---|
| Status | **Draft — aguarda decisão do dono do produto + implementação** |
| Prioridade | 🔴 Crítica |
| Responsável | Agente KLaOS (nova lógica na pipeline de mensagem) + Frontdesk agent (botão + timestamp — ver pasta `para-frontdesk-agent`) |
| Autor | Matheus + Frontdesk agent |
| Data | 2026-04-23 |

## Contexto

Quando o cliente retorna numa conversa resolvida:
- **Mesmo dia, em janela X** → atribuir ao humano original (ou fallback do time dele)
- **Após janela X (dia seguinte ou depois)** → devolver pro bot

Hoje o Chatwoot sempre devolve pro humano original (assignee preservado), independente de tempo. Resultado: conversa fica parada se humano estiver offline/férias.

## Decisões pendentes (bloqueadoras)

- **DP-1**: Janela = 24h default? Configurável por workspace? *Minha recomendação: sim, `workspaces.settings.reopen_window_minutes` default 1440.*
- **DP-2**: Regra aplica a toda conversa resolvida ou só as que passaram por handoff bot→humano? *Rec: toda conversa.*
- **DP-3**: Fallback quando agente original offline e dentro da janela: próximo online do mesmo team? *Rec: sim, com `team_id` preservado.*
- **DP-4**: "Online" = `availability_status = 'online'` no Chatwoot. *Rec: só isso.*
- **DP-5**: Ativar globalmente ou opt-in por workspace? *Rec: opt-in via `workspace_feature_flags.flag_name = 'reopen_policy_enabled'`.*

## O que já existe no KLaOS (reutilizar)

### `agent_conversations` (tabela viva — 235 rows no DEV)
Colunas relevantes JÁ presentes:
- `status` (active, resolved, handed_off, etc.)
- `handoff_at`, `handoff_reason`, `handoff_requested_at`
- `resolved_at`, `resolved_by_user_id`
- `assigned_to_user_id`
- `last_message_at`, `last_user_message_at`
- `chatwoot_conversation_id`, `desk_conversation_id`, `chatwoot_contact_id`, `chatwoot_inbox_id`

**Basta adicionar 1 campo** novo:
- `reactivation_at timestamp` — calculado em `resolved_at + reopen_window`. Consultado quando nova msg entra.

### `agent_handoff_config`
Já existe `timeout_seconds`, `timeout_minutes`, etc. Adicionar:
- `reopen_window_minutes integer DEFAULT 1440` (24h)

### `workspaces.settings` (jsonb)
Adicionar chave `reopen_policy`:
```json
{
  "reopen_policy": {
    "window_minutes": 1440,
    "fallback_to_team": true,
    "fallback_to_bot_after_window": true
  }
}
```

### `workspace_feature_flags`
Criar row:
```sql
INSERT INTO workspace_feature_flags (workspace_id, flag_name, enabled)
VALUES ('<workspace_id>', 'reopen_policy_enabled', true);
```

## Arquitetura — 3 hooks no pipeline KLaOS

### Hook 1 — `conversation_resolved` do Chatwoot

Quando chegar webhook `conversation_resolved`:
```ts
async function onConversationResolved(event) {
  const agentConv = await getAgentConversationByDeskId(event.conversation.id);
  if (!agentConv) return;

  const ws = await getWorkspace(agentConv.workspace_id);
  const flag = await getFeatureFlag(ws.id, 'reopen_policy_enabled');
  if (!flag) return; // não ativou opt-in

  const windowMin = ws.settings?.reopen_policy?.window_minutes
    ?? 1440;

  await supabase.from('agent_conversations').update({
    resolved_at: event.timestamp,
    resolved_by_user_id: event.resolved_by_user_id,
    reactivation_at: new Date(Date.now() + windowMin * 60_000).toISOString(),
    status: 'resolved',
  }).eq('id', agentConv.id);
}
```

### Hook 2 — `message_created` (incoming) numa conv resolvida

```ts
async function onIncomingMessage(event) {
  const agentConv = await getAgentConversationByDeskId(event.conversation.id);
  if (!agentConv) return;

  if (agentConv.status !== 'resolved') return; // fluxo normal

  const ws = await getWorkspace(agentConv.workspace_id);
  const flag = await getFeatureFlag(ws.id, 'reopen_policy_enabled');
  if (!flag) return;

  const now = new Date();
  const reactivationAt = new Date(agentConv.reactivation_at);

  if (now >= reactivationAt) {
    // Passou janela → devolver pro bot
    await returnToBot(agentConv, event);
  } else {
    // Dentro da janela → tentar agente original, fallback pro team
    await tryRouteToHuman(agentConv, event);
  }
}

async function returnToBot(agentConv, event) {
  const account = await getFrontdeskAccount(agentConv.workspace_id);
  await frontdeskAccountApi.toggleStatus(account.chatwoot_account_id, agentConv.desk_conversation_id, 'pending');
  await frontdeskAccountApi.unassign(account.chatwoot_account_id, agentConv.desk_conversation_id);

  await supabase.from('agent_conversations').update({
    status: 'active',
    resolved_at: null,
    reactivation_at: null,
  }).eq('id', agentConv.id);

  // Postar nota privada explicando
  await frontdeskAccountApi.postPrivateNote(
    account.chatwoot_account_id,
    agentConv.desk_conversation_id,
    '[reopen-policy] janela expirada — conversa devolvida ao bot'
  );

  // Continua o processing normal da msg → bot responde
  await processIncomingMessage(agentConv, event);
}

async function tryRouteToHuman(agentConv, event) {
  const originalUserId = agentConv.assigned_to_user_id; // última atribuição antes de resolver

  const isOnline = originalUserId
    ? await frontdeskAccountApi.isUserOnline(originalUserId)
    : false;

  if (isOnline) {
    // Reatribui ao mesmo
    await frontdeskAccountApi.toggleStatus(account.chatwoot_account_id, agentConv.desk_conversation_id, 'open');
    await frontdeskAccountApi.assignUser(account.chatwoot_account_id, agentConv.desk_conversation_id, originalUserId);
    await updateAgentConvStatus(agentConv.id, 'handed_off');
    return;
  }

  // Fallback: qualquer online do mesmo team
  const teamId = await getLastTeamId(agentConv); // grava quando handoff aconteceu
  const fallbackUser = teamId
    ? await frontdeskAccountApi.findOnlineUserInTeam(account.chatwoot_account_id, teamId)
    : null;

  if (fallbackUser) {
    await frontdeskAccountApi.assignUser(account.chatwoot_account_id, agentConv.desk_conversation_id, fallbackUser.id);
    await postPrivateNote(account, agentConv, `[reopen-policy] agente original offline, fallback pra ${fallbackUser.name}`);
    return;
  }

  // Ninguém online no team → vai pro bot
  await returnToBot(agentConv, event);
}
```

### Hook 3 — timer de reativação (opcional, não bloqueante)

Cron job a cada 5 min: varre `agent_conversations WHERE status='resolved' AND reactivation_at <= NOW()` e devolve pro bot proativamente. Isso resolve o caso onde cliente **não manda msg** mas queremos recuperar bots pra caixa "Ativas" do admin.

**Não é crítico — pode ser feito na v2.**

## Migração SQL (schema)

```sql
-- 1. Campo novo em agent_conversations
ALTER TABLE agent_conversations
  ADD COLUMN IF NOT EXISTS reactivation_at timestamp with time zone;
CREATE INDEX IF NOT EXISTS idx_agent_conv_reactivation
  ON agent_conversations (reactivation_at) WHERE status = 'resolved';

-- 2. Campo em agent_handoff_config (opcional — pode usar só workspaces.settings)
ALTER TABLE agent_handoff_config
  ADD COLUMN IF NOT EXISTS reopen_window_minutes integer DEFAULT 1440;

-- 3. Feature flag pra Mais Saúde DEV (exemplo opt-in)
INSERT INTO workspace_feature_flags (workspace_id, flag_name, enabled)
VALUES ('9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'reopen_policy_enabled', true)
ON CONFLICT DO NOTHING;

-- 4. Config default Mais Saúde
UPDATE workspaces
SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
  'reopen_policy', jsonb_build_object(
    'window_minutes', 1440,
    'fallback_to_team', true,
    'fallback_to_bot_after_window', true
  )
)
WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

## Dependência do Frontdesk agent

- Botão "Devolver ao bot" na sidebar da conversa — ver `../para-frontdesk-agent/SDD_TRANSFER_TO_BOT_BUTTON.md`
- Endpoint `POST /api/v1/accounts/:id/conversations/:id/transfer_to_bot` — ver `../para-frontdesk-agent/SDD_TRANSFER_TO_BOT_API.md`
- Esse endpoint DEVE chamar webhook pro KLaOS: `POST /api/webhooks/klaos/bridge-event {type: 'manual_transfer_to_bot', conv_display_id, workspace_id}`

KLaOS tem que:
- Criar rota `/api/webhooks/klaos/bridge-event`
- Ao receber `manual_transfer_to_bot`, setar `agent_conversations.status='active'`, `reactivation_at=null`, `resolved_at=null`, `assigned_to_user_id=null`
- Responder 200 ack

## Critérios de sucesso

- [ ] Feature flag opt-in funcional
- [ ] Cenário A testado: cliente volta em <24h com agente online → agente original recebe
- [ ] Cenário B testado: cliente volta em <24h com agente offline → fallback team
- [ ] Cenário C testado: cliente volta em >24h → bot assume
- [ ] Cenário D testado: ninguém online → bot assume
- [ ] Cenário E testado: humano clica "Devolver ao bot" → bot assume imediato

Ver `../shared/PLANO_TESTES_INTEGRACAO.md` §6.5 pra TCs formalizados.
