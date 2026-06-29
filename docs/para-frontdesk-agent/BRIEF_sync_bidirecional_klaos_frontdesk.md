# BRIEF CONSOLIDADO — KLaOS ↔ Frontdesk (Sync bidirecional + Modularidade + Zero-Bypass)

> Data: 2026-06-28
> Origem: agente KLaOS (Matheus + Claude)
> Para: agente Frontdesk (fork Chatwoot Rails) — `C:\dev\gmb\frontdesk` (branch `klaos-dev`)
> Substitui briefs avulsos da semana 27-28/06
> Repos relacionados: KLaOS = `C:\dev\gmb\klaos` (branch dev)

---

## 0. TL;DR

Em 2 dias o KLaOS rodou **2 audits massivos** + escreveu **2 SDDs novos**. Tudo converge em 3 regras arquiteturais não-negociáveis e algumas demandas pro lado Frontdesk. Este brief consolida TUDO. Sua resposta vira o cronograma de execução do lado Frontdesk.

**3 regras arquiteturais que valem pros 2 repos:**

1. **Zero bypass do backend** — front KLaOS **NUNCA** acessa Supabase ou Chatwoot direto. Tudo via `/api/...` do Express KLaOS. Frontdesk segue padrão equivalente: sua UI Chatwoot mexe no DB Chatwoot via Rails, nunca expõe credencial pro browser.
2. **Modular = backend + frontend MESMA entrega** — proibido "backend pronto, UI no sprint X depois". Cada migration vem com tela/editor no mesmo PR.
3. **Tools são hierárquicas** — tool ligada a connector externo só fica disponível se workspace tem credencial ativa do connector. Já implementada no KLaOS (#446). Frontdesk não é afetado diretamente, mas precisa estar ciente.

**SDDs/Docs pendentes mapeados:**

| # | Doc | Onde | Status | Pede do Frontdesk? |
|---|---|---|---|---|
| A | `sdd_klaos_frontdesk_bidirectional_sync.md` | `klaos/docs/` | DRAFT (28/06) | **SIM** — webhooks novos (§2 deste brief) |
| B | `sdd_ui_modularidade_agentes.md` (#444) | `klaos/server/docs/` | aberto | indireto — só ciência |
| C | `SDD_INBOX_WEBHOOK_DATA_CHANNEL_TYPE.md` | `frontdesk/docs/para-frontdesk-agent/` | implementado, monitorando | confirma status (§7) |
| D | Audit Zero-Bypass Front KLaOS | tasks #447-#451 | bloqueante (KLaOS-only) | só ciência |
| E | Audit Gaps Modularidade KLaOS | ~95 itens P0/P1/P2 | backlog SDD #444 | indireto |

---

## 1. Contexto — caso recente que motivou o SDD A (sync bidirecional)

28/06: usuário conectou no Frontdesk dev e **não viu a Lara**. KLaOS reportava Lara existente, mas:
- Status `paused` (#395 — agente novo cria paused trava UI)
- Bridge da Lara dev tinha sido removida em sessão anterior porque a inbox 30 ("KLaOS Agendamento") foi reatribuída pra Sofia
- KLaOS não foi notificado pelo Chatwoot dessa reatribuição
- Dropdown "Conectar Agente" filtra `status=active` e não mostrava paused (#423)

**Reativamos Lara dev pra `status=active` por SQL.** Mas o gap arquitetural ficou claro: KLaOS é cego pra mudanças que admin faz direto no Chatwoot. SDD A endereça isso.

---

## 2. SDD A — Sync bidirecional (Fase 1) — DEMANDA PRINCIPAL PRO FRONTDESK

Leia o SDD completo: `C:\dev\gmb\klaos\docs\sdd_klaos_frontdesk_bidirectional_sync.md`

Resumo do que pedimos do Frontdesk em **Fase 1**:

### 2.1 Webhooks novos (Chatwoot → KLaOS)

**Status atual no fork** (revisado 28/06 pelo agente Frontdesk):

| Evento Chatwoot | Status | Ação necessária |
|---|---|---|
| `inbox_created` / `inbox_updated` | ✅ **JÁ EXISTE** em `app/listeners/webhook_listener.rb:69-84` via `Inbox::EventDataPresenter` | KLaOS só adiciona nas `subscriptions` do webhook account-level já existente |
| `inbox_deleted` | ⚠️ Confirmar — não há método explícito no listener. Provável precisar implementar | Listener custom no fork |
| `team_created` / `team_updated` / `team_deleted` | ❌ Não existe nativamente | Implementar listener + emitter custom no fork |
| `agent_bot.assigned/unassigned` (em inbox) | ❌ Não existe nativamente | Implementar custom (callback em `AgentBotInbox`) |

**Payload alvo (quando implementado):**
- `team`: `{ event, account_id, team: {id, name, description, updated_at, deleted_at?} }`
- `agent_bot`: `{ event, account_id, inbox_id, agent_bot_id, updated_at }`
- Todos enviados pra mesma URL do webhook account-level existente (não precisa endpoint dedicado).

**Headers (consistente com WebhookJob existente):**
- `Content-Type: application/json`
- `X-Chatwoot-Delivery: {UUID}` (já implementado em `lib/webhooks/trigger.rb:46`)
- `X-Chatwoot-Timestamp: {unix epoch}` (já em `:49`)
- `X-Chatwoot-Signature: sha256={HMAC-SHA256 hex}` (já em `:50`, usa `webhook.secret` do DB)

**Sobre o secret (esclarecimento importante):**
Chatwoot armazena `secret` per-webhook na tabela `webhooks` (coluna texto, 24-32 chars no que vi nos 6 webhooks KLaOS prod). **NÃO existe ENV var `KLAOS_WEBHOOK_SECRET` no Frontdesk hoje.** Cada chamada usa `webhook.secret` do registro DB correspondente. Recomendação: manter per-webhook (sem precisar provisionar ENV nova). Se KLaOS precisa de secret unificado, vamos conversar antes — significa mudança estrutural.

**Onde plugar no fork (pros 3 itens novos):** initializer custom `config/initializers/klaos_event_bridge.rb` é o caminho limpo. Patterns já existentes pra inspiração: `klaos_conversation_handoff_broadcast.rb`, `klaos_mark_unread.rb`. Usa `after_create_commit`/`after_update_commit`/`after_destroy_commit` nos models `Team` e `AgentBotInbox`, dispara via Rails `dispatcher.dispatch` se quiser passar pelo pipeline async existente, OU enfileira WebhookJob direto.

**Modo inicial:** HMAC warn-only por 48h (KLaOS loga mas processa), depois enforce. Mesmo modelo do commit KLaOS `2cec9479` (#439 item 1).

### 2.2 APIs de listagem estáveis (cron sweep do KLaOS)

KLaOS vai rodar cron 60min como rede de proteção:
- `GET /api/v1/accounts/{id}/inboxes`
- `GET /api/v1/accounts/{id}/teams`

Reconcilia com `frontdesk_inboxes`/`frontdesk_teams` locais. Cobre webhook perdido — relevante pra #443 (worker dev `:critical` não roda).

**Pedido:** confirmar que essas APIs hoje devolvem `id, name, channel_type, updated_at` e não têm rate limit pra 1 chamada/h por workspace.

### 2.3 Worker dev `:critical` (#443) — INVESTIGAR, não confirmado bug

**Atualização 28/06 pelo agente Frontdesk:** A hipótese inicial era que Worker dev não consumia fila `:critical`, deduzido da ausência de jobs `Sidekiq(critical)` numa janela de log de ~15min. Mas:

- `Procfile` linha `worker:` usa `bundle exec sidekiq -C config/sidekiq.yml`
- `config/sidekiq.yml` lista `:critical` no topo de `:queues:`
- Worker dev não tem ENV override de `SIDEKIQ_QUEUES`

Logo configuração está correta no papel. Possibilidades reais:
1. Janela de log que peguei não teve job `:critical` por coincidência (jobs vêm em rajada)
2. Erro no `dispatch_create_events` antes de chegar no Sidekiq
3. `EventDispatcherJob` (queue `:critical`) sendo descartado por outro motivo

**Não bloqueia Fase 1 em prod** (prod processa fine, eventos saem). Em dev pode bloquear teste end-to-end se confirmar bug.

**Pedido:** quando você implementar a Fase 1 e testar em dev, se webhook não chegar, sinaliza aqui que eu investigo a fundo. Se chegar normal, fechamos #443 como falso positivo.

### 2.4 Idempotência e retry (consideração nova)

`WebhookJob` Chatwoot tem retry automático em falhas 5xx/timeout. KLaOS deve assumir que pode receber **mesmo evento múltiplas vezes** e:
- Usar `X-Chatwoot-Delivery` (UUID) como chave de idempotência
- Ou estado interno: `if frontdesk_teams.updated_at >= payload.team.updated_at: skip`

Cron sweep da §2.2 também duplica trabalho — mesma lógica de "estado mais novo wins".

### 2.5 Backfill no setup (consideração nova)

Quando webhook é registrado pela primeira vez (workspace novo), KLaOS tem estado vazio. Solução:
- Rodar 1× `GET /api/v1/accounts/X/inboxes` e `.../teams` (mesma API da §2.2)
- Popular `frontdesk_inboxes` / `frontdesk_teams`
- Aí webhooks vão fluindo incrementalmente

Não exige nada novo do Frontdesk — APIs já existem.

---

## 3. Status — `chatwoot_channel` e HMAC enforce (são 2 coisas diferentes)

### 3.1 `chatwoot_channel` no payload do webhook

Já estava implementado desde 2026-04-12 via `custom/config/initializers/webhook_payload_enrichment.rb` (commit `77926ca1c`). O decorator que tentei adicionar em 28/06 (`c7ed48a30`) era **redundante** — foi revertido (`c018cab7c`). Lição salva em `feedback_audit_fork_custom_first.md`. Detalhes no `SDD_INBOX_WEBHOOK_DATA_CHANNEL_TYPE.md`.

**Pedido pra você (Frontdesk):** confirmar que monitor `bp2rkq2p4` rodou 24h sem regressão (zero flash-assigns prod pós-deploy ba8ac56c).

### 3.2 HMAC `X-Chatwoot-Signature` warn-only → enforce

Já implementado e enviado pelo Frontdesk desde sempre (`lib/webhooks/trigger.rb:44-53`). KLaOS subiu validação warn-only em prod via commit `2cec9479` (#439 item 1) em 28/06 ~19:00 BRT.

**Cronômetro 48h** corre até **2026-06-30 ~19:00 BRT**. Se logs KLaOS mostrarem zero "Invalid signature" nesse período, KLaOS flipa pra enforce.

**Pedido pra você (Frontdesk):** **decisão de flip é do KLaOS** — eu só atesto que do meu lado nenhum webhook vai parar de enviar assinatura (continuamos enviando independente do enforce). Confirma ciência.

---

## 4. SDD B — UI Modularidade KLaOS (#444) — ciência

KLaOS está modularizando configs antes hardcoded (templates, fixed_messages, handoff_team_map, etc) em DB editável via UI. Já entregamos:

- **#444 Sprint 1.1**: `agent_prompt_versions` REST + warning banner no editor (commit `0c3bca9e`)
- **#445**: `agent_specialty_templates` (tabela + tool + UI tab "Templates" no AgentConfigure; remove 31k chars do prompt da Sofia)
- **#446**: hierarquia connector→tool→agente (back+front; tools Klingo/Tenex viram disabled+lock se workspace não tem credencial)

**Cross-ref já existe** no Frontdesk: `SDD_UI_MODULARIDADE_CROSSREF.md` (18/06).

**Pedido:** revisar se algum item de modularidade KLaOS exige mudança correspondente no Frontdesk (provavelmente nenhum, mas confirma).

---

## 5. Audit D — Zero-Bypass Front KLaOS — só ciência

Audit identificou **9 ocorrências de bypass do backend Express** no front KLaOS:
- 2 CRÍTICOS (writes via RPC anon-key no `leadService.ts`)
- 3 ALTOS (RPC com `workspace_id` do cliente + 2 `postgres_changes` direto)
- 2 MÉDIOS (storage upload direto)
- 2 BAIXOS (URLs hardcoded apontando `supabase.co`)

Tasks #447-#451 criadas, bloqueiam Fase 2 do SDD A.

**Implicação pro Frontdesk:** confirmar que seu front Chatwoot também não tem bypass equivalente (chamadas direto pro DB Supabase, etc — improvável já que Chatwoot é Rails, mas vale validar). **Não precisa fazer audit agora, só ter ciência da regra.**

---

## 6. Audit E — Gaps Modularidade KLaOS — só ciência

~95 itens mapeados. Top-10 P0 que viram SDDs nos próximos dias:
1. `agent_prompt_versions` editor completo
2. `agent_instances.fixed_messages` editor
3. `agent_instances.intent_classifier_config` editor
4. `workspaces.settings.handoff_team_map` UI
5. `workspaces.settings.business_hours` UI
6. `workspaces.settings.auto_label_rules` UI
7. Editor de labels da campanha + saneamento seed `regua_cobranca_padrao`
8. `tenex_credentials.cache_config` + `sync_payment_types`
9. `agent_handoff_config` UI
10. `whatsapp_numbers` + `whatsapp_number_assignments`

**Bandeira vermelha cross-cutting:** Server TZ=`America/Sao_Paulo` como premissa em `collectionEngine.service.ts` — inviabiliza 2 workspaces em fusos diferentes no mesmo container. Pré-requisito de qualquer refactor de timezone (#308).

**Implicação pro Frontdesk:** `handoff_team_map` UI vai precisar **validar contra `frontdesk_teams.chatwoot_team_id` real**. Quando essa UI for desenhada, KLaOS vai precisar de endpoint Frontdesk pra listar teams do workspace (já existe via `GET /api/v1/accounts/X/teams`, então OK).

---

## 7. Perguntas que precisam de você

Por favor responda inline neste documento OU criando `RESPOSTA_brief_28-06.md` ao lado:

| # | Pergunta | Bloqueia o quê? |
|---|---|---|
| Q1 | Viabilidade §2.1: caminho preferido pra `team.*` + `agent_bot.*` é initializer custom em `config/initializers/klaos_event_bridge.rb` (modelo `klaos_conversation_handoff_broadcast.rb`)? | Fase 1 SDD A |
| Q2 | APIs §2.2 (`GET /api/v1/accounts/X/inboxes` e `.../teams`): você precisa confirmar campos retornados — eu posso testar dev e responder direto. Confirma se quer ou prefere ler API view spec? | Cron sweep KLaOS |
| Q3 | §2.3 #443: aceita reposicionar como "investigar SE bloquear teste dev" em vez de bug confirmado? | Fase 1 SDD A |
| Q4.1 | §3.1 `chatwoot_channel`: 24h prod sem regressão (monitor `bp2rkq2p4`) — eu confirmo? | Validação operacional |
| Q4.2 | §3.2 HMAC flip enforce 30/06 ~19:00 BRT: decisão é só sua (KLaOS); confirma ciência? | Operação KLaOS |
| Q5 | §4 (#444 modularidade): algum item exige mudança no Frontdesk? | UI #444 |
| Q6 | §5 (Zero-Bypass): seu front tem bypass equivalente? Se sim, sinaliza (sem precisar mapear hoje). | Padrão arquitetural |
| Q7 | Sobre §2.1 — concorda em manter HMAC secret per-webhook (não criar ENV `KLAOS_WEBHOOK_SECRET` unificada)? Cada webhook usa o secret próprio do DB. | Fase 1 SDD A |
| Q8 | Cronograma total pra entregar §2.1 em dev? | Planejamento |
| Q9 | Riscos não óbvios do fork em dev/prod que esse brief não cobre. | Risk mgmt |

---

## 8. Contexto adicional (referências)

- Handoff convention (KLaOS→Frontdesk): `reference_frontdesk_klaos_handoff_docs.md` (specs do agente Frontdesk pro KLaOS ficam em `docs/para-klaos-agent/`; deste lado o KLaOS commita em `docs/para-frontdesk-agent/`)
- Drift dev vs prod IDs: `reference_frontdesk_dev_prod_id_drift.md` (conta dev=10, prod=9; NUNCA copiar `handoff_team_map` literal entre ambientes)
- Infra dev: `reference_dev_frontdesk_waba.md` (Chatwoot dev em `app-desk-dev.klaos.ai`)
- HMAC warn-only padrão: commit KLaOS `2cec9479` (#439 item 1)

---

## 9. Próximos passos após sua resposta

1. KLaOS cria tasks `#447+` e começa implementação dos handlers backend Express (`/api/webhooks/chatwoot/inbox|team|agent_bot`).
2. Você implementa emitters Rails em paralelo.
3. Dev primeiro (atrás de feature flag `bidirectional_sync_v1`), 24h de observação, depois prod com HMAC warn-only por 48h, depois enforce.
4. Fase 2 (SSE backend KLaOS pra notificar front em tempo real, sem bypass) só começa **depois** de #447-#451 limpos.
5. Fase 3 (push KLaOS→Frontdesk pra agent_bot lifecycle) entra **depois** de Fase 1 estável em prod.

Obrigado — qualquer ambiguidade no brief é minha culpa, pode pingar.
