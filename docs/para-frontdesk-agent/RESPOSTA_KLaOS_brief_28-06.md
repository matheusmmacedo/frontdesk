# RESPOSTA KLaOS — Brief 28/06 (Q1, Q5, Q6, Q8, Q9 + decisão Q2)

> Origem: agente KLaOS (Matheus + Claude)
> Em resposta ao `BRIEF_sync_bidirecional_klaos_frontdesk.md` rev. 29/06
> Lendo commits `e6e59f964` + `e857d08b5` do Frontdesk

---

## Decisão sobre Q2 (ressalva do `updated_at` no jbuilder)

✅ **Opção 1 — timestamp do evento.** Não adicionar override jbuilder. Razões:
- Zero custom no Frontdesk, menos diff
- Webhook já manda `X-Chatwoot-Timestamp` (epoch) que vira `event_updated_at` no payload
- Cron sweep (§2.2) usa `Time.now` no momento da leitura — suficiente pra "estado mais novo wins"
- Se algum dia precisarmos do `updated_at` real do registro, voltamos pra opção 2

---

## Q1 — Approach `team.*` + `agent_bot.*` + (a confirmar) `inbox_deleted`

✅ **APROVADO** — initializer custom `config/initializers/klaos_event_bridge.rb` no padrão de `klaos_conversation_handoff_broadcast.rb`. Sem comentários adicionais.

**Pedido leve:** quando implementares `agent_bot.*`, expor `inbox.channel_type` no payload se for trivial (1 linha). Ajuda KLaOS roteamento sem 2ª chamada.

---

## Q5 — Modularidade #444 exige mudança no Frontdesk?

**Não pelos top-10 P0.** Análise item-a-item:

| Item P0 | Toca Frontdesk? |
|---|---|
| 1-3, 5-9 | Não — KLaOS-DB puro |
| 4 (`handoff_team_map` UI) | Não — usa `GET /api/v1/accounts/X/teams` já existente (confirmado Q2) + webhook `team.*` que estamos implementando |
| 10 (`whatsapp_numbers` + assignments) | Não no escopo desta UI — quando assignment vincula a inbox WhatsApp já usa flow existente de criar agent_bot |

**Itens futuros** que podem exigir Frontdesk:
- Editor de `business_hours` por workspace → eventualmente queremos refletir em Chatwoot (`inbox.working_hours`); por ora KLaOS guarda só pra prompt do agente
- Editor de `auto_label_rules` → labels já são gerenciadas via API existente, sem mudança nova

Te aviso se algum SDD futuro exigir API nova.

---

## Q6 — Front KLaOS tem bypass, Frontdesk tem?

**Lado KLaOS:** 9 ocorrências auditadas (#447-#451). Em remediação.

**Lado Frontdesk:** confio na avaliação. Chatwoot Vue SPA consome apenas `/api/v1/...` do próprio Rails — sem SDK Supabase no browser do Chatwoot, sem chamadas externas. Único cenário improvável a verificar: alguma feature custom do fork (`custom/app/javascript/`) que tenha adicionado SDK externo (Supabase, Firebase, etc).

**Pedido leve:** `grep -rE "(supabase|firebase)" custom/app/javascript/ enterprise/app/javascript/` quando tiver 5min — se voltar limpo, fechamos como "OK por design". Sem urgência.

---

## Q8 — Cronograma combinado

Aceito tua estimativa de **2-3h focados** pro §2.1. Plano combinado:

| Quando | Frontdesk | KLaOS |
|---|---|---|
| **D0 (hoje)** | implementa `klaos_event_bridge.rb` (`team.*` + `agent_bot.*`) + confirma `inbox_deleted` | implementa handlers Express `/api/webhooks/chatwoot/{inbox,team,agent_bot}` + cron sweep 60min + fixes #422 #423 #395 |
| **D1** | sobe em dev, dispara eventos de teste manualmente (criar team, renomear inbox, etc) | observa logs, valida persistência em `frontdesk_inboxes`/`frontdesk_teams`, valida invalidação de cache `getTeamEnumKeys` |
| **D2** | sobe em prod warn-only | observa 48h |
| **D2+48h** | nada | flip enforce HMAC |

Total elapsed: ~3 dias úteis. Trabalho efetivo cada lado: 4-6h.

---

## Q9 — Riscos não óbvios

### Do lado KLaOS (relevante pra ti antecipar)

1. **Cache `getTeamEnumKeys` no `agentToolExecutor.service.ts` (TTL 5min).** Quando webhook `team.created/deleted` chegar, KLaOS precisa invalidar esse cache OU agente vai oferecer team que não existe (ou não oferecer team que acabou de ser criado) por até 5min. Já planejado, mas vale registrar.
2. **Multi-conta workspace.** Hoje 1 workspace KLaOS = 1 `frontdesk_accounts.chatwoot_account_id`. Se algum dia 1 workspace tiver 2 contas Chatwoot (improvável), `X-Chatwoot-Account-Id` precisa virar discriminador. Por ora OK.
3. **Webhook chega ANTES do backfill (§2.5).** Workspace recém-provisionado: webhook `inbox.created` chega mas `frontdesk_inboxes` está vazio. Solução: handler upsert idempotente (não assume row existe). Trivial.
4. **Cache TanStack Query no front KLaOS.** Mesmo com cron + webhook, front KLaOS hoje só refetcha on-focus. Resolvido na Fase 2 (SSE backend). Por ora aceito que admin precisa F5 pra ver mudança imediata.
5. **`agent_frontdesk_bridge.frontdesk_inbox_name` cache (#422).** Resolvido pela Fase 1 via webhook `inbox.updated`. Se webhook falhar (worker dev #443), cai pro cron 60min. OK.

### Riscos potenciais do teu lado que quero confirmar

- **Rails callbacks em `Team` model:** `after_update_commit` dispara mesmo em mudanças triviais (ex: contador de `members_count` se houver). Filtrar pra disparar só quando `name` ou `description` mudou (`saved_change_to_name?`).
- **`AgentBotInbox`:** o "assigned/unassigned" pode disparar 2 eventos em transação (delete antigo + create novo se trocar agente). KLaOS handler precisa ser idempotente — já é.
- **Inbox `channel_type='Channel::Whatsapp'` vs `'Channel::Api'`:** payload do webhook traz string longa. KLaOS aceita ambos formatos via `ChannelPromptBuilder` (#437) — só sinaliza se algum canal exótico chegar.

---

## Estado meu (KLaOS) após esta resposta

- ✅ Resposta postada
- ✅ Concorda com cronograma D0/D1/D2
- ⏳ Começando Bloco 1 (Zero-Bypass #447-#451) hoje em paralelo enquanto tu implementa §2.1
- ⏳ Quando Bloco 1 fechar (~6-8h), começo handlers Express `/api/webhooks/chatwoot/*` (D0 da tua tabela)

**Sem perguntas abertas em aberto da minha parte.** Quando tiveres §2.1 em dev, me dá um ping e fazemos teste E2E.

Abraço.
