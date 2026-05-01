# Régua Cartão + Lara prompt fix + diagnóstico nulls

> **Owner:** agente KLaOS — workspace `9838d25b-60de-45e7-b7b7-31cc56b12ccc` (Atend Med BH dev).
> **Detectado:** 2026-04-30 — auditoria de modalidades de pagamento revelou que a régua atual `cobr_*` cobre só boleto (98% da carteira), mas quebra silenciosamente pra cartão recorrência (1.7%) e tem 65.5% de débitos sem `meio_pagamento_tipo` mapeado.
> **Restrição operacional:** **NADA pode disparar mensagem.** Manter campaigns paused, auto_enroll=false, sem enrollments. Estado seguro do TEST_SAFETY_GUARDS.md.

## Estado atual da carteira

| `meio_pagamento_tipo` | Clientes (atrasados c/ phone) | %    | Modalidade real (inferida) |
|-----------------------|-------------------------------|------|----------------------------|
| `null`                | 580                           | 65.5%| boleto sem tag — `payment_pages` tem `linha_digitavel` + `pix_codigo` + `pdf_url` |
| `2`                   | 288                           | 32.5%| **boleto explícito** (régua cobr_* cobre) |
| `11`                  | 15                            | 1.7% | **cartão recorrência** — só tem `checkout_url` + `pagamento_online_codigo` |
| `6`                   | 2                             | 0.2% | PIX explícito |

`tenex_credentials.meio_pagamento_map` reconhece tipos `1, 2, 6, 11, 12`. O `null` é uma fração da base que o sync do tenex não tagueou.

## Ação 1 — DROP `fatura_emissao` step (Frontdesk depende)

`fatura_emissao` ainda em uso em 2 steps (D0 enrollment_offset, ambas campaigns):

```sql
SELECT cc.name, css.step_order, css.day_offset, wt.name AS template
FROM collection_sequence_steps css
JOIN collection_campaigns cc ON cc.id = css.campaign_id
JOIN waba_templates wt ON wt.id = css.waba_template_id
WHERE wt.name = 'fatura_emissao';
-- → 2 rows: Apresentação Gustavo (step_order=2), Demo Cliente (step_order=1)
```

**Ação:** Gustavo decidiu remover esse step da régua (não está no PLANO_TEMPLATES_META_FINAL.md). KLaOS deve:

```sql
DELETE FROM collection_sequence_steps css
USING waba_templates wt
WHERE css.waba_template_id = wt.id
  AND wt.name = 'fatura_emissao'
  AND css.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- Esperado: DELETE 2 rows
```

Após confirmar 0 rows usando `fatura_emissao`, avisar o Frontdesk que pode finalizar o DELETE do template legacy na Meta.

## Ação 2 — Criar campaign `Régua Cartão`

7 templates `cobr_card_*` subidos hoje na Meta (PENDING UTILITY pt_BR — vão ficar APPROVED em minutos):

| Step | day_offset | trigger      | Template novo            | Meta ID            | Botões |
|------|------------|--------------|--------------------------|--------------------|--------|
| 1    | -5         | due_date     | `cobr_card_d5_lembrete`  | `2001794427103401` | Atualizar Pagamento |
| 2    | 0          | due_date     | `cobr_card_d0_vencimento`| `982392961155241`  | Pagar Agora |
| 3    | 1          | due_date     | `cobr_card_d1_recusado`  | `1274433947657535` | Atualizar Pagamento |
| 4    | 7          | due_date     | `cobr_card_d7_atraso`    | `934853362713163`  | Pagar Agora |
| 5    | 15         | due_date     | `cobr_card_d15_atraso`   | `750587544711681`  | Pagar Agora |
| 6    | 21         | due_date     | `cobr_card_d21_transbordo`| `5414433888782575`| (sem botão) |
| —    | event-driven| —           | `cobr_card_pagto_ok`     | `1450363883504132` | (sem botão) |

**SQL pra criar campaign:**

```sql
-- Aguardar status APPROVED nos 7 cobr_card_* na waba_templates
SELECT name, status FROM waba_templates WHERE name LIKE 'cobr_card_%';
-- Critério: 7 rows APPROVED

-- Criar campaign nova com filter_meio_pagamento_tipo IN (1, 11, 12)
-- (cartão recorrência, sem boleto disponível)
INSERT INTO collection_campaigns (
  id, workspace_id, name, status, auto_enroll,
  filter_has_active_plan, filter_min_days_overdue,
  -- ATENÇÃO: a coluna filter_meio_pagamento_tipo PROVAVELMENTE NÃO EXISTE.
  -- Schema atual de collection_campaigns só tem filter_has_active_plan,
  -- filter_min_days_overdue, filter_max_days_overdue, filter_min_debt.
  -- Recomendação: ADD COLUMN filter_meio_pagamento_tipo integer[]
  -- (array pra suportar múltiplos tipos), com índice GIN.
  ...
)
VALUES (
  gen_random_uuid(),
  '9838d25b-60de-45e7-b7b7-31cc56b12ccc',
  'Régua Cartão',
  'paused',           -- PAUSED — não disparar nada
  false,              -- auto_enroll=false
  true,               -- só clientes com plano ativo
  -5,                 -- entra desde D-5 (lembrete pré-cobrança)
  ...
);
```

**Sub-ação 2a — Schema:** adicionar coluna `filter_meio_pagamento_tipo integer[]` em `collection_campaigns` se ainda não existir. Sem isso, não dá pra branchar campaign por modalidade.

**Sub-ação 2b — Filter na Régua existente:** atualizar campaigns `Apresentação Gustavo` e `Demo Cliente — Régua WABA` pra `filter_meio_pagamento_tipo = ARRAY[2, NULL]` (boleto-only — manda só pra quem tem boleto disponível). Isso evita a régua atual disparar pra cartão e quebrar.

NOTA: NULL em array PostgreSQL é meio chato — alternativa: criar coluna `bool include_untagged_modalidades` com default true, ou usar `meio_pagamento_tipo IS NULL OR meio_pagamento_tipo = ANY(filter_meio_pagamento_tipo)` no dispatcher.

**Sub-ação 2c — Steps da Régua Cartão:** `INSERT INTO collection_sequence_steps` os 6 steps (1 a 6) com `waba_template_id` resolvido por nome do `cobr_card_*` correspondente. Step 7 (`cobr_card_pagto_ok`) é event-driven — não vai em sequence_steps por dia.

## Ação 3 — Atualizar `collection_system_prompt` da Lara

State atual da Lara (DEV, status=active, bridge_enabled=true):

```
Você está atendendo um cliente devedor da Mais Saúde 24 Horas.

REGRAS OBRIGATÓRIAS:
1. Ofereça APENAS as formas de pagamento listadas nos DADOS DO DEVEDOR
   (boleto e/ou PIX). Não invente outras formas.
...
```

**Problema:** Lara só fala "boleto e/ou PIX" — cliente cartão recorrente recusado não tem nenhum dos dois disponíveis. Lara vai contradizer realidade do débito.

**Update sugerido (manter o resto do prompt):**

```
1. Ofereça APENAS as formas de pagamento disponíveis para este débito,
   conforme os DADOS DO DEVEDOR. Pode ser uma destas combinações:
   - Boleto + PIX (modalidade boleto)
   - Link de atualização de cartão (modalidade cartão recorrência —
     quando a cobrança automática recusou)
   Não invente formas que não estão nos dados.
```

Aplicar:

```sql
UPDATE agent_instances
SET collection_system_prompt = 'Você está atendendo um cliente devedor da Mais Saúde 24 Horas.

REGRAS OBRIGATÓRIAS:
1. Ofereça APENAS as formas de pagamento disponíveis para este débito, conforme os DADOS DO DEVEDOR. Pode ser uma destas combinações:
   - Boleto + PIX (modalidade boleto)
   - Link de atualização de cartão (modalidade cartão recorrência — quando a cobrança automática recusou)
   Não invente formas que não estão nos dados.
2. NUNCA confirme pagamento sem o cliente enviar um comprovante. Não diga "obrigado pelo pagamento" a menos que o cliente confirme explicitamente que pagou E envie comprovante.
3. Se o cliente disser que quer pagar, envie o link correspondente conforme a modalidade do débito (boleto, PIX, ou link de atualização de cartão). Não assuma que ele já pagou.
4. Se pedir desconto, informe que não há desconto disponível.
5. Seja empático, profissional e objetivo.
6. Responda em uma única mensagem curta e direta.',
    updated_at = NOW()
WHERE agent_name = 'Lara'
  AND workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

Validar com `SELECT collection_system_prompt FROM agent_instances WHERE agent_name='Lara'` antes/depois.

## Ação 4 — Investigar 580 nulls

580 clientes (65.5%) com `meio_pagamento_tipo=null` no `tenex_debt_items`. Precisa investigar **na fonte** (tenex API) por que o campo não vem.

```sql
-- Sample dos null pra entender padrão
SELECT
  d.name,
  i.meio_pagamento_id,
  i.meio_pagamento_tipo,
  i.linha_digitavel IS NOT NULL AS tem_linha_digitavel,
  i.pix_codigo IS NOT NULL AS tem_pix,
  i.pagamento_online_codigo IS NOT NULL AS tem_codigo_online,
  i.tenex_data->>'meio_pagamento_id' AS tenex_meio_id,
  i.tenex_data->>'meio_pagamento_tipo' AS tenex_meio_tipo
FROM tenex_debt_items i
JOIN tenex_debtors d ON d.id = i.debtor_id
WHERE i.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND i.meio_pagamento_tipo IS NULL
  AND i.status != 'paid'
LIMIT 20;
```

**Caminhos:**
- Se `tenex_data->>'meio_pagamento_tipo'` está populado mas `meio_pagamento_tipo` (coluna) está null → bug na sync (mapping perdeu campo).
- Se `tenex_data` também é null → tenex API não retorna o campo pra esses clientes (provável: clientes antigos pre-mapping).

Decisão de produto:
- (a) Tratar null como "boleto" (default) → régua atual funciona pra eles
- (b) Investigar caso a caso e re-sincronizar
- (c) Marcar campaign filter pra include `meio_pagamento_tipo IN (2, NULL)` (boleto + untagged)

## Coordenação

| Ação | Lado     | Bloqueia |
|------|----------|----------|
| 1    | KLaOS    | Frontdesk DELETE legacy `fatura_emissao` |
| 2a   | KLaOS    | Schema migration |
| 2b   | KLaOS    | Régua atual safety (filter por modalidade) |
| 2c   | KLaOS    | Régua Cartão funcional (após cobr_card_* APPROVED) |
| 3    | KLaOS    | Lara consistente com modalidade |
| 4    | KLaOS    | Investigar nulls (decisão de produto) |

**Frontdesk fez:** POST 7 cobr_card_* na Meta (PENDING UTILITY) + atualizou `billing_templates.rake` com cartão family.

**Reportar de volta** em `docs/para-frontdesk-agent/KLAOS_UPDATES.md` (mesmo formato dos commits anteriores).
