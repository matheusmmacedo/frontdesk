# BUG — Pipeline `crm_contacts.ai_memory` não popula em PROD (Mais Saúde)

| Campo | Valor |
|---|---|
| Status | **Reportado — aguarda investigação no KLaOS** |
| Prioridade | 🟡 Média (degrada qualidade Lara mas não trava atendimento) |
| Descoberto | 2026-05-08 |
| Workspace | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` (Mais Saúde 24h) |
| Frontdesk account | acct=9 (PROD) |

## Sintoma

Lara não tem **memória cross-conversation**. Quando cliente abre nova conv chatwoot (após resolve da anterior), Lara começa do zero — esquece nome, CPF, promessas, contexto.

## Estado verificado em PROD (KLaOS Supabase `ddnwemmvsuiibgbzjpwx`)

```sql
SELECT * FROM workspace_feature_flags
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND flag_name = 'contact_memory_enabled';
-- ✅ enabled=true desde 2026-05-01
```

```sql
SELECT
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE ai_memory IS NOT NULL AND ai_memory != '{}'::jsonb) AS with_memory,
  COALESCE(SUM(jsonb_array_length(COALESCE(ai_memory->'summaries', '[]'::jsonb))), 0) AS total_summaries
FROM crm_contacts
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND deleted_at IS NULL;
-- ⚠️ total=35, with_memory=0, total_summaries=0
```

**Feature flag ON, mas zero contatos com memória.** Convs resolvidas existem (vários contatos do cobrança fluxo, ex: Kennya conv 93, Yasmin conv 96), mas o pipeline de memória nunca rodou.

## Pipeline esperado (lendo o código)

Caminho `agent_conversation` → resolved → memory append:

1. **`reopenPolicy.service.ts:137-144`** chama `contactMemoryService.appendConversationSummary({workspaceId, contactId, conversationId, resolvedAt, summary})`
2. **Origem do `summary`** (linha 122-134): primeiro tenta `crm_deal_notes.content` (mais recente do deal), fallback pra `crm_deals.notes`
3. **`crm_deal_notes`** é populado por `dealSummaryUpdater.upsertStructuredDealNote` (chamado em `dealSummaryUpdater.service.ts:201-209`)
4. **`dealSummaryUpdater.updateDealSummary`** é chamado em `agentBufferProcessor.service.ts:616` por trigger `'message_count'` (a cada N mensagens)

## Hipóteses pra investigar (em ordem de probabilidade)

### H1 — `reopenPolicy.service` nunca dispara em PROD
A trigger pra resolved depende do webhook chatwoot `conversation_status_changed` (status='resolved') chegar no KLaOS e o pipeline reopenPolicy ser chamado. Conferir:
- `reopenPolicy.service` é importado/chamado em algum handler de webhook?
- Se sim, o `chatwootBotWebhook.controller.ts` ou `frontdeskAccountWebhook.controller.ts` trata `conversation_status_changed` chamando reopenPolicy?

```bash
grep -rn 'reopenPolicy\|reopen_policy' /c/dev/gmb/klaos/server/src
```

### H2 — `crm_deal_notes` está vazio (raíz do problema é dealSummaryUpdater)
Conferir em `ddnwemmvsuiibgbzjpwx`:
```sql
SELECT
  COUNT(*) AS total_notes,
  COUNT(DISTINCT deal_id) AS distinct_deals,
  MAX(created_at) AS most_recent
FROM crm_deal_notes
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

Se `total_notes = 0`, o problema é mais a montante: `dealSummaryUpdater` não tá rodando ou tá falhando silencioso.

### H3 — `crm_deals` não foi criado pra esses contatos
`dealSummaryUpdater` precisa de `crm_deal_id`. Conferir:
```sql
SELECT
  COUNT(*) AS total_contacts,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM crm_deals WHERE crm_deals.contact_id = crm_contacts.id AND crm_deals.workspace_id = crm_contacts.workspace_id)) AS contacts_with_deal
FROM crm_contacts
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND deleted_at IS NULL;
```

Se `contacts_with_deal=0`, deals não tão sendo criados — sem deal não há summary, sem summary não há memory append.

### H4 — `agent_conversations.crm_contact_id` está null
Memory append precisa de `crm_contact_id`. Conferir:
```sql
SELECT
  COUNT(*) AS total_agent_convs,
  COUNT(*) FILTER (WHERE crm_contact_id IS NOT NULL) AS linked_to_contact
FROM agent_conversations
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

Se `linked_to_contact=0`, o link conv → crm_contact não é criado e qualquer hook downstream falha.

## Por que importa agora

Estamos prestes a implementar no Frontdesk uma feature de **timeline unificada** (atendente Gustavo ver todas as convs de um contato em ordem cronológica numa única view). A versão para Lara dessa feature é o `contact_memory` — quando funcionar, Lara terá identidade + open loops + 3 últimos summaries injetados no prompt.

Se o pipeline ai_memory continuar quebrado, a Lara vai continuar com amnésia entre convs e a feature do front fica meia-boca (Gustavo vê tudo, Lara não).

## Pedido específico ao agente KLaOS

1. Validar quais das hipóteses H1-H4 são verdadeiras (queries SQL acima)
2. Identificar elo quebrado da cadeia `chatwoot resolved → reopenPolicy → memory.appendSummary`
3. Se for fix de código: PR + deploy
4. **Backfill** dos 35 contatos atuais Mais Saúde — gerar `ai_memory.summaries` retroativos das convs resolvidas pra Lara não começar branca
