# SDD — Billing Engine End‑to‑End (KLaOS ↔ Frontdesk)

> Status: **v2 (rewrite após auditoria de DB)** — 2026-04-29
> Owners: Frontdesk agent (este repo) + KLaOS agent (`gmb/klaos`)
> Espelhado em `docs/para-klaos-agent/SDD_BILLING_E2E.md`
> Princípio raiz: **não quebrar o que já existe.** Tudo aditivo. Versão anterior propunha tabelas/registries que **já existem** — descartado.

## Como ler este SDD
- **[FRONTDESK]** — implementação no `gmb/frontdesk` (este repo)
- **[KLAOS]** — implementação no `gmb/klaos` (passar pro outro agente)
- **[CROSS]** — coordenado entre os dois (contrato de API + deploy ordenado)
- **[OPS]** — operação manual (DBA, infra, owner)

## 0. TL;DR — decisões pendentes

| # | Decisão | Quem aprova | Status |
|---|---|---|---|
| **D1** | Família a oficializar: legacy (`fatura_*`/`cobranca_*`) ou `ms24h_*`? Funcionalmente equivalentes na Meta | usuário | ⏳ pendente |
| **D2** | Como corrigir `ms24h_boleto_vencido` MARKETING → UTILITY? | usuário | ✅ "recriar" — método PATCH (sem risco de lock) ⏳ aguardando confirmação do método |
| **D3** | Cliente teste +5521964798660 — clonar quem? | usuário | ✅ "usar quando quiser testar em qualquer hipótese" — autonomia liberada |

D1 não trava nada essencial: se for D1=ms24h, a régua atual usa legacy mas pode migrar gradualmente. Se for D1=legacy, basta deletar família ms24h_* da Meta.

---

## 1. Arquitetura real (auditada nos bancos em 2026-04-29)

### 1.1 Camadas de dados

```
┌─────────────────────────────────────────────────────────────────┐
│ Meta WABA (graph.facebook.com)                                  │
│ Source of truth canônico de templates                           │
│   /v22.0/{waba_id}/message_templates                             │
│   webhooks: template_status_update, template_category_update,    │
│             message_template_quality_update                      │
└────────────────┬───────────────────────────────────┬─────────────┘
                 │                                   │
       ┌─────────▼──────────┐               ┌────────▼────────┐
       │ Frontdesk cache    │               │ KLaOS cache     │
       │ ─────────────────  │               │ ──────────────  │
       │ WhatsappConnection │               │ waba_templates  │
       │   .message_        │               │   (1 row/tpl    │
       │   templates jsonb  │               │   por WABA)     │
       │ Sync: a cada 3h    │               │ Sync: 1x/dia ?  │
       │   TemplatesSyncJob │               │   (DEV: 04:00   │
       │ Channel propagate  │               │    UTC)         │
       └────────────────────┘               └────────┬────────┘
                                                     │
                                                     │ FK (uuid)
                                                     ▼
                                        ┌─────────────────────┐
                                        │ collection_         │
                                        │ sequence_steps      │
                                        │   .waba_template_id │
                                        │ (régua aponta       │
                                        │  pra template uuid) │
                                        └─────────────────────┘
```

### 1.2 Que dados realmente existem (DEV vs PROD)

| Tabela / objeto | DEV | PROD | Notas |
|---|---|---|---|
| `waba_templates` | 16 rows ✅ | 0 rows ❌ | Sync nunca rodou em prod |
| `waba_numbers` | 1 row ✅ | ? | Provisionamento de Atend Med BH em prod pendente |
| `collection_campaigns` | 2 paused (workspace teste) | 0 ❌ | Nenhuma régua provisionada em prod |
| `collection_sequence_steps` | 13 rows | 0 | |
| `collection_enrollments` | 3 | 0 | |
| `collection_enrollment_events` | 27 | 0 | |
| `WhatsappConnection.message_templates` | populado, sync 3h | populado p/ outros clientes | Frontdesk |

### 1.3 Régua atual (DEV) — como está montada

Workspace teste `9838d25b-…`, inbox 30 (KLaOS Cobrança), **paused**:

| step | offset | trigger | template (FK) | label aplicada |
|---|---|---|---|---|
| 1 | -5 | due_date | fatura_lembrete_5dias | lembrete-5d |
| 2 | 0 | enrollment | fatura_emissao | pendente |
| 3 | 0 | due_date | cobranca_vencimento_hoje | cobranca-0d |
| 4 | +5 | due_date | cobranca_atraso_5dias | cobranca-5d |
| 5 | +10 | due_date | boleto_atraso_10dias | cobranca-10d |
| 6 | +15 | due_date | fatura_atraso_15dias | cobranca-15d |
| 7 | +21 | due_date | fatura_atraso_21dias | cobranca-21d (handoff) |

`collection_campaigns.permanent_labels = ['mais-saude']` filtra **quem entra** na régua. `chatwoot_label` é o que **a régua aplica em cada step**. Conceitos distintos.

---

## 2. Auto-sync — como já funciona, e onde reforçar

> **Princípio:** o usuário pediu "atualização precisa ser auto". Boa parte já é. Esta seção mapeia o que existe e o que falta pra chegar em **idempotente, sem ação humana, com alerta quando algo desvia**.

### 2.1 O que já é automático

| Componente | Onde | Cadência | Status |
|---|---|---|---|
| Frontdesk: WhatsappConnection.message_templates | `custom/app/jobs/whatsapp_connections/templates_sync_job.rb` | a cada 3h (debounce) | ✅ ativo |
| Frontdesk: propaga pra Channel.message_templates | `custom/app/services/whatsapp_connections/meta/template_sync_service.rb` | mesmo job | ✅ ativo |
| KLaOS: `waba_templates` upsert | (presumido — verificar com agente KLaOS) | DEV: 04:00 UTC daily | ✅ ativo em DEV, ❌ em PROD |
| Webhook Meta `template_status_update` | (presumido handler genérico no Channel::Whatsapp) | tempo real | ⚠️ não persiste em `waba_templates` — verificar |

### 2.2 Gaps de auto-sync — o que falta

**[KLAOS] G-Sync.1** — Habilitar sync `waba_templates` em PROD. Diagnóstico em `docs/para-klaos-agent/SCHEMA_DRIFT_BILLING.md`. **Bloqueador alto**.

**[KLAOS] G-Sync.2** — Webhook real-time da Meta atualizar `waba_templates`. Hoje sync é batch (1×/dia em DEV). Quando Meta reclassifica MARKETING (caso `ms24h_boleto_vencido`), sistema só sabe na próxima janela. Adicionar handler que upserts em `waba_templates` quando recebe webhook.

**[KLAOS] G-Sync.3** — Constraint/trigger DB que marca steps como broken. Pré-flight virtual: nenhum dispatch dispara se step aponta pra template `status != APPROVED` ou `category != UTILITY` (em régua de cobrança). Implementação:
```sql
ALTER TABLE collection_sequence_steps ADD COLUMN broken_reason text;

CREATE OR REPLACE FUNCTION fn_validate_step_template()
RETURNS trigger AS $$
DECLARE tpl waba_templates%ROWTYPE;
BEGIN
  IF NEW.waba_template_id IS NULL THEN RETURN NEW; END IF;
  SELECT * INTO tpl FROM waba_templates WHERE id = NEW.waba_template_id;
  IF tpl.status != 'APPROVED' THEN
    NEW.broken_reason := 'template not APPROVED: ' || tpl.status;
  ELSIF tpl.category != 'UTILITY' THEN
    NEW.broken_reason := 'template not UTILITY: ' || tpl.category;
  ELSE
    NEW.broken_reason := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```
Trigger AFTER UPDATE em `waba_templates` recalcula `broken_reason` em todos os steps que apontam pra ela. Dispatcher checa `broken_reason IS NULL` antes de mandar.

**[KLAOS] G-Sync.4** — Telemetria/Sentry alert. Hoje quando categoria muda (`UTILITY → MARKETING`), nada dispara alert. Adicionar:
```typescript
// no handler de webhook
if (oldCategory === 'UTILITY' && newCategory === 'MARKETING') {
  Sentry.captureMessage(`Template ${name} reclassified to MARKETING`, 'warning');
  notifyOwner(workspace_id);
}
```

**[FRONTDESK] G-Sync.5** — Frontend mostra status atual. UI badge já adicionada (`klaos-patches.js` patch `template-category-badge`). Falta:
- timestamp de last_synced (quando UI mostra template, mostrar "sincronizado há X")
- botão "Sincronizar agora" — já existe `syncTemplates` no `TemplateManager.vue`, ✅

### 2.3 O que **nunca** automatizar

- Submeter template novo (apenas seed manual via rake ou UI)
- Aceitar reclassificação UTILITY → MARKETING como fix automático
- Editar texto de template (re-aprovação Meta)
- ~~Recategorize via API automática~~ **— Meta API nem suporta isso** (verificado 2026-04-30, subcode 3835031). Único caminho de correção: DELETE + POST com novo nome.

Tudo isso exige humano — Sentry/email alert dispara, dono decide.

### 2.4 Implicação operacional — playbook quando UTILITY vira MARKETING

Cenário: template aprovado como UTILITY tem comportamento detectado como MARKETING pela Meta (ex: usuários reportam, ou uma reclassificação automática). Sentry alert dispara via G-Sync.4.

**Playbook manual** (não automatizar nenhum passo, decisão humana em cada um):
1. **Pausar enrollments** que usam o template afetado: `UPDATE collection_sequence_steps SET broken_reason='manual_paused' WHERE waba_template_id=...`
2. **Avaliar** se texto precisa mudar (provavelmente sim — Meta classificou errado por algum motivo)
3. **Criar template novo** com nome `<nome>_v2` (ou `_v3` etc) com texto ajustado, categoria UTILITY explícita
4. **Aguardar APPROVED** (5-30min)
5. **Migrar** régua: `UPDATE collection_sequence_steps SET waba_template_id=<novo_uuid>, broken_reason=NULL WHERE ...`
6. **Deletar template velho** na Meta (nome fica lockeado 30d, OK pq estamos no `_v2`)

Tempo total estimado de incidente: **30-45min** (dominado por aprovação Meta).

---

## 3. Templates — estado atual + onde ajustar

### 3.1 Inventário Meta (auditado em 2026-04-29 via Graph API)

**WABA Klaus (`735467396201142`)** — usado pela régua atual. 16 templates APPROVED:

Família **legacy** (em uso):
- `fatura_lembrete_5dias` UTILITY ✅
- `fatura_emissao` UTILITY ✅
- `cobranca_vencimento_hoje` UTILITY ✅
- `cobranca_atraso_5dias` UTILITY ✅
- `boleto_atraso_10dias` UTILITY ✅
- `fatura_atraso_15dias` UTILITY ✅
- `fatura_atraso_21dias` UTILITY ✅ (transbordo, sem botão)
- `aviso_pagamento_ok` UTILITY ✅ (confirmação)

Família **`ms24h_*`** (não usada em régua hoje):
- `ms24h_fatura_geracao` UTILITY ✅
- `ms24h_vencimento_hoje` UTILITY ✅
- `ms24h_atraso_7dias` UTILITY ✅
- `ms24h_atraso_15dias` UTILITY ✅
- `ms24h_transbordo_21dias` UTILITY ✅
- `ms24h_pagamento_ok` UTILITY ✅
- **`ms24h_boleto_vencido` MARKETING ⚠️** — único problema

**WABA Mais Saude / Atend Med BH** — templates de agendamento, não cobrança. Não interferem.

### 3.2 Bug `ms24h_boleto_vencido` MARKETING

**Limitação confirmada via teste API (2026-04-30)**: Meta API **NÃO permite** alterar `category` de um template já `APPROVED`. Endpoint `POST /{template_id}` com `category: UTILITY` retorna erro `subcode 3835031` — "Não é possível atualizar uma categoria de modelo aprovada".

**Implicação geral**: qualquer template que a Meta classificar errado (UTILITY virando MARKETING) **só pode ser corrigido via DELETE + POST com nome diferente**. Não há recategorize via API. Isso impacta toda a estratégia de auto-sync — ver §2.3.

**[OPS] D2-fix recomendado**: como `ms24h_*` é família órfã (nenhuma `collection_sequence_steps` referencia esse template), basta:
```
DELETE https://graph.facebook.com/v22.0/735467396201142/message_templates?name=ms24h_boleto_vencido
Authorization: Bearer <SYSTEM_USER_TOKEN>
```
Lock de 30d no nome `ms24h_boleto_vencido` é irrelevante (nunca foi usado em régua, e estágio "boleto vencido" já é coberto por `boleto_atraso_10dias` UTILITY APPROVED).

**Aguardando confirmação A/B/C do usuário.**

### 3.3 `billing_templates.rake` — atualizado

`custom/lib/tasks/billing_templates.rake` reescrito (commit pendente nesta branch) pra refletir Meta atual:
- Variável 4 mudada de `link_pagamento` → `codigo_barras`
- 2 botões em todos (PIX + Boleto PDF), exceto `fatura_atraso_21dias`
- Removido `fatura_vencida_10dias` (não existe na Meta — equivalente é `boleto_atraso_10dias`)
- Adicionado `boleto_atraso_10dias`

**Idempotente.** Se Meta já tem o template idêntico → no-op. Se diferente → PATCH e reaprovação. Se inexistente → POST.

Comando: `rake billing_templates:sync CONNECTION_ID=<id>`. Não roda em cron — é manual seed.

### 3.4 Família `ms24h_*` órfã

Decisão D1 pendente. Sugestão dos dois caminhos:

**Caminho A — manter legacy, deletar ms24h_***
- 1 chamada DELETE por template (7 templates, lock de 30d nos nomes — não importa, não vamos reusar)
- Régua não muda

**Caminho B — migrar pra ms24h_***
- Atualizar `collection_sequence_steps.waba_template_id` apontando pros uuids da família ms24h
- Resolver D2 (`ms24h_boleto_vencido`) **antes** de migrar
- Deletar família legacy depois

Não há diferença funcional pro cliente final — texto é equivalente. Se você não tem preferência, **caminho A** é menos trabalho.

---

## 4. Régua atual — gaps no engine

### 4.1 O que JÁ funciona

- ✅ Multi-tenant (`workspace_id` em tudo)
- ✅ Filtragem por label (`permanent_labels` text[])
- ✅ Janela de horário (`dispatch_start_hour/end_hour/weekdays`)
- ✅ Filtros financeiros (`filter_min_days_overdue`, `filter_min_debt`, `filter_has_active_plan`)
- ✅ Stop on payment / on reply (configurável)
- ✅ Test mode com `demo_interval_seconds` (60s na campaign de teste DEV — não precisa env nova)
- ✅ Handoff team (`handoff_team_id`, `boletos_team_id`)
- ✅ Reply mode (`ai_agent` ou `human_only`)
- ✅ Anchor automático de bot (Frontdesk: `auto_anchor_agent_bot.rb`)
- ✅ Botão "Devolver ao bot" (Frontdesk: `transfer_to_bot_controller.rb`)
- ✅ Bridge bidirecional com `X-Bridge-Secret`

### 4.2 O que NÃO funciona / falta

**[KLAOS] G-Engine.1** — Recurrence (campanha mensal/semanal). Hoje campaign rola continuous (auto_enroll por filtro) ou one-shot. Falta cron-style. Exemplo: "todo dia 5 do mês reenrolla quem ainda está em atraso 30d+".
- Schema: adicionar `recurrence_kind` enum + `recurrence_rules` jsonb em `collection_campaigns`
- Job: `RecurringCampaignSchedulerJob` (cron 5min)

**[KLAOS] G-Engine.2** — Disparo avulso (sem campaign). Cenário: cliente liga, agente quer disparar template "lembrete" sem criar campaign nova. Hoje precisa SQL.
- Endpoint `POST /api/v1/internal/billing/dispatch-once {contact_id, template_id, vars}` — cria enrollment ad-hoc, executa, descarta.

**[KLAOS] G-Engine.3** — Cliente "cartão recusado". Hoje régua não distingue. Soluções:
- A: template novo `cobranca_cartao_recusado` UTILITY
- B: label `cobranca-cartao-recusado` (já existe na conta 10) + campaign customizada
- **Recomendado B** — máximo reuso, zero código novo

**[FRONTDESK] G-Engine.4** — UI pra editar régua. Hoje só via console. Opções:
- A: criar UI no Frontdesk Settings → "Cobrança" (consome bridge)
- B: criar UI no `app.klaos.ai` (admin do KLaOS)
- **Recomendado B** — UI vive onde mora o dado. Frontdesk é cliente, não dono.

---

## 5. Multi-número — estado e gaps

### 5.1 Já funciona

- Schema multi-número nativo: `WhatsappConnection 1:N WhatsappPhoneNumber 1:1 Channel::Whatsapp 1:1 Inbox`
- Cada PhoneNumber → inbox separada. Switch no time normal.
- Atend Med BH hoje: 1 connection, 1 phone, 1 inbox 30.

### 5.2 Gap UI — adicionar 2º número

**[FRONTDESK] G-Multi.1** — `WhatsappConnectionsForm.vue` só dá Embedded Signup pra registrar **um** número. Adicionar 2º precisa POST manual.

Fix:
1. UI: lista de phone_numbers vinculados (parcial, verificar)
2. Botão "Adicionar número" → modal Embedded Signup pra WABA já existente, listando phones disponíveis

Estimativa: 1d.

### 5.3 Gap operacional — trocar número

Procedimento (não automatizar — alto risco de migrar conversations):
1. Cadastra phone novo → cria inbox nova
2. Time se acostuma com inbox nova
3. Liberta phone antigo na Meta
4. Inbox antiga vira read-only via `Inbox.archived = true` (custom flag)

Documentar em runbook ops, **não** SDD.

---

## 6. Labels / etiquetas — CRUD

### 6.1 Backend (upstream Chatwoot)

- `LabelsController` REST completo
- `LabelPolicy` exige `administrator` em create/update/destroy
- `Label::DeletionService` cascade em conversation/contact tags
- Rota `/labels` tem `permissions: ['administrator']` no route guard — agente comum nem chega na página

### 6.2 Patch aplicado neste SDD

**[FRONTDESK]** `custom/vite/klaos-patches.js`:
- `labels.js` store — `isUpdating: false` no state inicial (higiene de reactivity)
- `Index.vue` — import `useAdmin` + `v-if="isAdmin"` no div dos botões edit/delete (defesa em profundidade vs custom roles que tenham `manage_label` mas não sejam admin)

### 6.3 Como labels alimentam a régua

`collection_campaigns.permanent_labels` é text[] e casa com array `tags` de `conversations` no Chatwoot. Match é por **conversation tag**, não contact tag. Se label só está no contact, **não entra na régua**.

**[FRONTDESK] G-Labels.1** — Badge na UI de Labels Settings: cada label que aparece em `permanent_labels` de campaign ativa ganha `🔒 usada em régua de cobrança`. Evita time deletar e quebrar régua.

Sub-tarefa **[KLAOS]**: endpoint `GET /api/v1/internal/labels-in-use?account_id=X` retornando lista distinta.

---

## 7. Bridge — robustez

### 7.1 Já funciona

- `X-Bridge-Secret` em ambos os lados
- KLaOS endpoints: `manual_transfer_to_bot`, `agent_message_sent`, `conversation_resolved`
- Frontdesk webhooks normais consumidos pelo KLaOS
- Logs duplos: `BridgeMessageLog` (Frontdesk) + `bridge_message_log` (KLaOS) + `agent_conversations.platform_metadata.desk_conversation_id`

### 7.2 Gaps

**[CROSS] G-Bridge.1** — Idempotência ainda não 100%. Frontdesk pode duplicar conversation se KLaOS reenvia enroll antes do anchor commit. Fix: dedup por `additional_attributes.klaos_enrollment_id` antes de criar.

**[KLAOS] G-Bridge.2** — Retry sem backoff. Atend Med BH gerou ~12 dispatches duplicados em 1 mês. Fix: exponential `[1s, 5s, 30s]` + circuit breaker se >50% falhas em 5min.

**[FRONTDESK] G-Bridge.3** — Endpoint `POST /api/v1/internal/billing/relink-enrollment` (recovery). Cenário: KLaOS perdeu link mas Chatwoot tem a conv. Hoje precisa SQL.

---

## 8. Testes E2E — plano com `+5521964798660`

### 8.1 Estado autorizado pelo usuário

Decisão D3: **autonomia liberada** — posso clonar cliente real e substituir dados pelo +5521964798660 quando quiser testar qualquer cenário.

### 8.2 Cenários de teste

| Cenário | Como simular | Template esperado |
|---|---|---|
| Inadimplente novo (5d antes) | `due_date = now + 5d` | `fatura_lembrete_5dias` |
| Cobrança emitida | `due_date = now + 30d, issued = now` | `fatura_emissao` |
| Vencendo hoje | `due_date = now` | `cobranca_vencimento_hoje` |
| Atraso 5d | `due_date = now - 5d` | `cobranca_atraso_5dias` |
| Atraso 10d | `due_date = now - 10d` | `boleto_atraso_10dias` |
| Atraso 15d | `due_date = now - 15d` | `fatura_atraso_15dias` |
| Atraso 21d | `due_date = now - 21d, status = 'protesto'` | `fatura_atraso_21dias` |
| **Cartão recusado** | `payment_method = card, status = 'declined'` | (G-Engine.3) — usa label hoje |

### 8.3 Modo turbo (intervalos comprimidos)

`collection_campaigns.demo_interval_seconds = 60` (já configurado nas campaigns DEV). Reduz cada step pra 1min. **Não precisa env nova** — só ativar/setar valor.

Quando rodar teste:
```sql
UPDATE collection_campaigns
SET demo_interval_seconds = 60, status = 'active'
WHERE id = '<campaign_id>';

INSERT INTO collection_enrollments (workspace_id, campaign_id, debtor_id, ...)
VALUES (..., '<fixture_debtor_id>', ...);
```

### 8.4 Roteiro Playwright (quando MCP voltar)

1. **TESTE 1** — Régua completa em modo turbo
   1. Seed cliente +5521964798660 com débito
   2. Enroll na campaign turbo
   3. Esperar 7 templates chegarem (intervalos de 60s)
   4. Validar variáveis (nome, valor, data, código de barras)
   5. Tag `cobranca-Xd` aparece nas conv

2. **TESTE 2** — Opt-out
   1. Após T2, cliente responde "PARAR"
   2. KLaOS unenroll → próximos não disparam
   3. Validar `enrollment.status = 'opted_out'`

3. **TESTE 3** — Pagamento
   1. Após T3, simular webhook de pagamento (Asaas/Stripe → KLaOS)
   2. KLaOS unenroll → T4-T7 não disparam
   3. Validar `enrollment.status = 'paid'`

4. **TESTE 4** — Labels admin vs agent
   1. Login admin → vê edit/delete (botões aparecem)
   2. Login agent → tenta acessar `/settings/labels` → redirecionado (route guard) ou botões escondidos (patch defensivo)

### 8.5 Bloqueador

Playwright MCP morto. **Antes de TESTE 1-4, reset MCP manualmente** (`/mcp` no chat).

---

## 9. Sprint roadmap

> Cada item é PR isolado, não-destrutivo, mergeável independente.

### Sprint 0 (esta sessão) — Cleanup já feito ou em andamento
- ✅ Schema drift documentado (`SCHEMA_DRIFT_BILLING.md`)
- ✅ Cleanup waba_templates duplicata documentado (`CLEANUP_WABA_TEMPLATES.md`)
- ✅ UI badge MARKETING patch (`klaos-patches.js`)
- ✅ Patch labels admin-only defensivo (`klaos-patches.js`)
- ✅ Rake billing_templates atualizado (cod_barras + Boleto PDF)
- ⏳ D2 fix `ms24h_boleto_vencido` — aguarda confirmação método (PATCH default)

### Sprint 1 — Auto-sync robusto
**[KLAOS]**
- K1.1: G-Sync.1 — habilitar sync `waba_templates` em PROD
- K1.2: G-Sync.2 — webhook real-time atualiza `waba_templates`
- K1.3: G-Sync.3 — trigger DB de validação (broken_reason)
- K1.4: G-Sync.4 — Sentry alert em mudança de categoria
- K1.5: aplicar cleanup duplicata (CLEANUP_WABA_TEMPLATES.md)
- K1.6: aplicar schema drift fix (SCHEMA_DRIFT_BILLING.md)

**[FRONTDESK]**
- F1.1: G-Sync.5 — UI mostra `last_synced_at` em Templates Settings

### Sprint 2 — Visibilidade + governance
**[FRONTDESK]**
- F2.1: G-Labels.1 — badge "🔒 em régua" em labels
**[KLAOS]**
- K2.1: endpoint `GET /api/v1/internal/labels-in-use`

### Sprint 3 — Multi-número UI
**[FRONTDESK]**
- F3.1: G-Multi.1 — botão "Adicionar número" + lista de phones

### Sprint 4 — Engine: recurrence + dispatch avulso
**[KLAOS]**
- K4.1: G-Engine.1 — recurrence_kind + RecurringCampaignSchedulerJob
- K4.2: G-Engine.2 — endpoint dispatch-once
- K4.3: UI no `app.klaos.ai` pra editar régua

### Sprint 5 — Bridge robustness
**[CROSS]**
- C5.1: G-Bridge.1 — idempotência bilateral
- C5.2: G-Bridge.2 — retry com backoff
- C5.3: G-Bridge.3 — endpoint relink-enrollment

### Sprint 6 — Cartão recusado
**[KLAOS]**
- K6.1: G-Engine.3 — auto-aplica label `cobranca-cartao-recusado` quando detecta declined
- K6.2: campaign nova com permanent_labels=[cobranca-cartao-recusado]

---

## 10. Anexo — referências de código

| Coisa | Path |
|---|---|
| Auto-anchor bot | `custom/config/initializers/auto_anchor_agent_bot.rb` |
| Botão "Devolver ao bot" | `custom/app/controllers/.../transfer_to_bot_controller.rb` |
| Templates rake (seed) | `custom/lib/tasks/billing_templates.rake` |
| Templates CRUD endpoint | `custom/app/controllers/.../whatsapp_connections/templates_controller.rb` |
| Templates sync job | `custom/app/jobs/whatsapp_connections/templates_sync_job.rb` |
| Templates sync service | `custom/app/services/whatsapp_connections/meta/template_sync_service.rb` |
| Vite patches (UI) | `custom/vite/klaos-patches.js` |
| Bridge log | `custom/app/models/bridge_message_log.rb` |
| Schema drift PROD | `docs/para-klaos-agent/SCHEMA_DRIFT_BILLING.md` |
| Cleanup waba_templates | `docs/para-klaos-agent/CLEANUP_WABA_TEMPLATES.md` |
| (KLaOS) collection_* tables | KLaOS DEV `szkzkyexagunvadzzaec` / PROD `ddnwemmvsuiibgbzjpwx` |
| (KLaOS) bridge service | `gmb/klaos:src/services/klaosBridgeService.ts` |

---

_FIM SDD v2_
