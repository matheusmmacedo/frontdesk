# Cleanup — duplicata em `waba_templates` (DEV)

> **Owner:** agente KLaOS — quem fizer cleanup, anota em `docs/para-frontdesk-agent/KLAOS_UPDATES.md`.
> **Severidade:** baixa (não bloqueia régua atual). Ambiente: KLaOS DEV (`szkzkyexagunvadzzaec`).
> **Detectado em:** 2026-04-29 pelo agente Frontdesk durante audit do SDD billing E2E.

## Sintoma

`SELECT name, COUNT(*) FROM waba_templates GROUP BY name HAVING COUNT(*) > 1;` retorna:

| name | count |
|---|---|
| boleto_atraso_10dias | 2 |

Ambos rows estão `APPROVED` `UTILITY` `pt_BR`. Diferença:

| id | meta_template_id | last_synced_at |
|---|---|---|
| `97ddfdfc-f95d-42db-ae06-2a663fb53064` | `boleto_atraso_10dias` ⚠️ literal nome | 2026-04-07 |
| `92712e7c-bf46-477a-abce-3a2328f01eee` | `1453687906218024` ✅ id real | 2026-04-29 |

## Causa raiz

O sync inicial (provavelmente seed manual/migration) criou o row com `meta_template_id = name` (literal). O sync subsequente da Graph API **não fez UPDATE** porque (presumivelmente) usa `(waba_number_id, meta_template_id)` como conflict key — viu que o `meta_template_id=1453687906218024` não existia e fez **INSERT** em vez de UPDATE no row antigo.

Confirmar isso no código do sync e mudar conflict key pra `(waba_number_id, name)` evita futuras duplicatas.

## Impacto atual

`collection_sequence_steps` referencia o **STALE** id 2x (régua "Apresentação Gustavo" + "Demo Cliente — Régua WABA"). O REAL id (`92712e...`) **não é referenciado por nada**.

Como o `KlaosBridgeService.send_template` provavelmente dispatch via `name + language` (não via `meta_template_id`), as 2 réguas continuam funcionando — não há regression imediata. Mas:
- Confunde audit/lookup
- Próximo seed pode tentar reusar o row real e falhar
- Se algum código futuro buscar template por `meta_template_id`, vai pegar o errado

## Fix recomendado (Option B — preserva FK das réguas)

```sql
BEGIN;

-- 1. Conferir antes
SELECT id, name, meta_template_id, last_synced_at, status, category
FROM waba_templates WHERE name = 'boleto_atraso_10dias';
-- Esperado: 2 rows (ids 97ddfdfc... e 92712e7c...)

-- 2. Atualiza o row stale com meta_template_id real (a régua já aponta pra ele)
UPDATE waba_templates
SET meta_template_id = '1453687906218024',
    last_synced_at   = NOW(),
    components       = (SELECT components FROM waba_templates WHERE id = '92712e7c-bf46-477a-abce-3a2328f01eee')
WHERE id = '97ddfdfc-f95d-42db-ae06-2a663fb53064';

-- 3. Deleta o row novo duplicado
DELETE FROM waba_templates WHERE id = '92712e7c-bf46-477a-abce-3a2328f01eee';

-- 4. Confirma
SELECT id, name, meta_template_id, last_synced_at FROM waba_templates WHERE name = 'boleto_atraso_10dias';
-- Esperado: 1 row, id 97ddfdfc..., meta_template_id 1453687906218024

COMMIT;
```

## Fix do sync (preventivo)

Seja qual for o serviço/job que faz o sync (procurar por `last_synced_at = NOW()` no código do KLaOS):

```typescript
// ANTES (presumido):
await supabase.from('waba_templates').upsert(
  { ...templateData },
  { onConflict: 'waba_number_id,meta_template_id' }  // BUG
)

// DEPOIS:
await supabase.from('waba_templates').upsert(
  { ...templateData },
  { onConflict: 'waba_number_id,name,language' }  // template "name" + "language" são únicos por WABA na Meta
)
```

Garantir que `(waba_number_id, name, language)` tem unique index — caso contrário criar:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS waba_templates_unique_per_waba
ON waba_templates (waba_number_id, name, language)
WHERE deleted_at IS NULL;  -- se tiver soft delete, ajustar
```

## Validação pós-fix

```sql
-- Não pode haver mais duplicata de name por WABA
SELECT waba_number_id, name, COUNT(*)
FROM waba_templates
GROUP BY waba_number_id, name
HAVING COUNT(*) > 1;
-- Esperado: 0 rows
```

## PROD não afetado

PROD (`ddnwemmvsuiibgbzjpwx`) tem `waba_templates` com **0 rows** — sync nunca rodou em prod (ver `SCHEMA_DRIFT_COLLECTION_CAMPAIGNS.md`). Preventivo: aplicar o fix do índice antes do primeiro sync de prod, pra não nascer com mesmo bug.
