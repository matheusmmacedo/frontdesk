# SAFETY GUARDS — antes de testar a régua em DEV

> **Owner:** todos os agentes que tocarem `collection_campaigns` em DEV.
> **Por que importa:** workspace `9838d25b-…` (Atend Med BH dev) tem **2.626 debtors reais** com phone_e164 (auditoria 2026-04-30 16:30 UTC), **886 com `has_active_plan=true` e `days_overdue >= 1`**. Filtros atuais das 2 campaigns batem em todos eles. WABA Klaus é a real (Meta cobra mensagens enviadas, contagem de quality contra a WABA).
>
> **Risco de trigger acidental:** se setar `auto_enroll=true` E `status='active'` numa campaign sem proteção, o `TriggerScheduledItemsJob` enrolla os 886 e começa a disparar templates UTILITY pra clientes reais. Em até 1h, a Atend Med BH recebe ~7×886 = **6202 mensagens** indevidas em massa.

## ⚠️ DESCOBERTA CRÍTICA — DEV não é isolado upstream

Auditoria 2026-04-30 17:00 UTC nas 2 Supabases:

| campo                     | KLaOS DEV (`szkzkyexagunvadzzaec`)   | KLaOS PROD (`ddnwemmvsuiibgbzjpwx`)  |
|---------------------------|--------------------------------------|--------------------------------------|
| `tenex_credentials.api_url` | `https://maisaudebh.tenex.com.br`  | `https://maisaudebh.tenex.com.br`    |
| `workspace_id`              | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` |
| `company_cnpj`              | `46.532.120/0001-30`               | `46.532.120/0001-30`                 |
| `is_active`                 | `true`                             | `true`                               |
| `last_sync_at`              | rolling (~5min)                    | rolling (~5min)                      |

**Implicação:** `tenex_debtors` em DEV vem do **mesmo endpoint tenex de produção** que abastece o KLaOS prod. A separação DEV↔PROD existe **só no banco KLaOS** — o pipeline upstream é compartilhado. Sample de phones em DEV (5 rows mais recentes do sync):

```
+5531998932729  ALEXANDRE LUIZ TORRES CODA       has_active_plan=true  days_overdue=10
+5531999282788  JULIANA SOUZA SANTOS BATISTA     has_active_plan=false days_overdue=3
+5564981348548  MARIA CLARA ELIZABETH SILVA TORRES has_active_plan=true days_overdue=3
+5531999575175  LUIZ CARLOS CHAGAS               has_active_plan=true  days_overdue=1
+5531988560932  TEREZINHA LIMA DUARTE            has_active_plan=true  days_overdue=4
```

**Conclusão operacional:** a sincronização do tenex prod é intencional e fica como está — não há problema em DEV ter dados reais no `tenex_debtors`. O que **não pode acontecer** é dispatch não-controlado: nenhuma mensagem WhatsApp pode sair pra esses phones sem passar pelos guards do INSERT de enrollment (Regra 3) e pelo estado paused/auto_enroll=false das campaigns (Estado seguro atual). DEV é seguro **enquanto o dispatcher só roda contra fixtures explícitas** — o dia em que escapar uma `INSERT INTO collection_enrollments` sem WHERE protetivo, atinge cliente real.

## Estado seguro atual (auditado 2026-04-30 16:50 UTC)

```sql
-- Conferir ANTES de qualquer ação:
SELECT id, name, status, auto_enroll,
       array_length(permanent_labels,1) AS labels_n,
       filter_has_active_plan, filter_min_days_overdue
FROM collection_campaigns;
```

Esperado:
- `status='paused'` em todas
- `auto_enroll=false` em todas

Se algum row aparecer com `status='active'` ou `auto_enroll=true` antes do teste estar aprovado, **PARE** e investigue antes de qualquer outra ação.

## Regras pra testar com cliente fixture (+5521964798660)

### Regra 1 — fixture flag obrigatória

Cada debtor de teste precisa ter `tenex_data->>'is_test_fixture' = 'true'` (já é gravado pelo template SQL em `SEED_TEST_CLIENT_MATHEUS.md`).

### Regra 2 — campaign **continua paused** durante o teste

NÃO setar `status='active'`. NÃO setar `auto_enroll=true`. **O fluxo de teste é manual:**

1. Seed o fixture (rake/SQL idempotente)
2. INSERT um `collection_enrollment` manualmente apontando pro fixture **e só ele**
3. Disparar manualmente o step 1: chamar o dispatcher service (`Collection::EnrollmentDispatcher.new(enrollment).perform_step`) ou rodar o job apenas pra esse `enrollment_id`
4. Validar que mensagem chegou no +5521964798660 sem afetar outros enrollments
5. Avançar steps manualmente (ou usar `demo_interval_seconds=60` + ativar campaign **só durante o teste**, pausando logo após)

### Regra 3 — guard SQL no INSERT do enrollment

Use **sempre** essa forma com WHERE protetivo:

```sql
INSERT INTO collection_enrollments (workspace_id, campaign_id, debtor_id, status, current_step_order, enrolled_at, debt_value_at_enrollment, debt_days_overdue_at_enrollment, primary_due_date)
SELECT
  d.workspace_id,
  '<CAMPAIGN_UUID>'::uuid,
  d.id,
  'active',
  0,
  NOW(),
  d.total_debt,
  d.days_overdue,
  (SELECT MIN(di.due_date) FROM tenex_debt_items di WHERE di.debtor_id = d.id)
FROM tenex_debtors d
WHERE d.workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND d.external_id LIKE 'TEST-MATHEUS-%'              -- ← guard 1: prefix de fixture
  AND (d.tenex_data->>'is_test_fixture')::boolean      -- ← guard 2: flag explícita
  AND d.phone_e164 = '+5521964798660';                 -- ← guard 3: phone exato do user
```

Triplo guard (prefix + flag + phone). Se qualquer um falhar, o INSERT vira no-op (zero rows) — não enrola cliente real.

### Regra 4 — kill switch antes de ativar campaign (se for ativar)

Se for usar `status='active'` em algum momento (ex: validar `TriggerScheduledItemsJob` end-to-end), **antes** rode:

```sql
-- Kill switch: cancela TODOS enrollments ativos exceto fixtures
UPDATE collection_enrollments ce
SET status = 'cancelled_pre_test', unenrolled_at = NOW(), unenroll_reason = 'safety_guard_pre_test'
FROM tenex_debtors d
WHERE ce.debtor_id = d.id
  AND ce.status = 'active'
  AND COALESCE(d.tenex_data->>'is_test_fixture', 'false') != 'true';
```

Confirmar `0 rows` (zero clientes reais ativos antes do teste) ou avaliar caso a caso.

### Regra 5 — desativar campaign **imediatamente** após validar step

```sql
UPDATE collection_campaigns SET status='paused' WHERE id='<CAMPAIGN_UUID>';
```

Não deixar `active` overnight.

## Pre-flight checklist

Antes de digitar qualquer comando que possa disparar mensagem:

- [ ] `SELECT status, auto_enroll FROM collection_campaigns` → todos paused/false
- [ ] `SELECT COUNT(*) FROM collection_enrollments WHERE status='active'` → 0 (ou só fixtures)
- [ ] `SELECT phone_e164 FROM tenex_debtors WHERE external_id LIKE 'TEST-MATHEUS-%'` → só `+5521964798660`
- [ ] WABA token do Frontdesk DEV aponta pra WABA Klaus de DEV (que é a mesma de prod neste caso — cuidado dobrado, é WABA real)
- [ ] Eu tenho meu celular comigo pra abortar caso algo escape

## Se algo escapar

- Pausar campaign: `UPDATE collection_campaigns SET status='paused' WHERE id=...`
- Cancelar enrollments ativos: `UPDATE collection_enrollments SET status='cancelled' WHERE status='active'`
- Drenar Sidekiq da fila de dispatch: identificar jobs `Collection::*` em sidekiq_admin e descartá-los
- Reportar pro Matheus imediatamente

Mensagens já entregues à Meta não voltam — só dá pra parar antes do dispatch.
