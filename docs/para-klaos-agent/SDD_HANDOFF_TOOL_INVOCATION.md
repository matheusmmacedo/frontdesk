# SDD — Invocação real da tool `transferir_para_time`

| Campo | Valor |
|---|---|
| Status | **Draft — aguarda implementação** |
| Prioridade | 🔴 Crítica |
| Responsável | Agente KLaOS |
| Autor | Matheus + investigação Frontdesk |
| Data | 2026-04-23 |

## Problema

**Lara (e provavelmente os outros agents) só RESPONDEM TEXTO dizendo "vou transferir" mas NÃO invocam a tool `transferir_para_time`.** Resultado: conversa fica `pending` sem assignee, cliente espera pra sempre.

## Evidência direta do DB

Conv 151 (workspace Mais Saúde DEV `9838d25b-60de-45e7-b7b7-31cc56b12ccc`):
- `agent_conversations.handoff_reason` = **NULL**
- `agent_conversations.handoff_at` = **NULL**
- `agent_conversations.handoff_requested_at` = **NULL**
- `agent_conversations.assigned_to_user_id` = **NULL**
- Mas: mensagem da Lara 10292 diz: *"Vou te transferir para o setor de cancelamentos e contratos, por gentileza aguardar."*

Confirmado: ação manual (só texto) sem chamada da tool.

## O que já existe (reutilizar)

### Tool `transferir_para_time`
Já cadastrada em `agent_tool_definitions`. Aceita:
```json
{
  "type": "object",
  "required": ["team_name", "reason"],
  "properties": {
    "reason": { "type": "string" },
    "team_name": { "type": "string", "description": "Nome do time: contratos, boletos, cancelamento, suporte" }
  }
}
```

### Habilitação da Lara
`agent_instance_tools` linha `is_enabled=true` pro `tool_definition_id` do `transferir_para_time`. Confirmado.

### Config do handoff
`agent_handoff_config` pra Lara:
- `auto_handoff_enabled: true`
- `handoff_triggers.keywords` — 24 frases de intenção
- `trigger_keywords` — 5 frases legadas
- `confidence_threshold: 0.70`
- `timeout_seconds: 900`

### Dados de destino
- `workspaces.closer_team_id` — hoje = 2 (team cobrança). Será usado como **fallback default** na arquitetura nova.
- Novos teams criados no Chatwoot Mais Saúde: **team 6 "Cancelamento"** (Gustavo é membro).

## Solução

### Parte 1 — Ajuste de prompt (imediato, sem deploy de código)

No `agent_instances.system_prompt` da Lara, a seção 10 diz:
```
Mensagem:
Vou te transferir para o setor de contratos gentileza aguardar.
```

**Adicionar regra explícita**: `IMPORTANTE: sempre que você enviar essa mensagem de transferência, você DEVE invocar a tool \`transferir_para_time\` no MESMO turno. A mensagem SOZINHA não executa o handoff — o sistema depende da chamada da tool.`

Repetir essa regra nas seções:
- A (cadastro inativo)
- 8 (quando cliente quer cancelar)
- 11 (tipos de transferência)
- 21 exemplo 3
- 22 (comprovante ilegível)

### Parte 2 — Guardrail no runtime (código)

Mesmo com prompt ajustado, LLM às vezes esquece a tool. Implementar **guardrail determinístico**:

```ts
// Em agentBufferProcessor.service.ts (ou onde roda o loop de completion)
const HANDOFF_KEYWORDS = /\b(transferir|encaminhar|setor de|atendente|humano)\b/i;

async function afterAiResponse(message: string, toolCallsInTurn: ToolCall[], context: Context) {
  const hasHandoffText = HANDOFF_KEYWORDS.test(message);
  const hasHandoffCall = toolCallsInTurn.some(c => c.name === 'transferir_para_time');

  if (hasHandoffText && !hasHandoffCall) {
    logger.warn('[HandoffGuard] Bot said handoff text but did NOT call transferir_para_time', {
      agentInstanceId: context.agentInstanceId,
      conversationId: context.chatwootConversationId,
      textSnippet: message.slice(0, 100),
    });

    // Inferir team_name do texto (regex simples ou LLM secundário)
    const inferredTeam = inferTeamFromMessage(message); // "cancelamento" | "contratos" | null

    if (inferredTeam) {
      // Auto-executar tool com inferência
      await executeToolCall('transferir_para_time', {
        team_name: inferredTeam,
        reason: 'auto-recovery: text sent but tool not called',
      }, context);
    } else {
      // Sem inferência confiável — alerta operacional
      await notifyOps({
        severity: 'warn',
        title: 'Handoff inferido sem tool call',
        context,
      });
    }
  }
}
```

### Parte 3 — Resolver `team_name` → `team_id` em multi-tenant

Tool recebe `team_name` (string). No executor:

```ts
// Tabela de mapeamento por workspace (nova — ver SDD_HANDOFF_ROUTING.md)
// Fallback: buscar team por nome no Chatwoot account do workspace

async function resolveTeamId(workspaceId: string, teamName: string): Promise<number | null> {
  // 1. Checa workspaces.settings.handoff_team_map
  const ws = await getWorkspace(workspaceId);
  const mapFromSettings = ws.settings?.handoff_team_map?.[teamName.toLowerCase()];
  if (mapFromSettings) return mapFromSettings;

  // 2. Fallback: buscar no Chatwoot account do workspace por nome aproximado
  const account = await getFrontdeskAccount(workspaceId);
  const teams = await frontdeskAccountApi.listTeams(account.chatwoot_account_id);
  const match = teams.find(t => t.name.toLowerCase().includes(teamName.toLowerCase()));
  return match?.id ?? null;
}
```

Config de `handoff_team_map` por workspace (ver SDD_HANDOFF_ROUTING.md).

### Parte 4 — Execução bloqueante do handoff

Substituir o atual "non-blocking com logger.warn" por retry com rollback:

```ts
async function executeTransferirParaTime(params, context) {
  const teamId = await resolveTeamId(context.workspaceId, params.team_name);
  if (!teamId) {
    throw new HandoffError(`Team não encontrado: ${params.team_name}`);
  }

  const convDisplayId = context.deskConversationId; // display_id do Chatwoot
  const accountId = context.chatwootAccountId;

  // PATCH 1: status → open
  await frontdeskAccountApi.toggleStatus(accountId, convDisplayId, 'open', { retries: 3 });

  // PATCH 2: atribuir team
  await frontdeskAccountApi.assignTeam(accountId, convDisplayId, teamId, { retries: 3 });

  // PATCH 3: nota privada
  await frontdeskAccountApi.postPrivateNote(accountId, convDisplayId, `[handoff] ${params.reason}`);

  // DB: gravar estado
  await supabase.from('agent_conversations').update({
    handoff_at: new Date().toISOString(),
    handoff_reason: params.reason,
    status: 'handed_off',
    assigned_to_user_id: null, // team level
  }).eq('id', context.agentConversationId);

  return { success: true, team_id: teamId, team_name: params.team_name };
}
```

Se qualquer PATCH falhar depois do retry → exceção propaga → LLM recebe erro → pode tentar de novo ou avisar cliente. **Não silenciar.**

## Critérios de sucesso

- [ ] Prompt da Lara atualizado com regra explícita de tool
- [ ] Guardrail implementado em `agentBufferProcessor.service.ts`
- [ ] Tool executor usa `resolveTeamId` multi-tenant
- [ ] Execução bloqueante com rollback
- [ ] Teste manual: mandar "quero cancelar" na Lara → confirmar:
  - Lara responde texto + chama tool
  - `agent_conversations.handoff_at` preenchido
  - `conversations.team_id = 6` no Chatwoot (Cancelamento)
  - Nota privada aparece na conversa

## Dependências

- **SDD_HANDOFF_ROUTING.md** — precisa ser feito em paralelo (mapa `intent → team_id`)
- **SDD_DESK_CONVERSATION_ID_BACKFILL.md** — precisa antes pra ter `desk_conversation_id` confiável

## Rollout

1. Dev: merge branch `handoff-tool-enforcement`, teste com Lara/Mais Saúde
2. Validação QA: Davi roda TC-796 (handoff completo) do plano Integração
3. Rollout gradual: habilitar pro Klaus (GMB), Iris, Klaus Ross
4. Monitorar 1 semana `handoff_at` sendo preenchido em 100% dos casos que o bot menciona "transferir"
