# Migrar régua de `legacy` → `cobr_*` no `collection_sequence_steps`

> **Owner:** agente KLaOS — quando os 7 templates `cobr_*` saírem de PENDING pra APPROVED na Meta.
> **Detectado:** 2026-04-30 — incidente de cleanup acidental dos `ms24h_*` (família que o Gustavo aprovou em PLANO_TEMPLATES_META_FINAL.md). Resubidos com nomenclatura nova (`cobr_*`) porque os nomes ms24h_* ficaram locked 30 dias na Meta.

## Contexto

- **Doc oficial Gustavo:** `PLANO_TEMPLATES_META_FINAL.md` (raiz do repo Frontdesk, 2026-04-08) — texts approved letter-perfect com negritos, "há 7 dias", "Boleto Vencido" corrigido, sem "Bom dia"/"URGENCIA".
- **Resubmissão:** 2026-04-30, todos UTILITY pt_BR pendentes na Meta, encoding via `JSON.generate(ascii_only: true)` (zero risco shell/locale).
- **Régua Gustavo (vs legacy):** D-5 → D0 → **D+1 NOVO** → D+7 (era D+5) → D+15 → D+21. **D+10 removido**.

## Mapping legacy → cobr_*

| Estágio    | Template legacy (atual no KLaOS) | Template novo (cobr_*) | Meta ID novo (PENDING)         | Botões? |
|------------|----------------------------------|------------------------|--------------------------------|---------|
| D-5        | `fatura_lembrete_5dias`          | `cobr_d5_lembrete`     | `967573122486341`              | PIX + Boleto |
| D0         | `cobranca_vencimento_hoje`       | `cobr_d0_vencimento`   | `26984168144553305`            | PIX + Boleto |
| **D+1 (novo)** | (não existia)                | `cobr_d1_vencido`      | `1892848914751505`             | PIX + Boleto |
| D+7        | `cobranca_atraso_5dias` (era D+5)| `cobr_d7_atraso`       | `967806542305040`              | PIX + Boleto |
| ~D+10~     | `boleto_atraso_10dias`           | **REMOVIDO da régua**  | —                              | — |
| D+15       | `fatura_atraso_15dias`           | `cobr_d15_atraso`      | `1483433960183870`             | PIX + Boleto |
| D+21       | `fatura_atraso_21dias`           | `cobr_d21_transbordo`  | `960619686455342`              | sem botão |
| Pagamento  | `aviso_pagamento_ok`             | `cobr_pagto_ok`        | `1254671323072863`             | sem botão |

## Plano de migração (KLaOS)

### Step 0 — Aguardar approval Meta

```sql
-- Frontdesk Postgres OU KLaOS waba_templates: aguardar status=APPROVED em todos os 7 cobr_*
SELECT name, status, last_synced_at
FROM waba_templates
WHERE name LIKE 'cobr_%'
ORDER BY name;
```

Critério: 7 rows com `status='APPROVED'`. Histórico de approval da WABA Klaus = 2-30min por template.

### Step 1 — Sync da `waba_templates` no KLaOS DEV

Force-sync do `wabaNumberService.syncTemplates(numberId, workspaceId)` pra criar as 7 rows novas (lado KLaOS Supabase) com `meta_template_id` correto. As rows de `cobr_*` virão APPROVED se já estão approved na Meta.

### Step 2 — Atualizar `collection_sequence_steps`

```sql
-- Workspace Atend Med BH: 9838d25b-60de-45e7-b7b7-31cc56b12ccc
-- Pegar ids de waba_templates (cobr_*) e atualizar steps existentes

WITH new_tpls AS (
  SELECT id, name FROM waba_templates
  WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
    AND name LIKE 'cobr_%'
    AND status = 'APPROVED'
),
mapping AS (
  SELECT
    legacy_name, new_name
  FROM (VALUES
    ('fatura_lembrete_5dias',    'cobr_d5_lembrete'),
    ('cobranca_vencimento_hoje', 'cobr_d0_vencimento'),
    ('cobranca_atraso_5dias',    'cobr_d7_atraso'),
    ('fatura_atraso_15dias',     'cobr_d15_atraso'),
    ('fatura_atraso_21dias',     'cobr_d21_transbordo'),
    ('aviso_pagamento_ok',       'cobr_pagto_ok')
  ) AS m(legacy_name, new_name)
)
UPDATE collection_sequence_steps css
SET waba_template_id = nt.id,
    updated_at = NOW()
FROM mapping m
JOIN waba_templates wt_legacy ON wt_legacy.name = m.legacy_name
JOIN new_tpls nt ON nt.name = m.new_name
WHERE css.waba_template_id = wt_legacy.id
  AND css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

### Step 3 — Adicionar step novo D+1

A régua do Gustavo tem `cobr_d1_vencido` como **etapa nova**, não substituição. Inserir step:

```sql
-- Pegar campaign_id correto antes de rodar (a régua que tem boleto_atraso_10dias?)
-- Usar order_index entre D0 e D+7 (ex: 2.5 ou re-ordenar todos depois)
INSERT INTO collection_sequence_steps (id, workspace_id, campaign_id, waba_template_id, order_index, day_offset, condition_type, ...)
SELECT
  gen_random_uuid(),
  '9838d25b-60de-45e7-b7b7-31cc56b12ccc',
  <campaign_id>,
  (SELECT id FROM waba_templates WHERE name='cobr_d1_vencido' AND status='APPROVED'),
  <novo_order_index>,
  1, -- day_offset = 1
  ...
```

### Step 4 — Remover step D+10

```sql
DELETE FROM collection_sequence_steps css
USING waba_templates wt
WHERE css.waba_template_id = wt.id
  AND wt.name = 'boleto_atraso_10dias'
  AND css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

### Step 5 — Validação visual

```sql
SELECT css.day_offset, wt.name, wt.status
FROM collection_sequence_steps css
JOIN waba_templates wt ON wt.id = css.waba_template_id
WHERE css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
ORDER BY css.day_offset;
```

Esperado:
```
-5    cobr_d5_lembrete       APPROVED
0     cobr_d0_vencimento     APPROVED
1     cobr_d1_vencido        APPROVED
7     cobr_d7_atraso         APPROVED
15    cobr_d15_atraso        APPROVED
21    cobr_d21_transbordo    APPROVED
```

(`cobr_pagto_ok` é trigger por evento de pagamento — não vive em sequence_steps por dia.)

### Step 6 — Após validação completa: cleanup

Frontdesk deleta os 8 legacy via Meta API + sync. KLaOS pode dropar as rows de `waba_templates` legacy depois (idempotente — sync rasga sozinho).

## Coordenação

- **Frontdesk:** já fez o POST dos 7 + atualizou `billing_templates.rake` + plano doc.
- **KLaOS:** rodar Steps 0-5 quando os 7 estiverem APPROVED.
- **Frontdesk após validação:** rodar DELETE dos 8 legacy via curl Meta API (token Daniel Limeira) + force-sync.
