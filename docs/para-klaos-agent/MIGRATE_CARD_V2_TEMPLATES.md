# Trocar `cobr_card_d7_atraso` / `cobr_card_d15_atraso` pra `_v2` no `collection_sequence_steps`

> **Owner:** agente KLaOS
> **Detectado:** 2026-04-30 — Meta reclassificou os 2 templates pra MARKETING após approval inicial UTILITY.
> **Acão Frontdesk (concluída):** ressubmetidos como `_v2` UTILITY com mudança mínima de texto, aprovados, e os antigos MARKETING foram deletados da WABA Klaus.

## Contexto

- **WABA:** Klaus (id `735467396201142`)
- **Workspace KLaOS Atend Med BH:** `9838d25b-60de-45e7-b7b7-31cc56b12ccc`
- **Antigos (DELETADOS):**
  - `cobr_card_d7_atraso` → meta id `934853362713163` (MARKETING)
  - `cobr_card_d15_atraso` → meta id `750587544711681` (MARKETING)
- **Novos (APPROVED + UTILITY):**
  - `cobr_card_d7_atraso_v2` → meta id `3621993874631787`
  - `cobr_card_d15_atraso_v2` → meta id `2125470961358142`

## Diff de texto (justifica re-aprovação)

**`cobr_card_d7_atraso_v2`** — 1 substituição:

| Sai | Entra |
|---|---|
| `Realize o pagamento pelo link abaixo para evitar a suspensão dos benefícios do plano.` | `Realize o pagamento pelo link abaixo para regularizar.` |

**`cobr_card_d15_atraso_v2`** — 1 linha removida + 1 substituição:

| Sai | Entra |
|---|---|
| `Você consegue realizar o pagamento hoje ainda?` | (removido) |
| `Caso não consiga, sua mensalidade pode ser registrada no SPC.` | `Caso o pagamento não seja regularizado, sua mensalidade pode ser registrada no SPC.` |

Resto idêntico (botão, footer, exemplo).

## Plano de migração (KLaOS)

### Step 0 — Confirmar aprovação no Meta

```sql
SELECT name, status, meta_template_id, last_synced_at
FROM waba_templates
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND name IN ('cobr_card_d7_atraso_v2', 'cobr_card_d15_atraso_v2', 'cobr_card_d7_atraso', 'cobr_card_d15_atraso')
ORDER BY name;
```

Esperado:
- 2 rows `_v2` com `status='APPROVED'`
- 2 rows antigas (sem `_v2`) ou sumiram do sync (deletadas no Meta), ou marcadas como `DELETED`/`STALE`. Bridge handler do Frontdesk emite `message_template_status_update` com `event=DELETED` quando deletamos no Meta.

Se as `_v2` ainda não estão na tabela, force-sync do `wabaNumberService.syncTemplates(numberId, workspaceId)` — vão entrar como APPROVED direto (já estão approved no Meta).

### Step 1 — Atualizar `collection_sequence_steps`

```sql
WITH mapping AS (
  SELECT * FROM (VALUES
    ('cobr_card_d7_atraso',  'cobr_card_d7_atraso_v2'),
    ('cobr_card_d15_atraso', 'cobr_card_d15_atraso_v2')
  ) AS m(legacy_name, new_name)
)
UPDATE collection_sequence_steps css
SET waba_template_id = wt_new.id,
    updated_at = NOW()
FROM mapping m
JOIN waba_templates wt_legacy
  ON wt_legacy.name = m.legacy_name
 AND wt_legacy.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
JOIN waba_templates wt_new
  ON wt_new.name = m.new_name
 AND wt_new.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
 AND wt_new.status = 'APPROVED'
WHERE css.waba_template_id = wt_legacy.id
  AND css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

### Step 2 — Validação visual da Régua Cartão

```sql
SELECT css.day_offset, wt.name, wt.status, wt.meta_template_id
FROM collection_sequence_steps css
JOIN waba_templates wt ON wt.id = css.waba_template_id
JOIN collection_sequences cs ON cs.id = css.sequence_id
WHERE css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND cs.name ILIKE '%cartão%' OR cs.name ILIKE '%cartao%' OR cs.name ILIKE '%card%'
ORDER BY css.day_offset;
```

Esperado (Régua Cartão completa):

```
-5   cobr_card_d5_lembrete         APPROVED
 0   cobr_card_d0_vencimento       APPROVED
 1   cobr_card_d1_recusado         APPROVED
 7   cobr_card_d7_atraso_v2        APPROVED   ← novo
15   cobr_card_d15_atraso_v2       APPROVED   ← novo
21   cobr_card_d21_transbordo      APPROVED
```

(`cobr_card_pagto_ok` é trigger por evento, não step.)

### Step 3 — Limpar rows legacy do `waba_templates` (opcional)

Bridge handler já notificou o `DELETED` event. Se as 2 rows antigas ainda persistem na `waba_templates` por algum motivo:

```sql
DELETE FROM waba_templates
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND name IN ('cobr_card_d7_atraso', 'cobr_card_d15_atraso')
  AND meta_template_id IN ('934853362713163', '750587544711681');
```

(Idempotente — se sync já limpou, `DELETE` retorna 0 rows.)

## Coordenação

- **Frontdesk:** ressubmissão + delete dos antigos **concluído** em 2026-04-30. Bridge webhook emitiu `message_template_status_update` em tempo real pra cada evento (create dos 2 v2 + delete dos 2 antigos).
- **KLaOS:** rodar Steps 0-2 (Step 3 só se necessário). 0 risco de disparo: enquanto `waba_template_id` aponta pro template deletado, a régua não envia (FK quebrada → validação falha graciosamente).
- **Próxima validação:** após KLaOS aplicar, rodar enroll de fixture de cartão recorrência (se existir cliente de teste com `meio_pagamento_tipo IN (1, 11, 12)`) ou validar visual no UI.
