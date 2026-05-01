# Seed — cliente teste +5521964798660 em KLaOS DEV

> **Owner:** agente KLaOS — implementar como rake task `klaos:billing:seed_test_client`. Frontdesk agent (eu) também tem permissão pra executar SQL direto via Supabase MCP em DEV — usuário autorizou em 2026-04-29 ("usar quando voce quiser testar em qualquer hipotese").
> **Ambiente:** APENAS KLaOS DEV `szkzkyexagunvadzzaec`. **NUNCA rodar em PROD.**
> **Idempotente:** mesmo `cenario` sempre retorna mesmo debtor (UPSERT por external_id).

## Por que existir

Para testar a régua e2e (todos os 7 estágios) com um número real (`+5521964798660`) sem manipular um cliente vivo. Clonamos um cliente real → trocamos PII por fixture do Matheus → ajustamos `due_date` dos debt_items pra simular cada estágio (D-5, D0, D+5, D+10, D+15, D+21, etc).

## Fixture base

| Campo | Valor |
|---|---|
| `name` | `Matheus (TEST)` |
| `phone` | `(21) 96479-8660` |
| `phone_e164` | `+5521964798660` |
| `email` | `matheus.test@klaos.ai` |
| `cpf_cnpj` | `999.999.999-99` (não-real) |
| `cpf_cnpj_digits` | `99999999999` |
| `workspace_id` | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` (Atend Med BH dev) |
| `external_id` (debtor) | `TEST-MATHEUS-{cenario}` |
| `tenex_data.is_test_fixture` | `true` |

## Cenários de teste

| `cenario` | due_date | days_overdue | template esperado | status_pagamento |
|---|---|---|---|---|
| `lembrete_5d` | now + 5 | -5 | `fatura_lembrete_5dias` | pending |
| `emissao` | now + 30 | -30 | `fatura_emissao` | pending |
| `vencimento_hoje` | now | 0 | `cobranca_vencimento_hoje` | pending |
| `atraso_5d` | now - 5 | 5 | `cobranca_atraso_5dias` | pending |
| `atraso_10d` | now - 10 | 10 | `boleto_atraso_10dias` | pending |
| `atraso_15d` | now - 15 | 15 | `fatura_atraso_15dias` | pending |
| `atraso_21d` | now - 21 | 21 | `fatura_atraso_21dias` | pending |
| `cartao_recusado` | now - 5 | 5 | (ainda não há template específico) | declined |

## SQL idempotente (template)

Substituir `{{CENARIO}}`, `{{DAYS_OFFSET}}`, `{{MEIO_PAGAMENTO_TIPO}}` antes de executar.
Base clonada: cliente real `cd1651ae-106a-4c43-aca9-addeb5c1f6d2` (LUCIA HELENA, 1 debt_item, R$ 34,90, payment type 2 = boleto+PIX).

```sql
DO $$
DECLARE
  v_workspace_id uuid := '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
  v_cenario text := '{{CENARIO}}';      -- ex: 'atraso_10d'
  v_days_offset int := {{DAYS_OFFSET}}; -- ex: 10  (positive = past, negative = future)
  v_meio_pgto_tipo smallint := {{MEIO_PAGAMENTO_TIPO}}; -- 2 = boleto+pix, 6 = cartão
  v_external_id text := 'TEST-MATHEUS-' || v_cenario;
  v_due_date date := CURRENT_DATE - v_days_offset;
  v_debtor_id uuid;
  v_debt_item_id uuid;
BEGIN
  -- UPSERT debtor por external_id (idempotente)
  INSERT INTO tenex_debtors (
    workspace_id, external_id, name, cpf_cnpj, cpf_cnpj_digits,
    phone, phone_e164, email, total_debt, days_overdue, status,
    has_active_plan, last_synced_at, tenex_data
  )
  VALUES (
    v_workspace_id, v_external_id, 'Matheus (TEST)', '999.999.999-99', '99999999999',
    '(21) 96479-8660', '+5521964798660', 'matheus.test@klaos.ai',
    34.90, GREATEST(v_days_offset, 0), 'active',
    true, NOW(),
    jsonb_build_object(
      'is_test_fixture', true,
      'cenario', v_cenario,
      'cloned_from', 'cd1651ae-106a-4c43-aca9-addeb5c1f6d2'
    )
  )
  ON CONFLICT (workspace_id, external_id) DO UPDATE SET
    days_overdue = GREATEST(v_days_offset, 0),
    last_synced_at = NOW(),
    tenex_data = tenex_debtors.tenex_data || EXCLUDED.tenex_data,
    updated_at = NOW(),
    deleted_at = NULL
  RETURNING id INTO v_debtor_id;

  -- UPSERT debt_item (1 boleto fictício)
  INSERT INTO tenex_debt_items (
    workspace_id, debtor_id, external_id, title_number,
    value, original_value, due_date, days_overdue, status,
    description, meio_pagamento_id, meio_pagamento_tipo,
    pdf_url, linha_digitavel, pix_codigo, pix_imagem_url, checkout_url,
    pagamento_online_codigo, tenex_data
  )
  VALUES (
    v_workspace_id, v_debtor_id, v_external_id || '-ITEM',
    'TEST-' || UPPER(v_cenario), 34.90, 34.90, v_due_date,
    GREATEST(v_days_offset, 0), 'pending',
    'TEST FIXTURE - ' || v_cenario,
    19, v_meio_pgto_tipo,
    'https://example.com/test-boleto.pdf',
    '00190.00009 03122.631017 55637.810171 9 13870000003490',
    '00020101021226TESTPIXCODE',
    'https://example.com/test-pix.png',
    NULL, 'TEST_ONLINE_CODE',
    jsonb_build_object('is_test_fixture', true)
  )
  ON CONFLICT (workspace_id, external_id) DO UPDATE SET
    due_date = v_due_date,
    days_overdue = GREATEST(v_days_offset, 0),
    updated_at = NOW();

  RAISE NOTICE 'Test debtor seeded: id=%, external_id=%, due_date=%', v_debtor_id, v_external_id, v_due_date;
END $$;
```

## Pre-condições no DB

Para o SQL acima funcionar, **preciso unique constraints** que talvez ainda não existam:
- `tenex_debtors`: UNIQUE `(workspace_id, external_id)` — verificar
- `tenex_debt_items`: UNIQUE `(workspace_id, external_id)` — verificar

```sql
-- Diagnóstico (rodar antes da primeira seed):
SELECT conname, contype, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid IN ('tenex_debtors'::regclass, 'tenex_debt_items'::regclass);
```

Se faltar, criar:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS tenex_debtors_workspace_external_id_uidx
  ON tenex_debtors (workspace_id, external_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS tenex_debt_items_workspace_external_id_uidx
  ON tenex_debt_items (workspace_id, external_id);
```

## Como enrollar na régua

Após seed, criar enrollment manual na campaign de teste:

```sql
INSERT INTO collection_enrollments (
  workspace_id, campaign_id, debtor_id, status,
  current_step_order, enrolled_at, debt_value_at_enrollment, debt_days_overdue_at_enrollment,
  primary_due_date
)
SELECT
  d.workspace_id,
  '{{CAMPAIGN_ID}}'::uuid,  -- 'f0dab2d3-68e6-45f4-b4d7-24cfdf05b27f' (Apresentação Gustavo) ou '0f34d947-63a7-48a2-bab3-85f7936c92b3' (Demo Cliente)
  d.id,
  'active',
  0,
  NOW(),
  d.total_debt,
  d.days_overdue,
  (SELECT MIN(di.due_date) FROM tenex_debt_items di WHERE di.debtor_id = d.id)
FROM tenex_debtors d
WHERE d.external_id = 'TEST-MATHEUS-{{CENARIO}}'
  AND d.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

Atençao: campaigns hoje estão `paused`. Mudar `status='active'` antes de rodar enrollment job. Ou usar `demo_interval_seconds` pra acelerar (já está em 60s nas duas).

## Cleanup (limpar fixtures)

```sql
BEGIN;
DELETE FROM collection_enrollments WHERE debtor_id IN (
  SELECT id FROM tenex_debtors WHERE external_id LIKE 'TEST-MATHEUS-%'
);
DELETE FROM tenex_debt_items WHERE external_id LIKE 'TEST-MATHEUS-%';
DELETE FROM tenex_debtors WHERE external_id LIKE 'TEST-MATHEUS-%';
COMMIT;
```

## Implementação recomendada (KLaOS rake)

```ruby
namespace :klaos do
  namespace :billing do
    desc 'Seed test client +5521964798660 em DEV — Usage: rake klaos:billing:seed_test_client[atraso_10d]'
    task :seed_test_client, [:cenario] => :environment do |_t, args|
      raise 'PROD blocked' if Rails.env.production?
      cenario = args[:cenario] || 'atraso_10d'
      offsets = {
        'lembrete_5d'      => -5,
        'emissao'          => -30,
        'vencimento_hoje'  => 0,
        'atraso_5d'        => 5,
        'atraso_10d'       => 10,
        'atraso_15d'       => 15,
        'atraso_21d'       => 21,
        'cartao_recusado'  => 5
      }
      raise "Unknown cenario: #{cenario}" unless offsets.key?(cenario)
      meio = cenario == 'cartao_recusado' ? 6 : 2
      ActiveRecord::Base.connection.execute(seed_sql(cenario, offsets[cenario], meio))
      puts "Seeded TEST-MATHEUS-#{cenario}"
    end
  end
end
```

(Ou TypeScript equivalente se KLaOS for Node.)
