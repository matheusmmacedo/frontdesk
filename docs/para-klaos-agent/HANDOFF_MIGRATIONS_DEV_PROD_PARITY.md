# Handoff KLaOS — Paridade de migrations DEV ↔ PROD

**Data:** 2026-05-06
**Origem:** auditoria `supabase_migrations.schema_migrations` em ambos projetos
**DEV:** `szkzkyexagunvadzzaec` (KLaOS DEV)
**PROD:** `ddnwemmvsuiibgbzjpwx` (KLaOS PROD)

DEV: 533 migrations · PROD: 534 migrations · Apenas-DEV: 18 · Apenas-PROD: 19. A maioria é renomeação. Abaixo, o que **realmente** importa.

---

## 🔴 CRÍTICO — fechar gap da migração Mais Saúde 24h em PROD

A Mais Saúde 24h (`workspace_id = 9838d25b-60de-45e7-b7b7-31cc56b12ccc`, mesmo UUID em DEV e PROD) entrou em PROD na sessão anterior, mas **dois pedaços de configuração ficaram só em DEV**:

### 1. `seed_mais_saude_handoff_team_map` — AUSENTE em PROD

DEV aplicou em `2026-04-23`. PROD não tem. **Sem isso, /handoff por classe de intenção não roteia certo.**

```sql
-- Aplicar em PROD (KLaOS PROD project_id ddnwemmvsuiibgbzjpwx)
UPDATE workspaces
SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
  'handoff_team_map', jsonb_build_object(
    'cancelamento', 6,
    'cancelamentos', 6,
    'contratos', 4,
    'contratos-e-cancelamentos', 4,
    'cobranca', 2,
    'cobrancas', 2,
    'boletos', 2,
    'vendas', 1,
    'consultas', 3,
    'consultas-e-exames', 3,
    'exames', 3,
    'suporte', 2,
    'default', 2
  )
)
WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

> ⚠️ **VERIFIQUE PRIMEIRO** se os IDs de team batem com PROD. No HANDOFF anterior eu tinha mapeado em PROD: `cobrança=2, cancelamento=3, contratos=4`. **Aqui o seed está usando o mapping de DEV** (`cancelamento=6, contratos=4, cobrança=2`). Cheque o `frontdesk_teams` cache da workspace ou faça SQL no Frontdesk PROD pra validar IDs reais antes de aplicar.

### 2. `reopen_policy` — PROD aplicou só `reopen_policy_schema_only` (faltam os dois INSERT/UPDATE)

PROD tem as colunas (`agent_conversations.reactivation_at`, `agent_handoff_config.reopen_window_minutes`, índice). **Falta a parte de dados:**

```sql
-- 1. Feature flag (opt-in da Mais Saúde)
INSERT INTO workspace_feature_flags (workspace_id, flag_name, enabled)
VALUES ('9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'reopen_policy_enabled', true)
ON CONFLICT (workspace_id, flag_name) DO UPDATE SET enabled = EXCLUDED.enabled;

-- 2. Config default em workspaces.settings.reopen_policy
UPDATE workspaces
SET settings = COALESCE(settings, '{}'::jsonb) || jsonb_build_object(
  'reopen_policy', jsonb_build_object(
    'window_minutes', 1440,
    'fallback_to_team', true,
    'fallback_to_bot_after_window', true
  )
)
WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
```

### Como aplicar como migration nomeada (não solto)

Use `mcp__supabase__apply_migration` com nome `seed_mais_saude_handoff_team_map_prod` e `reopen_policy_data_prod` — assim fica registrado em `schema_migrations` e dá pra diffar depois.

---

## 🟡 GAPS REAIS (não-Mais-Saúde) — DEV → PROD

Estas existem em DEV e nunca foram aplicadas em PROD. **Decisão do KLaOS:** aplicar agora ou só quando precisar do feature em PROD.

| Migration | O que faz | Recomendação |
|---|---|---|
| `add_notes_column_to_crm_contacts` | `ALTER TABLE crm_contacts ADD COLUMN notes text` | ✅ Aplicar — coluna usada por extend_crm_tasks_notes_for_crud que JÁ está em PROD |
| `frontdesk_channel_bridges` | Cria tabela `frontdesk_channel_bridges` (linkedin/collections/web_widget) + RLS | ⏸ Aplicar quando ativar bridges em PROD |
| `collection_templates_and_waba_integration` | Cria `collection_campaign_templates` + colunas em `collection_sequence_steps` + seed "Régua de Cobrança Padrão" | ⏸ Tenex/cobrança — aplicar quando ativar cobrança em PROD para Mais Saúde |
| `fix_waba_templates_unique_dedupe` | Dedupe de boleto_atraso_10dias + troca constraint pra `(waba_number_id, name, language)` | ⏸ Só aplicar se Mais Saúde PROD vai usar templates Tenex (depende do anterior) |
| `payment_pages_cartao_credito` | `ALTER TABLE payment_pages ADD COLUMN meio_pagamento_tipo, pagamento_online_codigo, checkout_url` | ⏸ Tenex/cartão — aplicar quando ativar em PROD |

---

## 🟡 GAPS REAIS — PROD → DEV

Estas existem em PROD e faltam em DEV. **Decisão do KLaOS:** levar pra DEV pra manter paridade.

| Migration | Recomendação |
|---|---|
| `add_collection_campaigns_permanent_labels` | ✅ Levar pra DEV |
| `add_cpf_cnpj_digits_column` | ✅ Levar pra DEV |
| `crm_email_integration` | ✅ Levar pra DEV |
| `crm_workspace_tags` | ✅ Levar pra DEV |
| `notification_center_upgrade` | ✅ Levar pra DEV |

Como em PROD elas têm `version` numérico e o arquivo `supabase/migrations/*.sql` provavelmente já existe no fs (consolidações de sprint), é só rodar `supabase db push` ou `apply_migration` espelhando o conteúdo.

---

## ✅ Diferenças apenas nominais (NÃO PRECISAM aplicar nada)

Mesmo conteúdo aplicado, nome diferente — provavelmente arquivo renomeado entre branches. Apenas registro pra ninguém ficar tentado a re-aplicar.

| DEV | PROD | Notas |
|---|---|---|
| `add_chatwoot_bot_to_agent_instances` | `20260312000001_add_chatwoot_bot_to_agent_instances` | Idêntico |
| `add_sender_type_to_agent_messages` | `20260312000002_add_sender_type_to_agent_messages` | Idêntico |
| `seed_gmb_handoff_team_map` | `seed_gmb_handoff_team_map_prod` | DEV usa team IDs do GMB DEV, PROD usa do GMB PROD (`5e0cea7f-...`) |
| `spec_l4_workspace_closer_team` | `workspace_closer_team` | Mesmo escopo |
| `curate_engines_and_dependencies_v2` | `curate_engines_and_dependencies` | Verificar se v2 tem coisa nova — provavelmente OK |
| `linkedin_daily_usage_rpc_and_searches_column` | `linkedin_daily_usage_rpc` | DEV pode ter coluna extra, **vale ler diff** |

---

## ⚪ Específicas de ambiente (NÃO migrar entre envs)

- **DEV-only (seeds/scripts dev):** `dev_drop_fatura_emissao_steps`, `dev_add_filter_meio_pagamento_and_create_regua_cartao`, `migrate_regua_to_cobr_dev`, `seed_cobr_templates_dev`, `backfill_tenex_debt_items_meio_tipo_dev`
- **PROD-only (consolidações/seeds go-live PROD):** `crm_prd_sprint0_2`, `crm_prd_sprint3_5`, `crm_prd_sprint6_12`, `golive_workspace_flags_and_crm_baseline`, `enable_tenex_multi_meio_and_subdomain_prod`, `prod_add_filter_meio_pagamento_tipo`, `backfill_tenex_debt_items_meio_tipo_prod`

Tem variantes `*_dev` / `*_prod` para o mesmo feature (filtro_meio_pagamento, backfill_tenex). É by design — não tentar unificar.

---

## 📋 Ordem sugerida de execução em PROD

1. **VALIDAR** os team IDs do Frontdesk PROD pro mapping de cancelamento/cobrança/contratos antes de qualquer coisa.
2. `apply_migration("seed_mais_saude_handoff_team_map_prod", <SQL ajustado>)` — usar IDs corretos de PROD.
3. `apply_migration("reopen_policy_data_prod", <SQL>)` — feature flag + settings.
4. `apply_migration("add_notes_column_to_crm_contacts", "ALTER TABLE crm_contacts ADD COLUMN IF NOT EXISTS notes text;")` — cabeça de série pra outras migrations CRM.
5. (Opcionais, sob demanda) Tenex/Cobrança/Payment Pages se for ativar em PROD.

## 🔍 Validação pós-aplicação

```sql
-- handoff_team_map deve estar populado
SELECT settings->'handoff_team_map' FROM workspaces WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';

-- reopen_policy enabled
SELECT enabled FROM workspace_feature_flags
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc' AND flag_name = 'reopen_policy_enabled';

-- reopen_policy settings
SELECT settings->'reopen_policy' FROM workspaces WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';

-- crm_contacts.notes existe
SELECT column_name FROM information_schema.columns
WHERE table_name='crm_contacts' AND column_name='notes';
```

---

**Pendências do lado Frontdesk (já feitas, registro):**
- ✅ Lara configurada em PROD acct=9 inbox=19 channel_whatsapp=1 agent_bot=14
- ✅ BRIDGE_SECRET alinhado (`JFve5UU5r7rGEBp/...`)
- ✅ Webhook per-phone configurado (PROD `+553184226006` → app-desk.klaos.ai)
- ✅ Display name "Mais Saúde" em PENDING_REVIEW na Meta (24-48h)
