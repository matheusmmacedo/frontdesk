# SDD KLaOS — Go-Live Mais Saúde 24h em PRODUÇÃO

> **Versão:** 1.0 — 2026-04-30
> **Owner:** agente KLaOS
> **Workspace:** `9838d25b-60de-45e7-b7b7-31cc56b12ccc` (Mais Saúde — já existe em PROD com 5 members)
> **Pré-req:** SDD master em `docs/para-frontdesk-agent/SDD_GOLIVE_PROD_MAISSAUDE.md`. Esse doc cobre apenas o lado KLaOS.

---

## 0. Sumário do que precisa ser feito no KLaOS PROD

Workspace existe em PROD (mesmo UUID que DEV) mas está vazio. Drift atual:

| Tabela | DEV (`szkzkyexagunvadzzaec`) | PROD (`ddnwemmvsuiibgbzjpwx`) | Ação |
|---|---|---|---|
| `agent_instances` (active) | 4 | **0** | Criar Lara |
| `agent_instance_tools` (Lara) | 6 enabled | 0 | Bind 6 tools (definitions globais já existem em PROD ✅) |
| `agent_prompt_versions` (Lara) | 8 | 0 | Migrar versões (ou só current) |
| `agent_documents` | 12 | 0 | Migrar metadados + blobs Supabase Storage |
| `agent_connector_credentials` (tenex) | 1 | 0 | **Recriar via admin panel** (não copiar — encriptação) |
| `agent_frontdesk_bridge` | 4 | 0 | Recriar bindings após Frontdesk bot existir |
| `crm_workspace_tags` | 4 | 0 | Migrar 4 (prioridade-alta, teste, e2e-funcional, prioritário) |
| `workspace_feature_flags` | 3 | 1 | Replicar 2 que faltam |
| `workspace_invitations` | 8 | 0 | Cliente convida via UI |
| Tool definitions globais (6 nomes) | ✅ | ✅ ok | OK |
| Régua (collection_sequences + steps) | ativa | inexistente | Criar com `status='paused'` |

---

## 1. Pré-reqs (que vão chegar do meu lado / cliente)

Antes de começar, eu (Frontdesk) entrego pra você:

- [ ] **`FRONTDESK_BRIDGE_SECRET`** — valor único pra PROD (gerado `openssl rand -base64 48`). Tem que estar IDÊNTICO no env do KLaOS PROD e no env do Frontdesk Railway PROD (klaos-production)
- [ ] **`FRONTDESK_WEBHOOK_SECRET`** — valor único pra PROD, idem (mesmo nos 2 lados)
- [ ] **`FRONTDESK_PLATFORM_API_TOKEN`** — token gerado no Frontdesk PROD (Settings → Profile → Access Tokens) — só no env do KLaOS PROD
- [ ] **Bot ID Frontdesk PROD** — `agent_bots.id` que vou criar em PROD acct=9 com URL `https://api.klaos.ai/api/webhooks/chatwoot-bot/1b092e03-9418-4352-956c-db0a560d904a`. Esse ID vai pro `agent_instances.frontdesk_chatwoot_bot_id` da Lara em PROD KLaOS
- [ ] **Inbox ID Frontdesk PROD** — `inboxes.id` que vou criar (KLaOS Cobranca) em PROD acct=9. Vai pro `agent_instances.desk_inbox_id`
- [ ] **WABA Klaus token + waba_id já existentes** — mesmo do DEV (`735467396201142`) — não muda

E do cliente (Matheus repassa):
- [ ] **Tenex API URL prod** (cliente fornece)
- [ ] **Tenex API key prod** (cliente fornece)
- [ ] **Tenex `company_id` da Mais Saúde em prod** (cliente fornece)
- [ ] **OPENAI_API_KEY prod** (validar não é dev)

---

## 2. Setar env vars KLaOS PROD (CloudPanel/Hostinger)

```env
# Database
SUPABASE_URL=https://ddnwemmvsuiibgbzjpwx.supabase.co
SUPABASE_SERVICE_KEY=<PROD_KEY>
DATABASE_URL=postgresql://...@db.ddnwemmvsuiibgbzjpwx.supabase.co:5432/postgres   # session mode pra pg-boss

# Frontdesk integration (DEVEM BATER COM Frontdesk PROD env)
FRONTDESK_PLATFORM_URL=https://app-desk.klaos.ai
FRONTDESK_PLATFORM_API_TOKEN=<vem de mim>
FRONTDESK_WEBHOOK_SECRET=<vem de mim, mesmo valor que Frontdesk env>
FRONTDESK_BRIDGE_SECRET=<vem de mim, mesmo valor que Frontdesk env>

# OpenAI
OPENAI_API_KEY=<PROD_KEY>

# Encryption — DECISÃO: secret próprio em PROD (cenário B)
# Implica recriar todas credentials encriptadas via admin UI (não copiar bytes encriptados)
ENCRYPTION_SECRET=<32 chars hex, gerar único>
OAUTH2_ENCRYPTION_KEY=<32 chars hex, gerar único>

# JWT/Cookie
JWT_SECRET=<openssl rand -base64 48>
JWT_REFRESH_SECRET=<openssl rand -base64 48>
COOKIE_SECRET=<openssl rand -base64 48>

# Scheduler / Workers
ENABLE_SCHEDULER=true
ENABLE_AI_WORKER=true
```

⚠️ **`ENCRYPTION_SECRET` mismatch DEV→PROD** = `agent_connector_credentials` copiada não decripta. Solução: recriar via admin panel em PROD (preencher campos plain text, KLaOS PROD encripta com seu próprio secret).

---

## 3. Renomear workspace + checks iniciais

```sql
-- Supabase PROD
UPDATE workspaces
SET name = 'Mais Saúde 24h'
WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- (parity com nome de DEV — evita confusão de operação)
```

```sql
-- Validar que tool_definitions (globais) estão presentes:
SELECT tool_name FROM agent_tool_definitions
WHERE tool_name IN ('adicionar_label','confirmar_pagamento','consultar_debito','gerar_link_pagamento','registrar_promessa_pagamento','transferir_para_time')
ORDER BY tool_name;
-- Esperado: 6 rows
```

---

## 4. Criar agent_instance Lara em PROD

**Dependência**: bot_id do Frontdesk PROD (Matheus envia depois de criar o bot via SQL — Fase 2 do SDD master).

```sql
-- Supabase PROD — copiar config exata da Lara DEV
INSERT INTO agent_instances (
  id, workspace_id, instance_name, agent_name,
  status, model, temperature, rag_enabled, web_search, bridge_enabled,
  voice_enabled, enabled_channels, channel_configs,
  system_prompt, collection_system_prompt,
  frontdesk_chatwoot_bot_id, desk_inbox_id,
  created_at, updated_at
) VALUES (
  '1b092e03-9418-4352-956c-db0a560d904a',  -- mesmo UUID que DEV (Frontdesk bot URL aponta pra esse path)
  '9838d25b-60de-45e7-b7b7-31cc56b12ccc',
  'lara', 'Lara',
  'active', 'gpt-5.2', 0.7, true, false, true,
  false, ARRAY['web']::text[], '{}'::jsonb,
  <SYSTEM_PROMPT_42KB_DEV>,        -- copiar exato de DEV
  <COLLECTION_SYSTEM_PROMPT_DEV>,  -- copiar exato de DEV
  <BOT_ID_FRONTDESK_PROD>,          -- vem da Fase 2 (Frontdesk side)
  <INBOX_ID_FRONTDESK_PROD>,        -- vem da Fase 2 (KLaOS Cobranca em PROD)
  NOW(), NOW()
);
```

Pra extrair o `system_prompt` de DEV:
```sql
-- Em Supabase DEV
SELECT system_prompt, collection_system_prompt
FROM agent_instances
WHERE id = '1b092e03-9418-4352-956c-db0a560d904a';
```

---

## 5. Bind 6 tools

```sql
-- Supabase PROD: tool_definition_ids são DIFERENTES de DEV. Mapear por tool_name.
INSERT INTO agent_instance_tools (id, workspace_id, agent_instance_id, tool_definition_id, is_enabled, config, created_at, updated_at)
SELECT
  gen_random_uuid(),
  '9838d25b-60de-45e7-b7b7-31cc56b12ccc',
  '1b092e03-9418-4352-956c-db0a560d904a',
  atd.id,
  true,
  '{}'::jsonb,
  NOW(), NOW()
FROM agent_tool_definitions atd
WHERE atd.tool_name IN (
  'adicionar_label','confirmar_pagamento','consultar_debito',
  'gerar_link_pagamento','registrar_promessa_pagamento','transferir_para_time'
);
-- Esperado: 6 rows inseridas
```

---

## 6. Recriar tenex credential em PROD

**Via admin panel KLaOS PROD** (não SQL — pra encriptar com `ENCRYPTION_SECRET` próprio do PROD):

1. Admin Panel → Connectors → Add → Tenex
2. Workspace: `9838d25b-60de-45e7-b7b7-31cc56b12ccc`
3. Preencher:
   - `api_url`: `<TENEX_PROD_URL>` (cliente fornece)
   - `api_key`: `<TENEX_PROD_TOKEN>` (cliente fornece)
   - `company_id`: `<TENEX_PROD_COMPANY_ID>` (cliente fornece)
   - `sync_interval_minutes`: copiar do DEV (default 60? confirmar)
4. Salvar

**Validação**:
```sql
SELECT id, workspace_id, connector_type, api_url, sync_interval_minutes
FROM agent_connector_credentials
WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- Esperado: 1 row, api_url apontando pra prod (não dev/sandbox)
```

---

## 7. Migrar agent_documents (knowledge base)

**Estratégia**: dump rows + copy blobs Supabase Storage. Embeddings já calculados (preservar — economiza tokens OpenAI).

```bash
# 1. Listar docs DEV
psql $DEV_SUPABASE_DB_URL -c "
  SELECT id, title, mime_type, file_size, storage_path
  FROM agent_documents
  WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
"
# Anotar 12 storage_paths

# 2. Pra cada doc, baixar de DEV e subir pra PROD
for path in $(psql ... extracted paths); do
  supabase storage download --project-ref szkzkyexagunvadzzaec "agent-documents/$path" -o /tmp/$path
  supabase storage upload   --project-ref ddnwemmvsuiibgbzjpwx "agent-documents/$path" /tmp/$path
done

# 3. Inserir rows em PROD (incluindo embeddings pgvector)
psql $DEV_SUPABASE_DB_URL -c "
  COPY (SELECT * FROM agent_documents WHERE workspace_id = '9838d25b-...') TO STDOUT
" | psql $PROD_SUPABASE_DB_URL -c "COPY agent_documents FROM STDIN"
```

(Adaptar credentials/connection strings conforme.)

---

## 8. Migrar crm_workspace_tags

```sql
-- Supabase PROD
INSERT INTO crm_workspace_tags (id, workspace_id, name, color, created_at, updated_at)
VALUES
  (gen_random_uuid(), '9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'prioridade-alta', '#EF4444', NOW(), NOW()),
  (gen_random_uuid(), '9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'teste',           '#F59E0B', NOW(), NOW()),
  (gen_random_uuid(), '9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'e2e-funcional',   '#2EC4B6', NOW(), NOW()),
  (gen_random_uuid(), '9838d25b-60de-45e7-b7b7-31cc56b12ccc', 'prioritário',     '#EF4444', NOW(), NOW());
```

---

## 9. workspace_feature_flags

```sql
-- DEV tem 3, PROD tem 1 — replicar 2 faltantes.
-- Antes, listar pra ver quais faltam:
SELECT * FROM workspace_feature_flags WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';  -- em DEV
SELECT * FROM workspace_feature_flags WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';  -- em PROD

-- Inserir as 2 que faltam (ajustar fields conforme schema):
-- INSERT INTO workspace_feature_flags ... ;
```

---

## 10. Recriar agent_frontdesk_bridge

Schema/exemplos não pude inspecionar profundamente — confirmar com banco DEV. Comportamento esperado: 4 rows que linkam Lara aos endpoints/eventos do Frontdesk PROD. Usar `frontdesk_chatwoot_bot_id` (que é o bot_id em PROD).

```sql
SELECT * FROM agent_frontdesk_bridge WHERE workspace_id = '9838d25b-...';
-- Inspecionar 4 rows DEV. Replicar em PROD substituindo bot_id, secret values.
```

---

## 11. Régua de cobrança (collection_sequences + steps)

**Status inicial**: `paused` em todas. Habilitar só após canary.

A régua tem 2 famílias (boleto + cartão). Templates de referência:

### Régua boleto (`cobr_*`)

| day_offset | template name | Klaus template id |
|---|---|---|
| -5 | `cobr_d5_lembrete` | `967573122486341` |
| 0 | `cobr_d0_vencimento` | `26984168144553305` |
| 1 | `cobr_d1_vencido` | `1892848914751505` |
| 7 | `cobr_d7_atraso` | `967806542305040` |
| 15 | `cobr_d15_atraso` | `1483433960183870` |
| 21 | `cobr_d21_transbordo` | `960619686455342` |
| evento | `cobr_pagto_ok` | `1254671323072863` |

### Régua cartão (`cobr_card_*`)

| day_offset | template name | Klaus template id |
|---|---|---|
| -5 | `cobr_card_d5_lembrete` | `2001794427103401` |
| 0 | `cobr_card_d0_vencimento` | `982392961155241` |
| 1 | `cobr_card_d1_recusado` | `1274433947657535` |
| 7 | `cobr_card_d7_atraso_v2` ⚠️ v2 | `3621993874631787` |
| 15 | `cobr_card_d15_atraso_v2` ⚠️ v2 | `2125470961358142` |
| 21 | `cobr_card_d21_transbordo` | `5414433888782575` |
| evento | `cobr_card_pagto_ok` | `1450363883504132` |

**Filtro `meio_pagamento_tipo`**: aplicar nas régua cartão apenas (`tipo IN (1, 11, 12)`). Doc completa em `docs/para-klaos-agent/REGUA_CARTAO_E_LARA_FIX.md`.

⚠️ **Não habilitar `status='active'`** até canary aprovado (Fase 5 do SDD master).

---

## 12. Smoke tests KLaOS-side

1. **Webhook bridge funciona**:
   ```bash
   curl -X POST "https://api.klaos.ai/api/webhooks/klaos/bridge-event" \
     -H "X-Bridge-Secret: $FRONTDESK_BRIDGE_SECRET" \
     -H "Content-Type: application/json" \
     -d '{"type":"manual_transfer_to_bot","conv_display_id":1,"workspace_id":"9838d25b-60de-45e7-b7b7-31cc56b12ccc","reason":"smoke-test"}'
   ```
   Esperado: 200 OK ou erro semântico (não 401/403).

2. **Scheduler ativo**:
   - Logs: `grep "[Scheduler]" /var/log/klaos-backend.log` → deve dizer "✅ Running via pg-boss"
   - `collectionDispatch` agendado a cada 1min

3. **Lara responde via web widget**:
   - Abrir web widget de teste do workspace
   - Conversa com Lara → ver tools sendo chamadas (logs)

4. **Tools tenex funcionam**:
   - Testar `consultar_debito` com CPF de teste — ver request indo pro Tenex prod (logs)

---

## 13. Validação final

```sql
-- Supabase PROD
SELECT
  (SELECT name FROM workspaces WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc') AS workspace_name,
  (SELECT COUNT(*) FROM agent_instances WHERE workspace_id = '9838d25b-...' AND deleted_at IS NULL) AS agents,
  (SELECT COUNT(*) FROM agent_instance_tools WHERE agent_instance_id = '1b092e03-9418-4352-956c-db0a560d904a') AS lara_tools,
  (SELECT COUNT(*) FROM agent_documents WHERE workspace_id = '9838d25b-...') AS docs,
  (SELECT COUNT(*) FROM agent_connector_credentials WHERE workspace_id = '9838d25b-...') AS connectors,
  (SELECT COUNT(*) FROM agent_frontdesk_bridge WHERE workspace_id = '9838d25b-...') AS bridges,
  (SELECT COUNT(*) FROM crm_workspace_tags WHERE workspace_id = '9838d25b-...') AS tags;
-- Esperado: 'Mais Saúde 24h', 1, 6, 12, 1, 4, 4
```

---

## 14. Rollback KLaOS-side

- Lara: `UPDATE agent_instances SET deleted_at = NOW() WHERE id = '1b092e03-...';`
- Tools: `DELETE FROM agent_instance_tools WHERE agent_instance_id = '1b092e03-...';`
- Documents: soft-delete rows + manter blobs em Storage por 7 dias
- Tenex credential: marca `is_active=false` no admin panel
- Régua: `UPDATE collection_campaigns SET status='paused' WHERE workspace_id='9838d25b-...';`

---

## Histórico

- **2026-04-30** — v1.0. Drift identificado via Supabase MCP comparando szkzkyexagunvadzzaec (DEV) vs ddnwemmvsuiibgbzjpwx (PROD).
