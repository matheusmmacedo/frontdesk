## B3 — `waba_number_assignments` (G43) — T+25

**Objetivo:** ligar o `waba_number` da Blue Care ao inbox recém-criado. **Obrigatório antes de B4.**

**Por que antes do sync de templates:** `wabaNumber.service.ts:252-389` tem **dois caminhos**. Com assignment ativo + conta frontdesk, ele lê `inbox.message_templates` do Chatwoot (que respeita o filtro de prefixo do canal). **Sem assignment, cai em `syncTemplatesFromMeta`, que lê `/{waba_id}/message_templates` SEM NENHUM FILTRO** — na WABA compartilhada isso traz os 21 templates do Mais Saúde e grava todos no workspace da Blue Care. Rodar o sync antes de B3 não é só "não funciona", é **ativamente sujo**.

> **NÃO usar `POST /api/waba/numbers/:id/assign`.** `wabaNumberAssignment.service.ts:52-122` (`assignToInbox`) **não aceita inbox existente** — ele chama `frontdeskAccountApi.createWabaInbox` e **cria um inbox WhatsApp NOVO** na conta 12. Como B2 já criou o inbox, o POST criaria um **segundo inbox duplicado**, com outro `webhook_verify_token`, e o número passaria a ter dois canais. Além disso o service (linhas 100-110) **nunca preenche `frontdesk_inbox_id`** — só `chatwoot_inbox_id` — o que quebra `wabaNumber.service.ts:497-529` (`enrichAssignments` faz join de `frontdesk_inbox_id` contra `frontdesk_inboxes.chatwoot_inbox_id`).

**RLS está ON nesta tabela: rodar como service_role (SQL Editor do Supabase), não com chave anon.**

### PASSO 1 — pré-check (esperado: `t,t,t,t`)
```sql
SELECT
  (SELECT count(*) FROM waba_numbers
     WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
       AND phone_number_id='<PHONE_NUMBER_ID>' AND deleted_at IS NULL
       AND status IN ('verified','active')) = 1                                   AS ok_numero,
  (SELECT count(*) FROM waba_number_assignments
     WHERE frontdesk_inbox_id=<INBOX_ID_PROD> AND is_active) = 0                  AS ok_inbox_livre,
  (SELECT count(*) FROM waba_number_assignments
     WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5') = 0               AS ok_sem_assignment,
  (SELECT count(*) FROM waba_number_assignments
     WHERE waba_number_id='98cee5da-caa9-48a6-bcb0-9387191b909d' AND is_active)=1 AS ms_intacto_antes;
```

### PASSO 2 — INSERT idempotente
Espelha a forma da linha do Mais Saúde (`frontdesk_inbox_id = chatwoot_inbox_id`). O `waba_number_id` é resolvido por SELECT — **nenhum UUID de número é digitado à mão**.

```sql
INSERT INTO waba_number_assignments
  (workspace_id, waba_number_id, assignment_type, frontdesk_inbox_id,
   frontdesk_account_id, agent_instance_id, chatwoot_inbox_id, is_active)
SELECT
  '6125b945-641c-4255-9cf5-81bbf2387ef5',
  n.id,
  'inbox',
  <INBOX_ID_PROD>,
  '9296c382-784a-404e-96fc-65b98309f83e',   -- frontdesk_accounts da conta 12
  NULL,                                      -- agent_instance_id NULL DE PROPOSITO (MS PROD tambem e NULL)
  <INBOX_ID_PROD>,
  true
FROM waba_numbers n
WHERE n.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND n.phone_number_id='<PHONE_NUMBER_ID>'
  AND n.deleted_at IS NULL
  AND n.status IN ('verified','active')
  AND NOT EXISTS (SELECT 1 FROM waba_number_assignments a
                  WHERE a.waba_number_id=n.id AND a.is_active)
RETURNING id, workspace_id, waba_number_id, frontdesk_inbox_id, chatwoot_inbox_id, is_active;
```
**Anotar o `id` retornado** — é o alvo da reversão.

**Não flipar `status` para `'active'`:** o MS opera com `'verified'` e o scheduler de sync aceita `['verified','active']` (`scheduler.service.ts:2033-2036`).

**O vínculo da ANA com o inbox é B6 (`agent_bot_inboxes` + `agent_frontdesk_bridge`), não este campo.** Há FK `waba_number_assignments_agent_instance_id_fkey` — qualquer UUID inventado quebra o INSERT.

### Verificação
```sql
SELECT a.id, w.name AS workspace, n.phone_number, n.phone_number_id,
       a.assignment_type, a.frontdesk_inbox_id, a.chatwoot_inbox_id,
       a.frontdesk_account_id, a.agent_instance_id, a.is_active
FROM waba_number_assignments a
JOIN workspaces w ON w.id=a.workspace_id
JOIN waba_numbers n ON n.id=a.waba_number_id
ORDER BY a.created_at;
```
**Esperado: exatamente 2 linhas na tabela inteira.**

| workspace | phone_number | phone_number_id | tipo | fd_inbox | cw_inbox | frontdesk_account_id | agent_instance | ativo |
|---|---|---|---|---|---|---|---|---|
| Mais Saúde 24h | +553184226006 | 1111100338751985 | inbox | 19 | 19 | 22db254b-... | NULL | true |
| Blue Care | `<PHONE_NUMBER>` | `<PHONE_NUMBER_ID>` | inbox | `<INBOX_ID_PROD>` | `<INBOX_ID_PROD>` | 9296c382-... | NULL | true |

```sql
SELECT (SELECT count(*) FROM waba_number_assignments)=2 AS total_2,
       (SELECT count(*) FROM waba_number_assignments
          WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND is_active)=1 AS bc_1_ativa,
       (SELECT count(*) FROM waba_number_assignments
          WHERE id='669e12e4-aabb-44f1-a370-ab36b6572f3d' AND is_active
            AND frontdesk_inbox_id=19)=1 AS ms_intacto,
       (SELECT count(*) FROM waba_number_assignments
          WHERE frontdesk_inbox_id IS DISTINCT FROM chatwoot_inbox_id)=0 AS ids_coerentes;
-- esperado: t,t,t,t
```

**Se falhar com `unique_violation`** no índice `idx_waba_one_number_per_inbox` (UNIQUE global sobre `frontdesk_inbox_id` WHERE `is_active AND assignment_type='inbox'`): o `<INBOX_ID_PROD>` foi digitado como **19** (inbox do MS). O banco protegeu — reconferir o id.

**Reversão:**
```sql
DELETE FROM waba_number_assignments
 WHERE id='<ID_RETORNADO>' AND workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';
-- esperado: DELETE 1
```
**Proibido:** qualquer `DELETE`/`UPDATE` sem `workspace_id='6125b945-...'`. Um "rollback limpa tudo" apaga a linha do Mais Saúde e `wabaWebhook.service.ts:35-38` passa a descartar mensagem de entrada dele.

---

## B4 — Sincronizar os templates da Blue Care (G44) — T+30

**Objetivo:** popular `waba_templates` do workspace BC PROD (hoje: 0 linhas; a tabela tem 21, todas do MS).

**Pré-condição já cumprida em B2:** `provider_config.template_filter = {"prefix_whitelist":["bluecare_"]}` no canal da BC.

### Opção A (preferida) — UI
KLaOS PROD (`app.klaos.ai`) → **trocar o workspace ativo para Blue Care** (obrigatório: sem isso o backend resolve pelo `last_workspace_id` e a chamada retorna 500 `WABA number not found`) → Cobrança → campanha "Cobrança Oficial Boleto" → seção "Templates WhatsApp Business" → **Sincronizar**.
Obs.: essa seção só aparece se a campanha já estiver com o inbox WABA vinculado — ou seja, **depois de B8**. Se ainda não fez B8, use a Opção B.

### Opção B — API
```bash
curl -X POST "https://api.klaos.ai/api/waba/numbers/<WABA_NUMBER_ID_BC>/sync-templates" \
  -H "Authorization: Bearer $KLAOS_JWT" \
  -H "x-workspace-id: 6125b945-641c-4255-9cf5-81bbf2387ef5"
```
**Esperado:** `{"success":true,"data":{"synced":17}}` (ou 12 se só os da régua existirem na WABA).

### Opção C — esperar
O job `wabaTemplateSync` roda `0 4 * * *` (04:00 UTC / 01:00 BRT) para todo `waba_number` com status `verified|active`. **Não contar com isso no dia do go-live.**

> **PROIBIDO:** `POST /api/v1/accounts/12/whatsapp_connections/:id/sync_templates` (nível **conexão**). Cai em `custom/app/services/whatsapp_connections/meta/template_sync_service.rb#propagate_to_channels`, que escreve `message_templates` em **TODOS** os canais ligados à conexão — inclusive o do Mais Saúde. A rota certa, que o KLaOS usa por baixo, é a **per-inbox**: `POST /api/v1/accounts/12/inboxes/<INBOX_ID_PROD>/sync_templates`.

### Verificação A — contagem e isolamento
```sql
SELECT w.name AS workspace, count(*) AS total,
       count(*) FILTER (WHERE t.name LIKE 'bluecare\_%') AS bluecare,
       count(*) FILTER (WHERE t.status='APPROVED') AS aprovados
FROM waba_templates t JOIN workspaces w ON w.id=t.workspace_id
GROUP BY 1 ORDER BY 1;
```
**Esperado: 2 linhas.** Blue Care → total 17, bluecare 17, aprovados 17 (aceitável 12/12/12). Mais Saúde → total **21**, bluecare **0**, aprovados 21.
**Se aparecer `bluecare > 0` na linha do Mais Saúde: ABORTAR e reverter.**

### Verificação B — os 12 nomes que as réguas exigem
```sql
SELECT n.nome, (t.id IS NOT NULL) AS existe, t.status, t.id
FROM (VALUES
 ('bluecare_cobr_d5_lembrete_v2'),('bluecare_cobr_d0_vencimento_v2'),('bluecare_cobr_d1_vencido_v3_bc'),
 ('bluecare_cobr_d7_atraso_v2'),('bluecare_cobr_d15_atraso_v2'),('bluecare_cobr_d21_transbordo_v2'),
 ('bluecare_cobr_card_d5_lembrete_v2'),('bluecare_cobr_card_d0_vencimento_v2'),('bluecare_cobr_card_d1_recusado_v2_bc'),
 ('bluecare_cobr_card_d7_atraso_v2_bc'),('bluecare_cobr_card_d15_atraso_v2_bc'),('bluecare_cobr_card_d21_transbordo_v2')
) AS n(nome)
LEFT JOIN waba_templates t
  ON t.name=n.nome AND t.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND t.language='pt_BR'
ORDER BY 2, 1;
-- ESPERADO: 12 linhas, existe=true e status='APPROVED' nas 12
```

> **ATENÇÃO — os nomes de cartão têm sufixo `_bc` em d1/d7/d15.** A lista que circulou no G44 estava errada nesses 3. Usar exatamente a lista acima.

**Meta template ids conferidos (cenário WABA compartilhada):**

| template | meta_template_id |
|---|---|
| bluecare_cobr_d5_lembrete_v2 | 1353941749540990 |
| bluecare_cobr_d0_vencimento_v2 | 1018192310983337 |
| bluecare_cobr_d1_vencido_v3_bc | 1028855780120937 |
| bluecare_cobr_d7_atraso_v2 | 1039716992086966 |
| bluecare_cobr_d15_atraso_v2 | 1958879691497746 |
| bluecare_cobr_d21_transbordo_v2 | 1931460250883125 |
| bluecare_cobr_card_d5_lembrete_v2 | 1743852886762543 |
| bluecare_cobr_card_d0_vencimento_v2 | 2248117279287383 |
| bluecare_cobr_card_d1_recusado_v2_bc | 1541558293927097 |
| bluecare_cobr_card_d7_atraso_v2_bc | 1004853242373453 |
| bluecare_cobr_card_d15_atraso_v2_bc | 1310489300887274 |
| bluecare_cobr_card_d21_transbordo_v2 | 3421787724651751 |

(+5 auxiliares também APPROVED e não usados em step: `bluecare_cobr_pagto_ok_v2`, `bluecare_cobr_card_pagto_ok_v2`, `bluecare_cobr_cobrar_agora_v2`, `bluecare_cobr_cobrar_agora_card_v2`, `bluecare_saudacao_inicial_ok_v2`.)

### Verificação C — nenhum template com host de dev
```sql
SELECT t.name, t.status FROM waba_templates t
JOIN waba_numbers n ON n.id = t.waba_number_id
WHERE n.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND n.phone_number_id = '<PHONE_NUMBER_ID>'
  AND to_jsonb(t)::text ~* '(app-dev\.klaos|app-desk-dev|-dev\.klaos)';
-- esperado: 0 linhas
```
Se algum `bluecare_*` voltar com botão apontando para host de dev, ele foi aprovado errado na Meta e precisa de **template novo** — não adianta corrigir no banco: o botão vive no template aprovado.

### Verificação D — regressão do Mais Saúde (repetir no dia seguinte, após 04:00 UTC)
```sql
SELECT count(*) AS ms_total,
       count(*) FILTER (WHERE name LIKE 'bluecare%') AS ms_bluecare,
       max(last_synced_at)
FROM waba_templates WHERE waba_number_id='98cee5da-caa9-48a6-bcb0-9387191b909d';
-- ESPERADO: ms_total=21, ms_bluecare=0
```

### Verificação E — visual
No Frontdesk PROD: abrir conversa no inbox 19 (MS), clicar no seletor de template → **nenhum `bluecare_*`**. Repetir no inbox da BC → **só `bluecare_*`**.

**Reversão (ordem importa — não há FK de `collection_sequence_steps.waba_template_id`):**
```sql
-- 1) se B5 ja rodou, zerar os vinculos PRIMEIRO
UPDATE collection_sequence_steps SET waba_template_id = NULL
WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';   -- 12 linhas
-- 2) so entao apagar
DELETE FROM waba_templates WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';
```
Na ordem errada (delete antes do UPDATE), o engine não manda mensagem torta — `collectionEngine.service.ts:4470-4515` trata como **fail-closed**, grava `message_failed`, cria notification `collection_error` e chama `pausePermafailViaReconciler` com motivo `waba_template_missing`. O estrago é que os enrollments ficam em permafail e **o sweep de 30 min não reabre** — cada um tem que ser destravado na mão.

**Zero risco na Meta:** `sync-templates` só **LÊ** `/{waba_id}/message_templates`. Nenhuma reclassificação de categoria, nenhum lock de 24h.

---

## B5 — Vincular os 12 steps aos templates (G45) — T+40

**Objetivo:** preencher `waba_template_id` nos 12 steps. Hoje os 12 estão NULL e caem 100% no branch fail-closed de `collectionEngine.service.ts:4294` (`if (!templateIdEfetivo && (step.channel ?? 'whatsapp') === 'whatsapp'`) → `logEvent 'message_failed'`, devolve o claim (`UPDATE collection_enrollments SET last_dispatch_at = NULL`) e `return`. Com as campanhas `paused` não há dano hoje; **no primeiro unpause seria 100% de falha silenciosa nos 94 enrollments**.

**Não há FK** de `collection_sequence_steps.waba_template_id` para `waba_templates` (`pg_constraint` só mostra `campaign_id_fkey` e `workspace_id_fkey`). E `collectionEngine.service.ts:4310-4314` busca o template **só por `.eq('id', ...)` — sem filtro de workspace e sem filtro de status**. É isso que transforma um UPDATE mal escopado em incidente cross-tenant.

**Sobre casar por nome:** a ressalva "não usar `template_message` como fonte" vale para o **Mais Saúde** (step boleto 1 do MS tem `template_message '[Template: fatura_lembrete_5dias]'` mas `waba_templates.name='cobr_d5_lembrete'` — divergem). Para a **Blue Care é o oposto**: em DEV os 12 `template_message` batem **caractere a caractere** com `waba_templates.name`. É seguro **e** é a única fonte disponível — mas tem que ser conferido no dry-run.

### PASSO 0 — GATE
```sql
SELECT count(*) FILTER (WHERE name LIKE 'bluecare!_%' ESCAPE '!'
                          AND status='APPROVED' AND language='pt_BR') AS bc_aprovados,
       count(*) FILTER (WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc') AS ms_intactos
FROM public.waba_templates
WHERE workspace_id IN ('6125b945-641c-4255-9cf5-81bbf2387ef5','9838d25b-60de-45e7-b7b7-31cc56b12ccc');
-- ESPERADO: bc_aprovados >= 12 e ms_intactos = 21.
-- Se ms_intactos != 21, o sync comeu template do MS: ABORTE.
```

### PASSO 1 — DRY-RUN (obrigatório; 12 linhas, ZERO com id nulo)
```sql
WITH mapa(step_id, template_name) AS (VALUES
  ('2847e70e-c8fb-452f-a126-1fb59d36acac'::uuid,'bluecare_cobr_d5_lembrete_v2'),
  ('0179dd29-265b-4e78-859e-7903a0b36bb5'::uuid,'bluecare_cobr_d0_vencimento_v2'),
  ('b38f6ae1-0e44-4f70-a815-5fede0b5ff83'::uuid,'bluecare_cobr_d1_vencido_v3_bc'),
  ('9e4dc111-d98b-4aac-a58e-ed6585e20cbd'::uuid,'bluecare_cobr_d7_atraso_v2'),
  ('fbfe7afe-20f2-42c3-8881-b85660091d3d'::uuid,'bluecare_cobr_d15_atraso_v2'),
  ('5ff1827f-6198-4c2b-8743-9396ef1442e1'::uuid,'bluecare_cobr_d21_transbordo_v2'),
  ('b0bb3816-cd48-4c79-9699-6bea33478445'::uuid,'bluecare_cobr_card_d5_lembrete_v2'),
  ('803332b2-0c65-4c04-a6af-8ed41e233f08'::uuid,'bluecare_cobr_card_d0_vencimento_v2'),
  ('e110a050-1a1e-4971-853c-873af55aae40'::uuid,'bluecare_cobr_card_d1_recusado_v2_bc'),
  ('a8eff75b-cce7-406e-b406-ed7a3193c94e'::uuid,'bluecare_cobr_card_d7_atraso_v2_bc'),
  ('ae4c5aae-d81b-4b03-b23b-e0b2cca785e1'::uuid,'bluecare_cobr_card_d15_atraso_v2_bc'),
  ('3afcba6b-1f6b-4bde-8216-c72cd48368ca'::uuid,'bluecare_cobr_card_d21_transbordo_v2')
)
SELECT s.step_order, c.payment_type, m.template_name, s.template_message,
       t.id AS waba_template_id, t.status, t.language, t.waba_number_id
FROM mapa m
JOIN public.collection_sequence_steps s ON s.id = m.step_id
JOIN public.collection_campaigns c ON c.id = s.campaign_id
LEFT JOIN public.waba_templates t
       ON t.name = m.template_name
      AND t.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
      AND t.language = 'pt_BR' AND t.status = 'APPROVED'
ORDER BY c.payment_type, s.step_order;
```
**Esperado:** 12 linhas; `waba_template_id` **não nulo** nas 12; `s.template_message = '[Template: ' || m.template_name || ']'` nas 12; `t.waba_number_id` **igual nas 12**.

**Se alguma linha vier NULL:** o template não foi aprovado/sincronizado ou foi recriado com outro sufixo (ex.: `_v3` para destravar o lock de 24h da Meta). **Não improvise o nome** — corrija na Meta/re-sincronize, ou ajuste a linha do VALUES conscientemente. **Não rode o PASSO 2 com dry-run incompleto.**

### PASSO 2 — UPDATE
```sql
BEGIN;
WITH mapa(step_id, template_name) AS (VALUES
  -- (repetir os mesmos 12 pares do PASSO 1)
  ('2847e70e-c8fb-452f-a126-1fb59d36acac'::uuid,'bluecare_cobr_d5_lembrete_v2'),
  ('0179dd29-265b-4e78-859e-7903a0b36bb5'::uuid,'bluecare_cobr_d0_vencimento_v2'),
  ('b38f6ae1-0e44-4f70-a815-5fede0b5ff83'::uuid,'bluecare_cobr_d1_vencido_v3_bc'),
  ('9e4dc111-d98b-4aac-a58e-ed6585e20cbd'::uuid,'bluecare_cobr_d7_atraso_v2'),
  ('fbfe7afe-20f2-42c3-8881-b85660091d3d'::uuid,'bluecare_cobr_d15_atraso_v2'),
  ('5ff1827f-6198-4c2b-8743-9396ef1442e1'::uuid,'bluecare_cobr_d21_transbordo_v2'),
  ('b0bb3816-cd48-4c79-9699-6bea33478445'::uuid,'bluecare_cobr_card_d5_lembrete_v2'),
  ('803332b2-0c65-4c04-a6af-8ed41e233f08'::uuid,'bluecare_cobr_card_d0_vencimento_v2'),
  ('e110a050-1a1e-4971-853c-873af55aae40'::uuid,'bluecare_cobr_card_d1_recusado_v2_bc'),
  ('a8eff75b-cce7-406e-b406-ed7a3193c94e'::uuid,'bluecare_cobr_card_d7_atraso_v2_bc'),
  ('ae4c5aae-d81b-4b03-b23b-e0b2cca785e1'::uuid,'bluecare_cobr_card_d15_atraso_v2_bc'),
  ('3afcba6b-1f6b-4bde-8216-c72cd48368ca'::uuid,'bluecare_cobr_card_d21_transbordo_v2')
)
UPDATE public.collection_sequence_steps s
   SET waba_template_id = t.id, updated_at = now()
  FROM mapa m
  JOIN public.waba_templates t
    ON t.name = m.template_name
   AND t.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND t.language = 'pt_BR' AND t.status = 'APPROVED'
 WHERE s.id = m.step_id
   AND s.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND s.campaign_id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46')
   AND s.waba_template_id IS NULL;
-- LER O CONTADOR. 'UPDATE 12' -> COMMIT;  Qualquer outro numero -> ROLLBACK;
COMMIT;
```

As 4 cláusulas de escopo do WHERE são **redundantes de propósito**: cada uma sozinha já impede tocar os 12 steps do Mais Saúde. **Não remova nenhuma para "simplificar".**

**Não usar UPDATE por regexp em cima de `template_message`.** Funciona hoje na BC, mas é a mesma heurística que já está errada no Mais Saúde.

### Verificação
```sql
SELECT c.payment_type, s.step_order, s.day_offset, s.chatwoot_label,
       t.name AS template_vinculado, t.status, t.language,
       (s.template_message = '[Template: ' || t.name || ']') AS nome_bate
FROM public.collection_sequence_steps s
JOIN public.collection_campaigns c ON c.id = s.campaign_id
LEFT JOIN public.waba_templates t ON t.id = s.waba_template_id
WHERE s.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
ORDER BY c.payment_type, s.step_order;
-- 12 linhas, 12 com template vinculado, 12 APPROVED, 12 pt_BR, 12 nome_bate=true
```

```sql
SELECT
 (SELECT count(*) FROM public.collection_sequence_steps
    WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND waba_template_id IS NULL) AS bc_null,      -- 0
 (SELECT count(*) FROM public.collection_sequence_steps
    WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc' AND waba_template_id IS NULL) AS ms_null,      -- 0
 (SELECT count(*) FROM public.collection_sequence_steps s
    JOIN public.waba_templates t ON t.id=s.waba_template_id
   WHERE s.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
     AND t.workspace_id <> s.workspace_id) AS vazamento_cross_tenant,                                        -- 0
 (SELECT count(*) FROM public.collection_sequence_steps s
    LEFT JOIN public.waba_templates t ON t.id=s.waba_template_id
   WHERE s.waba_template_id IS NOT NULL AND t.id IS NULL) AS ponteiros_orfaos_global;                        -- 0
```

**Reversão:**
```sql
UPDATE public.collection_sequence_steps SET waba_template_id = NULL, updated_at = now()
 WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND campaign_id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46');
-- ESPERADO: UPDATE 12
```
O estado revertido é o estado atual (fail-closed): a régua não envia nada — preferível a enviar errado.

**Regra permanente:** o vínculo por id é estável entre syncs (upsert `onConflict waba_number_id,name,language` preserva o id), **mas quebra se o template for renomeado na Meta** — inclusive pelo truque de criar `_v3`. Nesse caso o sync deleta a linha antiga, o step fica com UUID órfão e o enrollment vai para permafail `waba_template_missing`. **Toda vez que mexer em template na Meta, rodar de novo o gate `ponteiros_orfaos_global = 0`.**

---

## B6 — Ligar a ANA ao inbox: agent_bot + bridge (G41 + G42) — T+50

**Objetivo:** criar `agent_bot_inboxes` (conta 12) e `agent_frontdesk_bridge` (workspace BC).

**Caminho recomendado (faz os dois de uma vez):**
```
POST https://app.klaos.ai/api/frontdesk/bridge/activate/<ANA_ID_PROD>
Headers: sessao/token de owner|admin do workspace Blue Care PROD
Body: {"inboxId": <INBOX_ID_PROD>, "inboxName": "<INBOX_NAME>"}
```
Equivalente por clique: KLaOS → workspace **Blue Care** → Agentes → ANA → card "Inbox" → "Add to Inbox" → escolher o inbox → ativar.

> **O workspace vem do middleware de sessão, NÃO do body.** Se o operador estiver com o workspace Mais Saúde selecionado, a chamada cria/altera bridge do MS. **Conferir o seletor antes do clique.**

`activateBridge` (`frontdeskBridge.service.ts:576-668`) cria a linha em `agent_frontdesk_bridge` (`is_active=true`) **e** resolve G41 via `ensureAgentBot` → `setInboxAgentBot`.

### Corrigir o que a API NÃO grava
`activateBridge` grava **só** `frontdesk_inbox_id`, `frontdesk_inbox_name` e `is_active=true`. **Não grava `channel_type`** (fica no default `'web'`), **não grava `frontdesk_bot_id`** (fica NULL) e deixa `auto_create_crm_*` no default **true**.

```sql
UPDATE agent_frontdesk_bridge b
   SET channel_type            = 'whatsapp',
       mirror_all_messages     = false,
       auto_create_crm_contact = false,   -- MS usa true; ver decisao abaixo
       auto_create_crm_deal    = false,
       frontdesk_inbox_name    = '<INBOX_NAME>',
       frontdesk_bot_id        = ai.frontdesk_chatwoot_bot_id,
       is_active               = true,
       updated_at              = now()
  FROM agent_instances ai
 WHERE ai.id = b.agent_instance_id
   AND b.workspace_id      = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND b.agent_instance_id = '<ANA_ID_PROD>'
   AND b.frontdesk_inbox_id = <INBOX_ID_PROD>;
-- esperado: UPDATE 1. Se voltar 0, a bridge nao foi criada -> use o fallback SQL.
```
**Nunca rodar este UPDATE sem as 3 cláusulas de WHERE.**

**Decisão `auto_create_crm_*`:** não é cosmético. `frontdeskBridge.controller:613-618` chama `conversationCrmBridge.processNewConversation` em **toda** conversa nova. Com `true`, cada um dos 641 devedores vira contato+deal no CRM. MS usa `true`, BC DEV usa `false`. **Recomendo `false`** para inbox de cobrança, salvo decisão explícita do cliente.

### Fallback SQL (se `activate` falhar por token/permissão)
```sql
INSERT INTO agent_frontdesk_bridge
  (workspace_id, agent_instance_id, frontdesk_inbox_id, frontdesk_inbox_name,
   frontdesk_bot_id, is_active, mirror_all_messages, channel_type,
   auto_create_crm_contact, auto_create_crm_deal)
SELECT '6125b945-641c-4255-9cf5-81bbf2387ef5', ai.id, <INBOX_ID_PROD>, '<INBOX_NAME>',
       ai.frontdesk_chatwoot_bot_id, true, false, 'whatsapp', false, false
  FROM agent_instances ai
 WHERE ai.id = '<ANA_ID_PROD>'
   AND ai.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND ai.deleted_at IS NULL;
```
**SEM `ON CONFLICT`.** O índice `idx_agent_frontdesk_bridge_inbox_unique` é UNIQUE em `(frontdesk_inbox_id)` **sem workspace** — um `ON CONFLICT` **sequestraria a linha do Mais Saúde**. Se der duplicate key, **PARE**: `<INBOX_ID_PROD>` já pertence a outra bridge (inbox 19 = MS).

No fallback SQL, `agent_bot_inboxes` **não** é criado. Fazer à parte:
```
POST https://app-desk.klaos.ai/api/v1/accounts/12/inboxes/<INBOX_ID_PROD>/set_agent_bot
Header: api_access_token: <TOKEN_KLAUS_CONTA_12>
Body: { "agent_bot": <ANA_BOT_ID_PROD> }
Esperado: HTTP 200, corpo vazio.
```
(Rota `config/routes.rb:221` → `inboxes_controller.rb:57`. O controller faz `@inbox.agent_bot_inbox || AgentBotInbox.new(inbox: @inbox)` — rodar 2× não duplica.)

Último recurso, SQL defensivo (a tabela **não tem unique index nem FK** — só a PK):
```sql
INSERT INTO agent_bot_inboxes (account_id, inbox_id, agent_bot_id, status, created_at, updated_at)
SELECT i.account_id, i.id, <ANA_BOT_ID_PROD>, 0, now(), now()
FROM inboxes i
WHERE i.id = <INBOX_ID_PROD>
  AND i.account_id = 12
  AND EXISTS (SELECT 1 FROM agent_bots b WHERE b.id = <ANA_BOT_ID_PROD> AND b.account_id = 12)
  AND NOT EXISTS (SELECT 1 FROM agent_bot_inboxes a WHERE a.inbox_id = i.id)
RETURNING id, account_id, inbox_id, agent_bot_id, status;
```

> **ARMADILHA DE ENUM: `status: { active: 0, inactive: 1 }`** (`app/models/agent_bot_inbox.rb:22`). **ACTIVE É ZERO.** As 4 linhas vivas de PROD estão todas com `status=0`. Quem escrever `status=1` achando que "1=ativo" **desliga o bot em silêncio** (`agent_bot_webhook_guard.rb:22` filtra `status: :active` e retorna nil).

### Verificação
```sql
-- Chatwoot PROD
SELECT abi.id, abi.account_id, abi.inbox_id, abi.agent_bot_id, abi.status,
       i.name AS inbox, i.channel_type, ab.name AS bot, ab.outgoing_url
FROM agent_bot_inboxes abi
JOIN inboxes i ON i.id=abi.inbox_id
JOIN agent_bots ab ON ab.id=abi.agent_bot_id
WHERE abi.account_id=12;
-- EXATAMENTE 1 linha; status=0; inbox='KLaOS Cobranca'; channel_type='Channel::Whatsapp';
-- outgoing_url comecando com 'https://api.klaos.ai/api/webhooks/agent-bot/' (NAO api-dev)

SELECT count(*) AS total, count(*) FILTER (WHERE inbox_id=19) AS ms_inbox19 FROM agent_bot_inboxes;
-- ANTES: total=4, ms_inbox19=1.  DEPOIS: total=5, ms_inbox19=1 (continua 1).
SELECT id, agent_bot_id, status FROM agent_bot_inboxes WHERE inbox_id=19;
-- 1 linha: id=11, agent_bot_id=14, status=0
```
**Se `ms_inbox19` virar 2, PARE e apague a linha nova imediatamente:** a cobrança da Lara passa a chamar o webhook da ANA.

```sql
-- Supabase PROD
SELECT b.id, b.frontdesk_inbox_id, b.frontdesk_inbox_name, b.channel_type,
       b.is_active, b.mirror_all_messages, b.frontdesk_bot_id,
       ai.frontdesk_chatwoot_bot_id,
       (b.frontdesk_bot_id = ai.frontdesk_chatwoot_bot_id) AS bot_id_bate,
       b.auto_create_crm_contact, b.auto_create_crm_deal
FROM agent_frontdesk_bridge b JOIN agent_instances ai ON ai.id = b.agent_instance_id
WHERE b.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
-- 1 linha; channel_type='whatsapp'; is_active=t; mirror=f; bot_id_bate=t; crm f/f

SELECT id, agent_instance_id, frontdesk_inbox_id, frontdesk_bot_id, is_active, channel_type
FROM agent_frontdesk_bridge WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- 1 linha: 92226ba2-ab8a-483d-b735-748a617a68d6 | 1b092e03-... | 19 | 14 | t | whatsapp

SELECT count(*) FROM agent_frontdesk_bridge;                              -- 3 (era 2)
SELECT count(*) FROM agent_frontdesk_bridge WHERE frontdesk_inbox_id=19;  -- 1
```

**Reversão:**
```sql
-- suave (tira do ar sem perder config)
UPDATE agent_frontdesk_bridge SET is_active = false, updated_at = now()
 WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND agent_instance_id='<ANA_ID_PROD>' AND frontdesk_inbox_id=<INBOX_ID_PROD>;

-- total
DELETE FROM agent_frontdesk_bridge
 WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND agent_instance_id='<ANA_ID_PROD>' AND frontdesk_inbox_id=<INBOX_ID_PROD>;
```
Lado Chatwoot: `POST /api/frontdesk/bridge/deactivate/<ANA_ID_PROD>` body `{"inboxId": <INBOX_ID_PROD>, "removeBot": true}`, ou `POST .../set_agent_bot` com `{"agent_bot": null}`.
Ou SQL: `DELETE FROM agent_bot_inboxes WHERE id = <ID_CRIADO> AND account_id = 12 AND inbox_id = <INBOX_ID_PROD>;` — **nunca sem `account_id=12`**: sem WHERE apaga também o vínculo id=11 do Mais Saúde e a Lara para de responder na hora.

**Não usar** `DELETE /api/frontdesk/bridge/config/<ANA_ID_PROD>` **sem** `?inboxId=` — sem ele, `deleteBridgeConfig` apaga **todas** as bridges daquele agent_instance.

---

## B7 — `default_inbox_id` e espelho `frontdesk_inboxes` (G48) — T+60

**Objetivo:** evitar que o fallback alfabético escolha o inbox errado no futuro, e destravar o provisionamento de agentes.

**O fallback é pior do que "ordem de inboxes":** `frontdeskBridge.service.ts:596-604` **não** lê a tabela espelho — chama `frontdeskAccountApi.listInboxes()` = `GET /api/v1/accounts/12/inboxes`, e o controller do fork **ordena por NOME** (`inboxes_controller.rb:11` → `order_by_name`). Logo `inboxes[0]` é o inbox **alfabeticamente primeiro** da conta 12. "KLaOS Cobranca" começa com **K**: qualquer inbox chamado Atendimento/Comercial/Financeiro/Geral vence o sorteio. E o inbox escolhido vai para `ensureAgentBot(...inboxId)` (linha 619) — o AgentBot da ANA seria plugado no inbox errado.

**Não existe API/UI para setar esse campo.** Grep em todo o repo KLaOS: `default_inbox_id` aparece só em `frontdeskProvisioning.service.ts:40` (tipo), `:1463` (zera quando deleta o inbox default) e `frontdeskBridge.service.ts:597` (leitura). **Nenhum writer.**

```sql
BEGIN;
-- fotografia antes (esperado: default_inbox_id = NULL)
SELECT id, chatwoot_account_id, chatwoot_account_name, default_inbox_id
FROM frontdesk_accounts WHERE id = '9296c382-784a-404e-96fc-65b98309f83e';

UPDATE frontdesk_accounts
SET default_inbox_id = <INBOX_ID_PROD>, updated_at = now()
WHERE id = '9296c382-784a-404e-96fc-65b98309f83e'
  AND workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND chatwoot_account_id = 12;
-- ESPERADO: UPDATE 1. Se vier 0 ou 2 -> ROLLBACK.
COMMIT;
```

**Variante segura** (deriva o id da bridge de B6, elimina erro de digitação):
```sql
UPDATE frontdesk_accounts fa
SET default_inbox_id = b.frontdesk_inbox_id, updated_at = now()
FROM agent_frontdesk_bridge b
WHERE fa.id = '9296c382-784a-404e-96fc-65b98309f83e'
  AND b.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND b.channel_type = 'whatsapp' AND b.is_active = true
  AND (SELECT count(*) FROM agent_frontdesk_bridge x
       WHERE x.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
         AND x.channel_type = 'whatsapp' AND x.is_active = true) = 1;
```

### Espelho `frontdesk_inboxes` (recomendado, mesmo lote)
`provisionUser` (`frontdeskProvisioning.service.ts:690-704`) só adiciona agente novo ao inbox marcado `is_default=true` **nessa tabela**, e o webhook que a popularia não funciona para a conta 12 (`chatwoot_account_webhook_id` NULL + `onConflict` inválido → 42P10). Hoje BC PROD tem **0 linhas**.

```sql
INSERT INTO frontdesk_inboxes
  (workspace_id, frontdesk_account_id, chatwoot_inbox_id, name, channel_type,
   is_default, settings, created_at, updated_at)
VALUES
  ('6125b945-641c-4255-9cf5-81bbf2387ef5',
   '9296c382-784a-404e-96fc-65b98309f83e',
   <INBOX_ID_PROD>, '<INBOX_NAME>',
   'whatsapp',   -- enum frontdesk_channel_type: web_widget,api,email,whatsapp,telegram,line,sms
   true, '{}'::jsonb, now(), now())
ON CONFLICT (frontdesk_account_id, chatwoot_inbox_id) DO UPDATE
  SET name = EXCLUDED.name, is_default = true, updated_at = now();
```
**O `<INBOX_NAME>` tem que ser copiado literalmente do que ficou no Chatwoot** (com ou sem cedilha — o MS usa com Ç, o de DEV da BC é sem). Não inventar.

### Verificação
```sql
SELECT chatwoot_account_id, default_inbox_id FROM frontdesk_accounts ORDER BY chatwoot_account_id;
-- esperado 4 linhas: 9=NULL, 10=NULL, 11=NULL, 12=<INBOX_ID_PROD>
-- Qualquer valor nao-NULL em 9/10/11 = UPDATE vazado -> reverter imediatamente.

SELECT count(*) FROM frontdesk_inboxes
WHERE frontdesk_account_id='9296c382-784a-404e-96fc-65b98309f83e' AND is_default=true;
-- esperado 1 (NUNCA 2 — o codigo usa maybeSingle() e 2 linhas fazem o provisionUser desistir)
```

**Reversão:**
```sql
UPDATE frontdesk_accounts SET default_inbox_id = NULL, updated_at = now()
WHERE id = '9296c382-784a-404e-96fc-65b98309f83e'
  AND workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';

DELETE FROM frontdesk_inboxes
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND chatwoot_inbox_id = <INBOX_ID_PROD>;
```

**Gravar `<INBOX_ID_PROD>` errado é pior que deixar NULL:** o `find()` falha, cai no fallback alfabético e dá falsa sensação de configurado.

---

## B8 — `frontdesk_inbox_id` nas 2 campanhas (G46) — T+65

**Objetivo:** destravar a ativação. `collectionEngine.service.ts:250` barra `activateCampaign` sem `frontdesk_inbox_id`, e **não dá para despausar por fora**: `updateCampaignSchema` não tem `status` e `validation.middleware.ts:20` faz `req.body = schema.parse(req.body)`, descartando chave desconhecida.

O mesmo strip do zod **derruba `frontdesk_inbox_name`** — ele não está em `createCampaignSchema` nem em `updateCampaignSchema`. O wizard (`CampaignWizard.tsx:596`) monta o campo e o backend joga fora silenciosamente. **O nome só entra por SQL direto.**

`frontdesk_account_id=12` **já está correto** nas duas — não mexer.

### PARTE 1 — id do inbox pela UI (tenant-safe)
1. Logar no KLaOS e **trocar o seletor de workspace para Blue Care**.
2. Cobrança → Campanhas → "Cobrança Oficial Boleto" → Editar → passo 3 "Inbox & Times" → selecionar `<INBOX_ID_PROD>` → Salvar.
3. Repetir para "Cobrança Oficial Cartão".

Equivalente por API (o nome **não** é gravado por aqui):
```
PUT https://api.klaos.ai/api/collections/campaigns/0ad47dde-d9e6-4a28-b3d8-b170e5306340
PUT https://api.klaos.ai/api/collections/campaigns/91805b50-f05f-4858-9295-99bd6d3f8d46
Body: {"frontdesk_inbox_id": <INBOX_ID_PROD>}
```

### PARTE 2 — nome por SQL (obrigatório)
```sql
BEGIN;
UPDATE public.collection_campaigns
   SET frontdesk_inbox_name = '<INBOX_NAME>', updated_at = now()
 WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46')
   AND frontdesk_inbox_id = <INBOX_ID_PROD>
RETURNING id, name, frontdesk_inbox_id, frontdesk_inbox_name;
-- CONFERIR: EXATAMENTE 2 linhas. 0, 1, 3 ou mais -> ROLLBACK;
COMMIT;
```

### Alternativa 100% SQL (só se UI/API indisponível)
```sql
BEGIN;
DO $$ BEGIN IF <INBOX_ID_PROD> = 19 THEN
  RAISE EXCEPTION 'ABORTADO: <INBOX_ID_PROD>=19 e o inbox da Mais Saude'; END IF; END $$;

UPDATE public.collection_campaigns
   SET frontdesk_inbox_id = <INBOX_ID_PROD>, frontdesk_inbox_name = '<INBOX_NAME>',
       frontdesk_account_id = 12, updated_at = now()
 WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46')
   AND deleted_at IS NULL
RETURNING id, name, status, frontdesk_account_id, frontdesk_inbox_id, frontdesk_inbox_name;

SELECT id, frontdesk_inbox_id, status FROM public.collection_campaigns
 WHERE workspace_id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- esperado: 2 linhas, inbox=19, status='active'. Diferente -> ROLLBACK;
COMMIT;
```

**Este passo NÃO ativa nada:** `status` continua `'paused'` e `activated_at` continua NULL.

### Verificação — coerência dos três (campanha, bridge, WABA)
```sql
SELECT (SELECT DISTINCT frontdesk_inbox_id FROM collection_campaigns
          WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5') AS campanha_inbox,
       (SELECT frontdesk_inbox_id FROM agent_frontdesk_bridge
          WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND is_active=true LIMIT 1) AS bridge_inbox,
       (SELECT chatwoot_inbox_id FROM waba_number_assignments
          WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
            AND is_active=true AND assignment_type='inbox' LIMIT 1) AS waba_inbox;
-- ESPERADO: as 3 colunas iguais a <INBOX_ID_PROD>
```

```sql
SELECT count(*) FROM collection_campaigns
WHERE frontdesk_inbox_id=19 AND workspace_id <> '9838d25b-60de-45e7-b7b7-31cc56b12ccc';
-- ESPERADO: 0
```

**Prova funcional pela API** (workspace Blue Care selecionado):
```
GET https://api.klaos.ai/api/collections/campaigns/0ad47dde-d9e6-4a28-b3d8-b170e5306340/inbox-info
```
Esperado: `data != null`, `inbox_id=<INBOX_ID_PROD>`, `inbox_source='waba'`, `phone_number='<PHONE_NUMBER>'`, ANA como bridge ativa. Se `inbox_source='evolution'` ou `phone_number=null`, B3 falhou.

**Prova visual (Playwright/browser, obrigatória):** os 2 cards mostram "via `<INBOX_NAME>`" e o wizard, no passo 3, já vem com o inbox selecionado. E o inbox aparece com badge **"WABA" / "WhatsApp Business Oficial"**, não "API Não Oficial".

**Reversão:**
```sql
UPDATE public.collection_campaigns
   SET frontdesk_inbox_id = NULL, frontdesk_inbox_name = NULL, updated_at = now()
 WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46');
```
Zerar o inbox com a campanha `active` não gera envio errado — o dispatch cai em fail-closed (`collectionEngine.service.ts:4677-4694`), mas polui o log e reagenda em loop. **Pausar primeiro.**

---

## B9 — Reconferir o handoff do step 6 (G32) — T+70

Se **nenhum** salvamento do wizard de steps ocorreu depois de A13, este passo é só verificação:
```sql
SELECT c.name AS campanha, s.step_order, s.day_offset, s.is_handoff_step, s.handoff_team_id
FROM collection_sequence_steps s JOIN collection_campaigns c ON c.id = s.campaign_id
WHERE s.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5' AND s.is_handoff_step = true;
-- ESPERADO: 2 linhas, ambas com handoff_team_id = <TEAM_COBRANCA_BC>
```

**Se vier NULL** (alguém salvou o wizard e `upsertCampaignSteps` recriou as linhas com UUIDs novos), refazer casando por `step_order` em vez de UUID:
```sql
UPDATE collection_sequence_steps s
SET handoff_team_id = <TEAM_COBRANCA_BC>, updated_at = now()
WHERE s.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND s.is_handoff_step = true
  AND s.step_order = 6
  AND EXISTS (SELECT 1 FROM frontdesk_teams t
              WHERE t.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
                AND t.chatwoot_team_id = <TEAM_COBRANCA_BC>);
-- esperado: UPDATE 2
```
**Nesse caso B5 também precisa ser refeito** (os `waba_template_id` terão voltado a NULL). Rodar o gate:
```sql
SELECT count(*) FROM collection_sequence_steps
WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND waba_template_id IS NOT NULL;
-- ESPERADO: 12
```

---

## B10 — Webhook per-number na Meta (G47) — T+75

# ⚠ PONTO DE NÃO RETORNO

**A partir do momento em que este comando retorna `{"success":true}`, o `<PHONE_NUMBER>` passa a entregar mensagem de cliente real no Chatwoot da conta 12.** Tudo o que estiver mal configurado (bot, bridge, templates, filtro) aparece na frente de gente de verdade.

**Antes de executar, confirme:** B2 a B9 concluídos e verificados; A17 rodado uma última vez (gate `=0`); e registre `<DATA_HORA_GOLIVE>` = agora.

### Por que é obrigatório
`custom/config/initializers/whatsapp_connection_extensions.rb:17-21` sobrescreve `should_auto_setup_webhooks?` e retorna **false** quando `source == 'whatsapp_pool'`. **Nenhum caminho do fork configura webhook per-number automaticamente.** O comentário do `PhoneLinkerService` que diz o contrário está desatualizado.

### Pegar o verify_token REAL
**Não usar o env `WHATSAPP_VERIFY_TOKEN`.** `app/controllers/webhooks/whatsapp_controller.rb:17-21` valida **somente** contra `channel.provider_config['webhook_verify_token']` do canal cujo `phone_number` bate com a URL. O token é `SecureRandom.hex(16)` (32 chars) gerado em `phone_linker_service.rb:68`.

```sql
SELECT id, account_id, phone_number,
       provider_config->>'phone_number_id'      AS pnid,
       provider_config->>'business_account_id'  AS waba_id,
       provider_config->>'source'               AS source,
       provider_config->>'webhook_verify_token' AS verify_token
FROM channel_whatsapp WHERE phone_number = '<PHONE_NUMBER>';
-- 1 linha, account_id=12, source='whatsapp_pool', verify_token com 32 chars hex
```
Alternativa sem SQL: Frontdesk PROD → Configurações → Caixas de entrada → KLaOS Cobranca → Configuração → campo "Webhook Verify Token".

### O comando
```bash
export META_TOKEN='<SYSTEM_USER_TOKEN>'
export VERIFY_TOKEN='<VERIFY_TOKEN>'

curl -s -X POST "https://graph.facebook.com/v22.0/<PHONE_NUMBER_ID>" \
  -H "Authorization: Bearer $META_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "webhook_configuration": {
          "override_callback_uri": "https://app-desk.klaos.ai/webhooks/whatsapp/<PHONE_NUMBER>",
          "verify_token": "'"$VERIFY_TOKEN"'"
        }
      }'
```
**Esperado:** `{"success":true}`.

**Regras do `<PHONE_NUMBER>` na URL:** exatamente o mesmo texto gravado em `channel_whatsapp.phone_number`, formato `+55DDXXXXXXXXX`, com o `+` **literal**, sem espaço, sem hífen, **sem `%2B`**. Um caractere de diferença e a rota não acha o canal — o payload é descartado.

Vale para os **dois** cenários da Parte 3: na WABA compartilhada é **obrigatório** (único jeito de não brigar com o MS); em WABA própria continua sendo o recomendado (custo zero e imune a mexidas futuras em WABA-level).

> **NÃO FAZER:** `POST /735467396201142/subscribed_apps` com `override_callback_uri` da Blue Care — é o que o §4.5 do SDD do MS manda e **reescreve o fallback compartilhado da WABA**.

### Verificação imediata
```bash
# 1) estado no Meta, string identica
curl -s "https://graph.facebook.com/v22.0/<PHONE_NUMBER_ID>?fields=webhook_configuration&access_token=$META_TOKEN" | jq
# esperado: webhook_configuration.phone_number == "https://app-desk.klaos.ai/webhooks/whatsapp/<PHONE_NUMBER>"
# host app-desk.klaos.ai — NUNCA app-desk-dev

# 2) handshake (prova que o verify_token casa)
curl -i "https://app-desk.klaos.ai/webhooks/whatsapp/<PHONE_NUMBER>?hub.mode=subscribe&hub.verify_token=$VERIFY_TOKEN&hub.challenge=bc123"
# esperado: HTTP 200, body exatamente 'bc123'
# 401 {"error":"Error; wrong verify token"} -> token nao e o do canal
# 404 -> phone_number da URL nao bate com channel_whatsapp.phone_number

# 3) REGRESSAO DO MAIS SAUDE (obrigatoria)
curl -s "https://graph.facebook.com/v22.0/1111100338751985?fields=webhook_configuration&access_token=$META_TOKEN" | jq
curl -i "https://app-desk.klaos.ai/webhooks/whatsapp/+553184226006?hub.mode=subscribe&hub.verify_token=<verify_token_do_MS>&hub.challenge=ms123"
# esperado: per-number do MS INALTERADO e HTTP 200 + 'ms123'
```

Confirmar também que `<PHONE_NUMBER>` **não** está no `GlobalConfig INACTIVE_WHATSAPP_NUMBERS` (`whatsapp_controller.rb:23-32`), senão o POST é respondido com 422 e nada é enfileirado.

**Reversão (limpa, escopada ao número da BC — não toca o MS):**
```bash
curl -s -X POST "https://graph.facebook.com/v22.0/<PHONE_NUMBER_ID>" \
  -H "Authorization: Bearer $META_TOKEN" -H "Content-Type: application/json" \
  -d '{"webhook_configuration": {"override_callback_uri": ""}}'
# conferir: a chave "phone_number" desaparece do GET
```
Ou redirecionar para DEV (`https://app-desk-dev.klaos.ai/webhooks/whatsapp/<PHONE_NUMBER>`).

**Anotar ANTES de executar** a saída do GET do B0 dos 3 escopos — é o **único backup** do estado anterior; não existe histórico no Meta nem no banco.

**Risco residual aceito:** entre o POST e o smoke, mensagens recebidas podem ser perdidas (o Meta reentrega por algum tempo, sem garantia). **Fazer fora do horário da régua** (janela 08:30–18:00) para não competir com disparo.

---

## B11 — SMOKE COMPLETO (T+80, ~20 min)

Mandar **1 mensagem de um celular próprio** para `<PHONE_NUMBER>`. Não usar número de cliente real.

### Camada 1 — Meta
```bash
curl -s "https://graph.facebook.com/v22.0/<PHONE_NUMBER_ID>?fields=webhook_configuration,quality_rating,code_verification_status&access_token=$META_TOKEN" | jq
```
**Esperado:** `webhook_configuration.phone_number` com a URL de PROD; `quality_rating` presente (número novo entra em Tier 1 — normal).

### Camada 2 — Chatwoot (a mensagem chegou)
```sql
SELECT id, inbox_id, created_at FROM conversations
WHERE inbox_id = <INBOX_ID_PROD> ORDER BY id DESC LIMIT 1;
-- esperado: 1 conversa nova em menos de 30s

SELECT count(*) FROM messages m JOIN conversations c ON c.id=m.conversation_id
WHERE c.inbox_id=<INBOX_ID_PROD> AND m.message_type=0
  AND m.created_at > now() - interval '10 minutes';
-- esperado: >= 1
```
**Se 0:** checar os logs do web procurando `Inactive WhatsApp channel`. O job só aceita o payload se `channel.provider_config['phone_number_id'] == <PHONE_NUMBER_ID>` do metadata (`app/jobs/webhooks/whatsapp_events_job.rb:95-101`) — pnid divergente = **descarte silencioso**, sem erro em lugar nenhum.

### Camada 3 — Chatwoot (o bot foi ancorado)
```
GET https://app-desk.klaos.ai/api/custom/v1/accounts/12/conversations/<display_id>/gate_snapshot
Header: api_access_token: <TOKEN_KLAUS_CONTA_12>
```
**Esperado:** `{"agent_bot_id": <ANA_BOT_ID_PROD>, ...}` — **não null**. `null` significa que o gate fecha em `cw_status_unknown` e a ANA fica muda.

```sql
SELECT display_id, assignee_agent_bot_id, additional_attributes->'agent_bot_guard_log'
FROM conversations WHERE account_id=12 ORDER BY id DESC LIMIT 1;
-- esperado: assignee_agent_bot_id=<ANA_BOT_ID_PROD> e o guard log com '-> 200'
```
(Referência de que o mecanismo funciona vivo: na conta 9 são 2.295 conversas, 1.238 com `assignee_agent_bot_id` preenchido.)

### Camada 4 — KLaOS (a bridge captou)
```sql
SELECT count(*) FROM agent_conversations
 WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5'
   AND created_at > now() - interval '10 minutes';
-- esperado: >= 1
```
**Se 0:** a bridge não está captando — checar `is_active`, `frontdesk_inbox_id` e o webhook do agent-bot.

### Camada 5 — A resposta da ANA
No celular de teste, ver a resposta chegar.
**Conferir no Chatwoot que a resposta aparece assinada como o bot ("ANA"), NÃO como usuário humano.** Resposta assinada como humano = token de admin gravado no lugar do token de bot (161 vs 97 chars).
**Nenhuma resposta pode conter `[` seguido de `PENDENTE`.** Se contiver, A18 não foi aplicado.

### Camada 6 — Handoff
Escrever "quero cancelar meu plano". **Esperado:** log `[frontdeskTransferirParaTime]` com `teamName` resolvido e `source='explicit'`; e, no Frontdesk conta 12, a conversa aparecer com o time **`cancelamento` preenchido (NÃO em branco)**.
Se o time ficar em branco com HTTP 200 no log, há id pendurado — voltar ao gate de A9.
(Aguardar ≥5 min após A9 por causa do `TEAM_ENUM_TTL_MS`, ou reiniciar o server.)

### Camada 7 — Link de pagamento
Abrir 1 link `/pay/<code>` em aba anônima: **HTTP 200 com valor, vencimento, linha digitável e logo Blue Care**. Não pode cair em "Pagamento indisponível" nem 404, e o host tem que ser `app.klaos.ai` (não `localhost:5173`).

### Camada 8 — Mais Saúde intacto
```sql
-- Chatwoot
SELECT count(*) FROM inboxes WHERE account_id=9;   -- 2
SELECT count(*) FROM teams   WHERE account_id=9;   -- 6
SELECT count(*) FROM webhooks WHERE account_id=9;  -- 1
SELECT phone_number, provider_config->>'phone_number_id' FROM channel_whatsapp WHERE id=1;
-- +553184226006 / 1111100338751985
SELECT jsonb_array_length(message_templates) FROM channel_whatsapp WHERE id=1;  -- 21
SELECT provider_config->'template_filter' FROM channel_whatsapp WHERE id=1;
-- {"prefix_blacklist": ["bluecare_"]}
```
```sql
-- KLaOS: trafego do MS continua vivo
SELECT count(*) AS msgs_ultima_hora, max(created_at) AS ultima
FROM agent_messages
WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc'
  AND created_at > now() - interval '60 minutes';
-- em horario comercial: msgs_ultima_hora > 0 e "ultima" avancando
```
**Se congelar exatamente a partir do B1/B10, suspeitar de colisão de `phone_number_id`** e rodar o gate de B1 imediatamente.

---

## B12 — Ativação escalonada (T+95 e D+1)

### B12.0 — PRÉ-CONDIÇÃO DURA
```sql
SELECT count(*) FROM public.collection_sequence_steps s
  JOIN public.collection_campaigns c ON c.id = s.campaign_id
 WHERE c.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND s.waba_template_id IS NOT NULL;
-- ESPERADO: 12
```
> **Se não for 12, NÃO ATIVE.** Os enrollments viram `status='paused'` + `substate_reason='waba_template_missing'` (`collectionEngine.service.ts:4506`), e `'paused'` está na lista de skip incondicional do `autoEnrollDebtors` (`:5461-5475`) — **os devedores ficam permanentemente fora do auto-enroll, motor mudo e silencioso, sem alarme.**

Rodar também a sentinela anti-demo de A16 (`total=2, com_demo_interval=0, nome_demo=0, janela_fds=0`).

### B12.1 — ATIVAR FORA DA JANELA DE DISPARO
A janela é **seg–sex 08:30–18:00** e o cron roda a cada minuto. **Ativar depois das 18:00 BRT ou no fim de semana.**
Ativar **PRIMEIRO só a campanha BOLETO** (`0ad47dde-...`); a de cartão (`91805b50-...`) no dia seguinte.

UI: Cobranças → campanha → Ativar. Ou `POST /api/collections/campaigns/0ad47dde-d9e6-4a28-b3d8-b170e5306340/activate`.

`activateCampaign` chama `autoEnrollDebtors`, que recria os enrollments com o step e o `next_dispatch_at` **corretos para a data real**, com cap `MAX_AUTO_ENROLL_BATCH=80` por rodada (há 157 candidatos; o restante drena nos syncs seguintes).

```sql
SELECT count(*) FROM collection_enrollments
WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND status='active';
-- ESPERADO: 80. Se vier 0, autoEnroll nao rodou -> conferir auto_enroll=true
-- e o log '[CollectionEngine] Auto-enroll: no matching debtors'.
```

### B12.2 — ESCALONAR O DIA 1 (rodar IMEDIATAMENTE após ativar, ainda fora da janela)
10 disparos a cada 30 min = 20/h; ~9h30 de janela = teto de ~190/dia.
```sql
UPDATE public.collection_enrollments e
   SET next_dispatch_at = t.slot, updated_at = now()
  FROM (
    SELECT id,
           (((current_date + 1)::timestamp
             + interval '8 hours 30 minutes'
             + (((row_number() OVER (ORDER BY primary_due_date ASC, id)) - 1) / 10)
               * interval '30 minutes')
            AT TIME ZONE 'America/Sao_Paulo') AS slot
      FROM public.collection_enrollments
     WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
       AND status = 'active' AND last_dispatch_at IS NULL
  ) t
 WHERE e.id = t.id;
```
`ORDER BY primary_due_date ASC` = os mais vencidos primeiro. **Ajustar `(current_date + 1)` se ativar na sexta** (usar a segunda) — `dispatch_weekdays = {1,2,3,4,5}`.

*Mecânica:* o engine só usa este valor como "elegível a partir de"; ele **não reescreve** `next_dispatch_at` para trás (`calculateNextDispatchFromDueDate:5767` só cai em "agora" quando o alvo já passou). O escalonamento é respeitado.

```sql
SELECT min(next_dispatch_at), max(next_dispatch_at), count(*)
FROM collection_enrollments
WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND status='active';
-- min = amanha 08:30 BRT, max = min + ~3h30 para 80 linhas, ZERO com next_dispatch_at <= now()
```

### B12.3 — Dias 2 e 3
Repetir B12.2 (o auto-enroll do sync diário injeta o resto dos 157 sem escalonamento).

### B12.4 — Fim do dia 1
```sql
SELECT count(*) FROM public.collection_enrollment_events
WHERE workspace_id='6125b945-...' AND event_type='message_sent' AND created_at::date = current_date;
-- ESPERADO: <= 190. Se passar de 200 num dia, o escalonamento nao pegou — PAUSAR imediatamente.
```

E a verificação B do A15:
```sql
-- link_quebrado=0, pagina_orfa=0, due_divergente=0, linha_divergente=0, cobrando_quem_pagou=0
```

### FREIO DE EMERGÊNCIA
```sql
UPDATE public.collection_campaigns SET status='paused'
 WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';
```
O dispatcher exige `collection_campaigns.status='active'` (linha 1455) — **para em até 60s.**

---

# PARTE 3 — A DECISÃO DA WABA (G38)

## O estado hoje

`waba_numbers` em PROD tem **1 linha**: Mais Saúde, `+553184226006`, `waba_id=735467396201142`, `phone_number_id=1111100338751985`, `status=verified`, `provider=client_bm`, token de 449 chars (cifrado). Blue Care PROD: **0 linhas**. **A decisão de fato não está tomada em lugar nenhum do sistema.**

Em DEV, `waba_numbers` tem 1 linha só: a da Blue Care (`+553197286773`, **mesma WABA 735467396201142**, `phone_number_id=1088056767715946`). O workspace Mais Saúde em DEV tem 0 números — confirma o empréstimo via SQL.

Os **17 templates `bluecare_*` de DEV estão todos APPROVED / UTILITY / pt_BR** na WABA `735467396201142`, com `meta_template_id` próprio.

## Como a separação funciona hoje (e por que já funciona)

**Template no Meta é objeto de WABA, não de número.** A `GET /{waba_id}/message_templates` devolve **tudo**. A separação MS × BC é feita **no fork, por prefixo**, em `custom/config/initializers/klaos_template_filter_guard.rb` — `before_save` em `Channel::Whatsapp` lendo `provider_config['template_filter']` com `prefix_whitelist`/`prefix_blacklist`. Introduzido em `9e099996a` e endurecido em `55c079a75` (o job upstream `templates_sync_scheduler_job` de 3/3h repovoava o canal 1 do MS com 15 `bluecare_*`).

**Prova de que o filtro está ATIVO em PROD hoje:** `waba_templates` PROD tem 21 linhas, todas do MS, 0 com prefixo `bluecare`, com `last_synced_at` de madrugada — e o sync do KLaOS (`wabaNumber.service.ts:288-295`) lê `inbox.message_templates` do Frontdesk como fonte da verdade. Se o blacklist do canal MS não estivesse aplicado, o sync teria upsertado os `bluecare_*` embaixo do `waba_number` do MS. Não aconteceu.

**O guard é FAIL-OPEN** (`klaos_template_filter_guard.rb:59-62`): erro no filtro nunca bloqueia o save. O isolamento do MS depende hoje de **uma chave jsonb**.

## Opção 1 — MESMA WABA `735467396201142` (a da Klaus / Mais Saúde)

| | |
|---|---|
| Templates a submeter | **ZERO.** Os 12 das réguas já estão APPROVED, com `meta_template_id` conferidos |
| Token | O mesmo System User de 449 chars — já provado |
| Prazo | **Executável na segunda, sem espera de aprovação** |
| Caminho ponta a ponta | **100% provado** (é o que DEV usa hoje) |

**O que implica para a Mais Saúde:**

1. **Blast radius compartilhado.** Qualquer violação de política cometida pelo número da Blue Care dentro dessa WABA é passível de **restrição em nível de WABA** no Meta — e isso derruba também o `+553184226006`. Como a BC entra com 641 devedores e régua ligada, o dia 1 tem risco real de rajada e de reclamação. **Mitigado por:** A14/A15 (elimina a rajada), B12.2 (escalonamento 20/h) e A16 (impede a campanha demo).
2. **Quality rating no nível da WABA.** Rajada de template a partir do número da BC derruba o rating **da WABA inteira** — Meta corta messaging limit e pode pausar templates, atingindo a régua viva do MS sem que ninguém tenha tocado no workspace dela.
3. **Isolamento de template depende de 1 chave jsonb.** `prefix_blacklist:["bluecare_"]` no canal 1 e `prefix_whitelist:["bluecare_"]` no canal novo. O guard é fail-open. Se algum passo do go-live sobrescrever o `provider_config` do canal 1, o filtro some silenciosamente e o job de 3/3h repovoa o canal do MS. **Mitigado por:** B0 e a Camada 8 do B11 como gate obrigatório ao fim de cada bloco.
4. **Webhook.** É onde a colisão realmente mora — ver abaixo.
5. **Token compartilhado.** Rotação/expiração/revogação do System User derruba **os dois clientes ao mesmo tempo**. Não há isolamento de credencial hoje (o token da BC seria uma segunda cópia cifrada do mesmo segredo).
6. **Ruído de DEV.** O número de DEV `+553197286773` vive na **mesma WABA de produção**. Qualquer "limpeza de WABA" (deletar templates órfãos, remover números) pode acertar o número errado. **Não executar nenhum DELETE em `/{735467396201142}/...` durante o go-live.**

## Opção 2 — WABA PRÓPRIA da Blue Care

| | |
|---|---|
| Templates a submeter | **12** (ou 17), um a um, via `POST /{WABA_ID}/message_templates` |
| Prazo de aprovação | horas a dias — **fora do nosso controle** |
| Token | **Novo.** O System User de 449 chars do MS não tem acesso a WABA de terceiro |
| Escopo reaberto | G39, G44 e G47 com escopo maior |

**Pré-condições que têm que existir HOJE, senão não dá para adiantar:** (a) a WABA nova já criada no BM; (b) o System User com papel de admin nela e permissão `whatsapp_business_management`. **Se qualquer uma faltar, isso vira o verdadeiro bloqueio de segunda — escalar hoje.**

**Correção importante:** "submeter os 12 templates AGORA" é verdade no nível Meta (`POST /{waba_id}/message_templates` **não** exige número conectado), mas **não dá para fazer pelo KLaOS**: a rota de criação é `POST /api/waba/numbers/:id/templates` (`waba.routes.ts:43`) e resolve o `waba_id` a partir de uma linha de `waba_numbers`; e `register()` (linhas 63-73) chama `verifyPhoneNumber` na Meta antes de inserir — **exige o `phone_number_id` real**. A submissão antecipada tem que ser **curl direto no Graph**.

**Não existe hoje nenhum vestígio de BM/WABA da Blue Care no banco.** Varri `information_schema`: as únicas colunas de WABA em PROD são `waba_numbers.waba_id` e `whatsapp_phone_numbers.waba_id` (essa com 0 linhas); `meta_ads_credentials.business_id` é de Ads.

**Se for este ramo, extrair os payloads exatos de DEV:**
```sql
SELECT name,
       jsonb_build_object('name', name, 'category', category,
                          'language', language, 'components', components) AS payload
  FROM waba_templates
 WHERE workspace_id = 'b2f92f46-65cd-4f3d-b5ae-5dbf73cab0b0'
   AND name IN ('bluecare_cobr_d5_lembrete_v2','bluecare_cobr_d0_vencimento_v2',
                'bluecare_cobr_d1_vencido_v3_bc','bluecare_cobr_d7_atraso_v2',
                'bluecare_cobr_d15_atraso_v2','bluecare_cobr_d21_transbordo_v2',
                'bluecare_cobr_card_d5_lembrete_v2','bluecare_cobr_card_d0_vencimento_v2',
                'bluecare_cobr_card_d1_recusado_v2_bc','bluecare_cobr_card_d7_atraso_v2_bc',
                'bluecare_cobr_card_d15_atraso_v2_bc','bluecare_cobr_card_d21_transbordo_v2')
 ORDER BY name;   -- esperado: 12 linhas
```

**GATE UTF-8 obrigatório ANTES do POST** (regra fixa: nunca mandar mojibake para a Meta):
```sql
SELECT count(*) AS mojibake_hits
  FROM waba_templates t, jsonb_array_elements(t.components) c
 WHERE t.workspace_id = 'b2f92f46-65cd-4f3d-b5ae-5dbf73cab0b0'
   AND t.name LIKE 'bluecare_%'
   AND (c->>'text') ~ '(Ã.|Â.|�|\?\?)';   -- esperado: 0 (rodado hoje: 0)
```

```bash
# 12x, um payload por chamada, com --data-binary de arquivo UTF-8
curl -s -X POST "https://graph.facebook.com/v21.0/<WABA_ID>/message_templates" \
  -H "Authorization: Bearer <SYSTEM_USER_TOKEN>" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-binary @payload_<NOME_DO_TEMPLATE>.json
```

Conferência: `GET /{WABA_ID}/message_templates?limit=250&fields=name,status | grep -c bluecare_` → **12**, todos APPROVED (ou PENDING logo após o POST; reconferir em até 24h). Qualquer REJECTED = tratar antes de segunda.

**Reversão:** `curl -X DELETE ".../{WABA_ID}/message_templates?name=<NOME>"`. Ressalvas: deletar template no Meta é permanente e o nome fica em **quarentena ~30 dias**; template já aprovado não volta atrás de aprovação. Se der para só não usar, prefira não deletar.

## A colisão de webhook — o que realmente decide

Este é o ponto que a decisão da WABA governa.

O webhook **per-number** (`POST /{phone_number_id}` com `webhook_configuration`) tem **precedência** sobre o WABA-level. É o mecanismo que permite DEV, PROD e clientes distintos coexistirem na mesma WABA.

**Na Opção 1**, a segurança do MS depende de:
1. O MS ter per-number próprio (é o gate do **B0**). Se ele estiver rodando no fallback de WABA, **qualquer** escrita WABA-level derruba a entrega dele.
2. A BC ser criada **só** pelo caminho do pool (`source='whatsapp_pool'`), que tem o auto-setup de webhook **desligado**. Criar pela UI padrão do Chatwoot dispara `subscribe_waba_webhook` e sobrescreve o callback compartilhado.
3. Ninguém rodar o §4.5 do SDD do MS (`POST /{waba_id}/subscribed_apps`).
4. Ninguém apagar um canal criado como `embedded_signup` — `webhook_teardown_service.rb:16-18` faria `DELETE /{waba_id}/subscribed_apps` e **desinscreveria o app da WABA inteira**; o per-number não salva, porque sem app inscrito na WABA não chega nada.

**Na Opção 2**, esses 4 riscos desaparecem: a BC opera numa WABA onde o MS não existe.

## RECOMENDAÇÃO

**Perguntar ao dono do número, em uma frase:** *"o número novo da Blue Care vai ser adicionado na WABA da Klaus (735467396201142, a mesma do Mais Saúde) ou numa WABA própria da Blue Care?"*

**Recomendação técnica, condicionada:**

- **Se a WABA própria já existir no BM com System User admin e permissão `whatsapp_business_management`** → **Opção 2**. Submeter os 12 templates **HOJE** (a aprovação corre em paralelo à portabilidade) e ir de WABA própria. Isola completamente o blast radius do Mais Saúde e elimina os 4 riscos de webhook. **Custo:** token novo e ~1 dia de espera de aprovação, que cabe se a submissão for hoje.

- **Se a WABA própria NÃO existir hoje** → **Opção 1** (mesma WABA), porque é o único caminho 100% provado ponta a ponta e o único compatível com o prazo. **Não negociáveis nesse cenário:**
  1. `webhook_configuration` **per-number** nos **DOIS** números (B0 confirma o do MS; B10 cria o da BC). Nunca WABA-level.
  2. `prefix_whitelist:["bluecare_"]` no canal da BC no mesmo passo em que ele é criado (B2, passo 5) e `prefix_blacklist:["bluecare_"]` confirmado no canal 1 (B0).
  3. A14/A15 fechados **antes** de despausar (elimina a rajada de 87 mensagens em 6 min, 58,5% delas com texto errado).
  4. B12.2 (escalonamento 20/h) no dia 1.
  5. Nenhum DELETE em `/{735467396201142}/...` durante o go-live.
  6. Inbox criado **só** pelo pool.
  7. **Plano de migração para WABA própria registrado como item pós-go-live** — enquanto a WABA for compartilhada, o acoplamento existe.

**Registrar a decisão no doc de go-live, nesta forma:**
> WABA de destino da Blue Care = `<WABA_ID>`; BM = `<BUSINESS_ID>`; token = `<MESMO do MS | NOVO>`; templates = `<já aprovados 12/12 | submetidos em DD/MM HH:MM, aguardando aprovação>`.

---

# PARTE 4 — O QUE CONTINUA SEM COBERTURA

## 4.1 — G50: fechado nesta rodada, com ressalvas

O Postgres do Chatwoot PROD **foi consultado** (read-only, `SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY`). Os 9 gaps que estavam "presumidos" a partir de espelhos vazios do KLaOS foram confirmados na fonte: G40, G41, G07/G08/G27/G31/G32. Um gap falso foi eliminado (`custom_attribute_definitions` já existe completo).

**O que o inventário NÃO cobriu:**

| Item | Por quê | Como resolver |
|---|---|---|
| Conteúdo das 10 `auto_label_rules` de BC DEV | Não consultado nesta sessão | A lista final de labels de A5 tem que ser conferida contra elas antes de criar. Rodar em DEV: `SELECT jsonb_pretty(settings->'auto_label_rules') FROM workspaces WHERE id='b2f92f46-...'` |
| Se o token de 97 chars da conta 12 responde | Regra: só presença e tamanho | `GET /api/v1/accounts/12/inboxes` com esse token. 200 = ok; 401 = A2 é bloqueante |
| Se o token do Klaus na conta 12 funciona após A2 | Só existe depois de A2 | Mesmo GET, com o token do Klaus |
| Lista de inboxes existentes na conta 12 (para o fallback alfabético de B7) | O baseline diz `inboxes=0` **hoje**; se alguém criar outro inbox antes do go-live, o fallback muda | Rodar A1 de novo imediatamente antes de B2 |
| Ids reais dos times da conta 12 | Só existem após A4 | `SELECT id, name FROM teams WHERE account_id=12` |
| Nome exato do inbox (com/sem cedilha) | Depende de como o `PhoneLinkerService` gravar | Ler de `inboxes.name` após B2 e usar literalmente em B7/B8 |

## 4.2 — Não verificável por SQL: só olhando UI/API da conta 12

- **Se o time "cobrança" já existe no Chatwoot da conta 12 e só não espelhou.** `frontdesk_teams` do workspace BC PROD tem 0 linhas, mas isso pode significar "não existe" ou "existe e o webhook não espelhou" (`chatwoot_account_webhook_id` é NULL). Resolver por `GET /api/v1/accounts/12/teams` com o token do Klaus.
- **Se o dropdown de inbox no CampaignWizard lista o inbox da BC com badge WABA.** Só visível na UI, e só depois de B3. É a prova de que a assignment casou por `chatwoot_inbox_id`.
- **Se o seletor de template no inbox da BC mostra só `bluecare_*`** e o do MS mostra só os dele. Camada E do B4 — obrigatoriamente visual.
- **Se a resposta da ANA sai assinada como bot ou como humano.** Camada 5 do B11. Não há query que prove isso; é o rendering da mensagem no Chatwoot.

## 4.3 — Não verificado por falta de acesso

| Item | Bloqueio | Impacto se estiver errado |
|---|---|---|
| `APP_BASE_URL` no serviço KLaOS de produção (Railway) | Token Railway expirou 2026-07-23 | Se vazio, `paymentPage.service.ts:223-225` cai em `RAILWAY_PUBLIC_DOMAIN` e depois `http://localhost:5173`. **Todo link `/pay/<code>` enviado ao cliente nasce quebrado** |
| Estado vivo do `webhook_configuration` no Meta (per-number MS, per-number DEV, subscribed_apps da WABA) | Não consultei a Graph API para não materializar o token de produção no contexto; e não há coluna de webhook em `waba_numbers` | **É o gate B0.** Se o MS estiver no fallback de WABA, entrar com número novo na mesma WABA é perigoso |
| Teto real de req/min do host `bluecaremaissaude.tenex.com.br` | Não há teste empírico próprio da BC | Os 30/min de A11 são herdados de `maisaudebh.tenex.com.br` — host diferente. São ~400× abaixo do que comprovadamente falhou (12.400 req/min), mas é valor herdado, não calibrado |
| Se um boleto Tenex tipo 2 vencido continua pagável (multa/juros) ou se a linha digitável é recusada | Não consultei a Tenex live | Era a premissa em que a ação original do G34 se apoiava. **A15 foi escrito para não depender disso** — ele descongela o snapshot e deixa o pré-dispatch reler a Tenex |
| Se o cliente já viu/aprovou a lista dos 94 devedores | Decisão de negócio, não de banco | — |
| Se a Clínica Baronesa é canal oficial da Blue Care | Pergunta ao cliente (A18, passo 2) | Se não for, a ANA manda cliente de cobrança para um número de terceiro |

## 4.4 — Dois achados colaterais na MAIS SAÚDE PROD

Encontrados nesta varredura. **NÃO fazem parte do go-live da Blue Care. NÃO corrigir junto.** Tratar como itens próprios, depois.

### (A) BOMBA ARMADA NO PROMPT DA LARA
Em MS PROD há divergência entre a versão marcada `is_active` e o prompt que roda de fato:

| | chars | md5 | host de dev |
|---|---|---|---|
| `agent_prompt_versions` v55 (`is_active=true`) | 88.276 | `b5ae277b7c39e736594e1a3e1a5bb910` | **CONTÉM** |
| `agent_instances.system_prompt` (a coluna) | 33.141 | `902da154a3191dcd2ad3a4b3bb19e5bb` | limpo |

**43 das linhas de `agent_prompt_versions` da MS têm host de dev, e a marcada como ativa é uma delas.** Como `resolveActivePrompt` usa a versão ativa, **a Lara roda 88.276 chars em produção hoje** — o prompt de 33k é código morto.

O footgun (#505, documentado em `C:\dev\gmb\klaos\AGENTS.md:152`): **quem editar a Lara pelo editor de prompt vai achar que mudou e não muda nada.** E quem clicar em "restaurar/reativar a versão ativa" pela UI substitui o prompt vivo por um texto com `app-dev.klaos.ai` dentro, em produção, cobrando gente de verdade. Foi exatamente por esse caminho que o host de dev entrou na ANA (o label da v4 cita "clone Lara v55 (md5 b5ae277b)").

### (B) TEMPLATE APROVADO NA META COM LINK DE DEV
`customer_satisfaction_survey_30` (MS PROD, **APPROVED**, UTILITY) tem botão url = `https://app-desk-dev.klaos.ai/survey/responses/{{1}}`. Verifiquei que **não é usado por nenhum step** (`collection_sequence_steps`: 0 usos), então está dormente. Mas se alguém disparar esse template, cliente real recebe link para o ambiente de dev. **Corrigir exige template novo na Meta** — o botão vive no template aprovado, não no banco; não dá para consertar por SQL.

## 4.5 — Defeitos herdados que NÃO devem ser corrigidos só na Blue Care

Consertar só num lado cria divergência entre os prompts sem ganho medido:

- **Seção "5. Régua diária (Dia 1/3/7/14/21)"** não bate com as campanhas (steps reais −5/0/+1/+7/+15/+21). O MS PROD tem os **mesmos** day_offsets e a **mesma** seção na v55 ativa — opera com esse descompasso em produção.
- **`https://app-dev.klaos.ai/pay/xxx`** na linha 774 do prompt: herdado da Lara v55, dentro de um exemplo rotulado ERRADO. A18 tira na BC; **tirar nos dois ou em nenhum**.
- **CPF de exemplo `13825251764`** (linhas 750 e 764): herdado da Lara.

## 4.6 — Riscos estruturais que este runbook mitiga mas não elimina

| Risco | Natureza | Estado |
|---|---|---|
| Não existe UNIQUE em `provider_config->>'phone_number_id'` no `channel_whatsapp` | O único UNIQUE é em `phone_number` (E.164). O banco **impede** repetir o E.164 mas **não impede** repetir o `phone_number_id` do MS num canal novo. Canal da BC nascido de copy/paste do `provider_config` do MS **passa no insert** e a BC começa a mandar mensagem pelo número do Mais Saúde, sem erro nenhum | Mitigado pela verificação de B2 (exigir `phone_number_id` distintos) |
| `waba_numbers` permite o mesmo `phone_number_id` em 2 workspaces (UNIQUE é `(workspace_id, phone_number_id)`) e `wabaWebhook.service.ts:15-25` busca **sem** filtro de workspace com `.maybeSingle()` | Com 2 linhas, o erro é ignorado e **a mensagem é descartada em silêncio** | Mitigado pelo gate de B1 |
| `agent_bot_inboxes` não tem UNIQUE nem FK — só a PK | `inbox_id` errado cria duplicata; `find_by` devolve linha arbitrária | Mitigado pelo `NOT EXISTS` de B6 |
| `idx_agent_frontdesk_bridge_inbox_unique` é UNIQUE em `(frontdesk_inbox_id)` **sem workspace** | Um `ON CONFLICT` sequestra a linha do MS | Mitigado por: INSERT puro, sem `ON CONFLICT` |
| Não existe FK de `collection_sequence_steps.waba_template_id` → `waba_templates`, e o engine busca o template só por `.eq('id')` sem filtro de workspace/status | UUID de outro workspace ou órfão passa liso | Mitigado pelos gates `vazamento_cross_tenant=0` e `ponteiros_orfaos_global=0` |
| `tenexSync` percorre workspaces **em série** num único job horário | Sync longo da BC atrasa o do MS; sync parado = feed velho = `halt_on_stale` = régua inteira sem disparar | Mitigado pelo `reconcile_out` explícito de A11 (60/200). Atraso esperado: ~0 min em horário comercial, ≤13 min off-hours numa janela de 360 min |
| O guard de filtro de template é **fail-open** | Erro no filtro nunca bloqueia o save; o job upstream de 3/3h repovoa o canal | Mitigado por: `SELECT provider_config->'template_filter' FROM channel_whatsapp WHERE id=1;` como gate obrigatório ao fim de **cada** bloco |
| Não existe ferramenta de clone de workspace entre ambientes | O porte é 100% manual; o único controle é checklist + gate SQL | A16 (allowlist por id) e A17 (gate `=0`) |

## 4.7 — Bloqueios que podem virar o problema real de segunda

1. **A WABA de destino não estar decidida** (Parte 3). Se a resposta for "WABA nova" e ela ainda não existir no BM com System User admin, isso é o bloqueio, não o número. **Escalar hoje.**
2. **O token da conta 12 não funcionar** (97 vs 161 chars). Bloqueia A2, A19, B2, B6, B7. **Testável hoje** com um GET.
3. **`APP_BASE_URL` não estar setado em produção.** Não bloqueia o go-live tecnicamente, mas faz todo link de pagamento nascer quebrado. **Testável hoje**, precisa de token Railway novo.
4. **O cliente não responder as 13 perguntas do A18.** Não bloqueia (a guarda de precedência transforma marcador em transbordo), mas gera volume artificial de handoff no dia 1.
5. **A portabilidade não concluir na segunda.** Todo o Bloco B para. Bloco A inteiro pode e deve ser fechado antes, independentemente.