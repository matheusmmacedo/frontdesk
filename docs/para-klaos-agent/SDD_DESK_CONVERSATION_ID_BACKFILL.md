# SDD — Backfill de `desk_conversation_id` em `agent_conversations`

| Campo | Valor |
|---|---|
| Status | **Draft** |
| Prioridade | 🟡 Alta |
| Responsável | Agente KLaOS |
| Data | 2026-04-23 |

## Problema

A coluna `agent_conversations.desk_conversation_id` (tipo `text`) está **NULL** em todos os rows existentes. O dado correto (display_id do Chatwoot) está em `platform_metadata->>'desk_conversation_id'`.

## Evidência

Conv 151 (Mais Saúde DEV):
```
desk_conversation_id: null                                   ❌
platform_metadata.desk_conversation_id: 33                   ✅
chatwoot_conversation_id: 151                                (id interno)
```

## Por que importa

O fix do agente de ontem (`9837d52a`) adaptou o `agentMessageDelivery` pra ler do `platform_metadata` primeiro. Funciona, mas a coluna dedicada continua inconsistente. Qualquer código novo que use `desk_conversation_id` direto quebra. Além disso, queries de debug/analytics ficam ambíguas.

## Solução

### Backfill (único SQL)
```sql
UPDATE agent_conversations
SET desk_conversation_id = platform_metadata->>'desk_conversation_id'
WHERE desk_conversation_id IS NULL
  AND platform_metadata->>'desk_conversation_id' IS NOT NULL;
```

Deve rodar em todos os workspaces (dev + prod).

### Write path — novos inserts
Toda vez que um webhook do Chatwoot cria/atualiza `agent_conversations`, gravar **nas duas localizações**:
```ts
await supabase.from('agent_conversations').upsert({
  id,
  chatwoot_conversation_id: payload.conversation.id,
  desk_conversation_id: payload.conversation.display_id?.toString(), // ← coluna dedicada
  platform_metadata: {
    ...metadata,
    desk_conversation_id: payload.conversation.display_id, // ← jsonb (redundância por compat)
  },
});
```

### Transição
Depois de 1-2 semanas com write path duplo e backfill aplicado, o `platform_metadata.desk_conversation_id` pode ser deprecated em favor da coluna dedicada. Manter só a coluna dedicada.

## Critérios de sucesso

- [ ] Backfill rodado em DEV sem erro; todas as rows com `chatwoot_conversation_id != null` têm `desk_conversation_id` preenchido
- [ ] Backfill rodado em PROD
- [ ] Write path atualizado em `handleWebhook` / `ensureAgentConversation`
- [ ] Spot-check: query `SELECT COUNT(*) FROM agent_conversations WHERE desk_conversation_id IS NULL AND chatwoot_conversation_id IS NOT NULL` retorna 0
