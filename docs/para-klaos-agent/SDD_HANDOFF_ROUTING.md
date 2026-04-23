# SDD — Roteamento de handoff por intent (team_id por tenant)

| Campo | Valor |
|---|---|
| Status | **Draft** |
| Prioridade | 🔴 Crítica (dependência do `SDD_HANDOFF_TOOL_INVOCATION.md`) |
| Responsável | Agente KLaOS |
| Data | 2026-04-23 |

## Problema

Tool `transferir_para_time` recebe `team_name` (string livre: "contratos", "boletos", "cancelamento", "suporte"). Hoje não há mapa de `team_name → team_id` por workspace. Resultado: handoff cai em team errado OU cai em limbo.

Também: `workspaces.closer_team_id` é **um só** team — genérico. Cada tenant tem times diferentes pra intents diferentes.

## Exemplo real (Mais Saúde)

Teams no Chatwoot account 10:
| team_id | name |
|---|---|
| 1 | vendas |
| 2 | cobrança |
| 3 | consultas e exames |
| 4 | contratos e cancelamentos |
| **6** | **Cancelamento** (novo, criado 2026-04-23 pra Gustavo) |

Quando a Lara chama `transferir_para_time({team_name: "cancelamento"})`, qual team? 6 ou 4?

Sem config, cai num match fuzzy de nome → resultado incerto.

## Solução — mapa por workspace em `settings.handoff_team_map`

```json
{
  "settings": {
    "handoff_team_map": {
      "cancelamento": 6,
      "contratos": 4,
      "cobranca": 2,
      "boletos": 2,
      "vendas": 1,
      "consultas": 3,
      "suporte": 2,
      "default": 2
    }
  }
}
```

Chave é o `team_name` que o LLM usa (lowercase, sem acento idealmente). Valor é o `team_id` do Chatwoot daquele workspace.

## Resolve path no runtime

```ts
async function resolveTeamId(workspaceId: string, teamName: string): Promise<number> {
  const key = normalize(teamName); // lowercase, sem acento, replace espaços por '-'

  // 1. Config explícita
  const ws = await getWorkspace(workspaceId);
  const map = ws.settings?.handoff_team_map ?? {};
  if (map[key]) return map[key];

  // 2. Fallback default do workspace
  if (map.default) return map.default;

  // 3. Fallback global (último recurso): closer_team_id legado
  if (ws.closer_team_id) return ws.closer_team_id;

  // 4. Último recurso: fuzzy match no Chatwoot
  const account = await getFrontdeskAccount(workspaceId);
  const teams = await frontdeskAccountApi.listTeams(account.chatwoot_account_id);
  const fuzzy = teams.find(t => normalize(t.name).includes(key));
  if (fuzzy) {
    logger.warn('[HandoffRouting] used fuzzy team match', {
      workspaceId, teamName, matchedTeam: fuzzy.name
    });
    return fuzzy.id;
  }

  throw new Error(`Team não roteável: workspace=${workspaceId} team_name=${teamName}`);
}
```

## Migração de dados — Mais Saúde DEV

```sql
UPDATE workspaces
SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
  'handoff_team_map', jsonb_build_object(
    'cancelamento', 6,
    'contratos', 4,
    'cobranca', 2,
    'boletos', 2,
    'vendas', 1,
    'consultas', 3,
    'suporte', 2,
    'default', 2
  )
)
WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

## UI / config

V1: config manual via SQL / Supabase UI.
V2: tela em `/klaos-control-panel/workspace-settings/handoff-routing` pra admin configurar drag-drop `team_name → Chatwoot team`.

## Multi-tenant enforcement

`team_map` sempre escopado por `workspace_id`. Nenhum valor hardcoded global. Quando cria workspace novo:
- Sync teams do Chatwoot ao provisionar → popular `handoff_team_map` com os nomes detectados
- Admin ajusta via UI conforme necessidade

## Critérios de sucesso

- [ ] Mais Saúde DEV com `handoff_team_map` populado
- [ ] `resolveTeamId` implementado com prioridade: explicit > default > legacy > fuzzy
- [ ] Teste: Lara chama `transferir_para_time({team_name: "cancelamento"})` → conversa vai pro team 6 (Gustavo) ✅
- [ ] Teste: `team_name` desconhecido → cai no default (team 2) + log warning
- [ ] Rollout: popular mapa pros outros workspaces (GMB, Atend Med, E-Cassini) antes de ativar a enforcement
