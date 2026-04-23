# Análise do Fluxo de Handoff e Assumir Conversa

| Campo | Valor |
|---|---|
| Data | 2026-04-23 |
| Autor | Matheus + análise Claude |
| Motivação | Mapear todos os caminhos possíveis entre bot e humano numa conversa, identificar gaps que bugam em produção |
| Escopo | KLaOS Frontdesk (Chatwoot) + KLaOS AI Agents + Cliente final |

---

## 1. Estados possíveis de uma conversa

| Status | Semântica oficial Chatwoot | Semântica operacional KLaOS |
|---|---|---|
| `pending` | Bot territory | Bot ativo, cliente aguardando resposta automatizada |
| `open` | Human territory | Humano atribuído ou em atendimento |
| `snoozed` | Adiada | Volta sozinha em data futura |
| `resolved` | Fechada | Não recebe mais ação até cliente voltar |

## 2. Assignees possíveis

| Tipo | Quem atende |
|---|---|
| `null` | Ninguém atribuído |
| `User` (humano) | Agente humano individual |
| `AgentBot` via `agent_bot_inbox` | Bot (via vínculo de inbox, não pela coluna `assignee_id`) |

**Nota importante**: Chatwoot tem duas formas de "ter bot":
1. **`agent_bot_inbox`** — bot vinculado à inbox (o que usamos)
2. **`conversation.assignee_agent_bot`** — bot atribuído direto à conversa (raro)

O `assignee_id` da conversa **só referencia Users, nunca bots**.

---

## 3. Matriz completa de comportamento

Quando cliente envia nova mensagem, o que cada combinação (status × assignee × bot-inbox) deveria produzir:

| Status | Assignee | Inbox tem bot? | Comportamento esperado | Quem responde |
|---|---|---|---|---|
| pending | null | sim | webhook pro bot | BOT |
| pending | null | não | conv fica parada | ninguém (bug de config) |
| pending | humano | sim | **AMBÍGUO** — ver Gap 13 | ? |
| pending | humano | não | humano responde | HUMANO |
| open | null | sim | **LIMBO** — ver Gap 3 | ninguém |
| open | null | não | limbo | ninguém |
| open | humano | sim | humano responde, bot quieto | HUMANO |
| open | humano | não | humano responde | HUMANO |
| snoozed | qualquer | — | aguarda desnooze | ninguém |
| resolved | null | sim | reabre → pending? open? | depende (ver Gap 4) |
| resolved | humano | sim | reabre → open, assignee preservado | HUMANO |

---

## 4. Fluxos completos desenhados

### Fluxo A — Vida normal com bot + handoff

```
Cliente manda 1ª msg
       ↓
Conversation criada
  status=pending, assignee=null
       ↓
AgentBotListener.message_created dispara
       ↓
Webhook POST pro bot (outgoing_url)
       ↓
Bot responde → sucesso
       ↓
(continua pingue-pongue)
       ↓
Bot decide que precisa humano
       ↓
Bot chama API Chatwoot:
  1. POST /conversations/:id/toggle_status { status: open }
  2. POST /conversations/:id/assignments { team_id: X }  (ou assignee_id)
  3. POST /conversations/:id/messages { content, private: true } (nota explicando motivo)
       ↓
Conversation atualizada:
  status=open, assignee=humano
       ↓
AgentBotListener.assignee_changed notifica humano
       ↓
Humano recebe notificação (sininho, email, push)
       ↓
Humano responde
       ↓
Humano clica "Resolver"
       ↓
Conversation status=resolved, assignee preservado
```

### Fluxo B — Reabertura (sem política de 24h)

```
Conversation resolved
       ↓
Cliente manda nova msg (X tempo depois)
       ↓
Message criada
       ↓
Chatwoot: status=open, assignee preservado (sempre)
       ↓
AgentBotListener dispara webhook pro bot? SIM (porque inbox ainda tem bot)
  MAS: bot vê que conversa tem humano atribuído e fica quieto
       ↓
Humano (assignee original) recebe... nada automático por padrão
(não dispara notification pelo reopen direto — só pelo assignee_changed se mudar)
       ↓
Conversa pode ficar parada se humano não checar
```

### Fluxo C — Reabertura COM política de 24h (SDD proposto)

```
Resolved
       ↓
Cliente manda msg
       ↓
Custom initializer verifica:
  - additional_attributes.klaos_resolved_at existe?
  - horas desde então > 24?
    └─ SIM → status=pending, assignee=null → bot assume
    └─ NÃO → agente original está online?
              └─ SIM → mantém (default Chatwoot)
              └─ NÃO → fallback (outro agente/time → bot final)
```

### Fluxo D — Humano devolve pro bot (botão manual SDD)

```
Humano abre a conv e clica "Transferir pro bot"
       ↓
Frontend chama POST /api/v1/accounts/:aid/conversations/:id/transfer_to_bot
       ↓
Custom controller:
  - assignee_id = null
  - status = pending
  - cria msg system: "Transferido pro bot por <humano>"
       ↓
Próxima msg do cliente → bot assume
```

### Fluxo E — Bot dá timeout (BUG REAL em prod)

```
Cliente manda msg
       ↓
Chatwoot dispara webhook pro bot
       ↓
Bot demora > 5s pra responder 200 OK (buffer backlog, LLM lento, tool call)
       ↓
Chatwoot RestClient::TimeoutError
       ↓
Webhooks::Trigger#handle_error chamado
       ↓
update_conversation_status:
  - conv.open!  (pending → open)
  - cria activity "Conversation was marked open by system due to an error with the agent bot"
       ↓
Conversation agora: status=open, assignee=null
  ↳ LIMBO: bot não atua (não é pending), humano não atribuído
```

### Fluxo F — Múltiplas mensagens rápidas do cliente

```
Cliente envia 3 msgs em 500ms ("oi", "meu nome é X", "pode me ajudar?")
       ↓
Chatwoot cria 3 Messages
       ↓
3 webhooks disparados em paralelo
       ↓
Bot processa 3 mensagens em paralelo ou em fila
       ↓
Respostas podem chegar desordenadas se bot não dedup/sequencia
  - Bot pode responder 3x
  - Ou dedupliar e responder 1x ao conjunto
  - Depende da implementação KLaOS
```

---

## 5. Gaps identificados — catalogados por risco

### 🔴 Críticos (bugs conhecidos em produção)

#### Gap 1 — Handoff sem ação no Chatwoot
**Sintoma**: bot fala "vou te transferir" no texto, mas NÃO chama as APIs pra mudar status/assignee.  
**Efeito**: conversa fica em pending infinitamente, cliente acha que humano vai responder, ninguém vai.  
**Evidência**: Mais Saúde tem 15 conversas em `pending` sem assignee há semanas.  
**Responsável**: KLaOS (precisa implementar as 2 PATCHes na tool de handoff).

#### Gap 2 — Webhook timeout causa limbo
**Sintoma**: KLaOS processa async com buffer, responde 200 em >5s, Chatwoot timeout → marca conv como `open` sem assignee.  
**Evidência**: msg 10245 na conv 151 ("Conversation was marked open by system due to an error with the agent bot") em 2026-04-22 22:26.  
**Efeito**: conv cai em limbo — bot não atua (não é pending), ninguém atribuído.  
**Responsável**:
- **KLaOS**: responder `{"status":"ok"}` em <2s sempre (ACK imediato, enfileirar processamento depois)
- **Frontdesk (feito hoje)**: commit `02586d04f` — guard síncrono que bypassa Sidekiq e tem log visível

#### Gap 3 — Token do bot desalinhado no KLaOS
**Sintoma**: KLaOS tem `access_token` de um bot mas o campo `frontdesk_chatwoot_bot_id` aponta pra outro. Mensagens saem com sender_id errado.  
**Evidência**: incidente 2026-04-21 com Klaus Ross (bot 25 tinha nome "klaus" porque recebia token do bot 16).  
**Responsável**: KLaOS — ao atualizar bot_id, atualizar access_token **junto**.

#### Gap 4 — Display_id vs id interno
**Sintoma**: KLaOS usa `conversation.id` (interno) na URL do POST, mas Chatwoot espera `display_id` (numerador por account). Retorna 404.  
**Evidência**: incidente 2026-04-22. Account 10 novo passou a divergir (id=151, display_id=33).  
**Status**: **Corrigido** em KLaOS commit `9837d52a`.  
**Responsável**: KLaOS — sempre usar `display_id`.

---

### 🟡 Altos (funcionam mas com risco)

#### Gap 5 — Reabertura sem regra de tempo
**Sintoma**: cliente volta 5 min depois ou 5 dias depois, sempre vai pro mesmo agente. Se agente off, conversa empaca.  
**Status**: SDD escrito (`SDD_REOPEN_POLICY.md`), aguarda decisões pendentes e implementação.

#### Gap 6 — Agente humano offline mas é o assignee
**Sintoma**: conversa reaberta fica atribuída a agente offline. Ninguém pega.  
**Mitigação atual**: filtro "Ativas" ajuda agente ver pending/open antes de resolver.  
**Fix definitivo**: política de fallback do SDD.

#### Gap 7 — Race condition no handoff
**Sintoma**: bot envia múltiplas msgs em paralelo. Última chega DEPOIS do handoff.  
**Evidência**: conv 151 — "vou te transferir" → "horário 9h-17h" → erro do bot marca conv open → "Por gentileza, aguardar" postou DEPOIS.  
**Efeito**: mensagem fora de ordem confunde cliente.  
**Responsável**: KLaOS — serializar respostas ou cancelar fila ao detectar handoff em curso.

#### Gap 8 — Buffer backlog do KLaOS
**Sintoma**: backlog stale faz novas mensagens serem processadas com delay ou nem processadas.  
**Evidência**: incidente 2026-04-22 — Lara não respondeu nada desde 17/04 por backlog antigo travando.  
**Status**: corrigido via purge + fix do detector de timeout.

#### Gap 9 — Cliente muda de canal
**Sintoma**: mesmo contato tem conversa em 2 canais (ex: widget + WA). Bot tem contexto em cada uma separadamente.  
**Risco**: atendimento duplicado, contexto perdido.  
**Responsável**: KLaOS (unificar contexto por contact) OU frontdesk (merge de conversas).

---

### 🟢 Médios (edge cases)

#### Gap 10 — Pending + humano atribuído (ambíguo)
**Sintoma**: admin atribui manualmente um humano a uma conv `pending`. Quem responde?  
**Comportamento atual Chatwoot**: bot continua recebendo webhook, mas por convenção não responde se há humano.  
**KLaOS**: provavelmente não verifica `assignee_id` e responde igual → caos.  
**Responsável**: KLaOS — no processing do webhook, verificar se `conversation.assignee_id` != null e abortar se tiver humano.

#### Gap 11 — Snoozed sem regra de retorno
**Sintoma**: conversa snoozed até X data. Ao unsnoozar, volta pra qual status? Open ou Pending?  
**Comportamento Chatwoot**: parece voltar pro status que estava antes.  
**Impacto**: se antes era pending (bot), continua. Se era open (humano), continua humano.  
**Ação**: documentar, talvez adicionar a SDD.

#### Gap 12 — Bot pausado/inativo no KLaOS mas ativo no Frontdesk
**Sintoma**: `agent_bot_inboxes.status = active` mas KLaOS desativou o agent_instance internamente. Webhook sai, KLaOS responde 200 mas não processa.  
**Efeito**: cliente fica esperando resposta que não vem.  
**Responsável**: KLaOS — sincronizar estado. Quando agent é pausado, notificar Frontdesk pra desativar o binding OU retornar código específico no webhook que ativa fallback.

#### Gap 13 — Conversa órfã no limbo pós-erro
**Sintoma**: Gap 2 criou conv open sem assignee. Ninguém pega. Cliente manda msg nova, Chatwoot pode não disparar webhook (ou dispara e bot fica quieto porque status=open).  
**Responsável**: ambos — KLaOS evita timeout, Frontdesk tem política de recuperação (script que varre conv open+null_assignee há >X min e devolve pro bot).

#### Gap 14 — Múltiplos bots por inbox
**Sintoma**: admin vincula 2 bots. Chatwoot tem constraint `idx_afb_one_agent_per_inbox`, mas se for violado por SQL direto...  
**Status**: improvável via UI, mas validar em script de provisionamento.

---

### 🔵 Baixos (conceituais / documentação)

#### Gap 15 — Reabertura com resolved_at não registrado
**Sintoma**: conversas resolvidas antes da feature de timestamping não têm `resolved_at`. Política de 24h não aplica retroativamente.  
**Mitigação**: aceita, documenta no SDD.

#### Gap 16 — Agent_bot pode postar fora da janela 24h WABA
**Sintoma**: Meta Cloud API bloqueia mensagens livres fora de 24h após última msg do cliente. Bot tenta, recebe erro. Cliente fica sem resposta.  
**Responsável**: KLaOS — no handoff retroativo, usar template aprovado em vez de free-form.

#### Gap 17 — Dedup de mensagens idênticas rápidas
**Sintoma**: cliente manda "oi" 3x em 1s. Bot responde 3x ou dedup?  
**Responsável**: KLaOS — janela de dedup por contact_id (ex: 5s).

---

## 6. Responsabilidades por camada

### Frontdesk (Chatwoot fork) tem que garantir:

- [x] Webhook dispara em toda mensagem incoming (listener nativo + custom guard)
- [x] Bot vinculado à inbox com `agent_bot_inboxes.status = active`
- [x] `outgoing_url` correto e atualizado
- [x] Bot tem `access_token` válido
- [x] Custom guard faz HTTP síncrono pra bypassar falha do Sidekiq (commit `02586d04f` hoje)
- [ ] **Política de reabertura com regra de tempo** (SDD, aguardando decisões)
- [ ] **Botão "Transferir pro bot"** na UI (SDD)
- [ ] **Script de recuperação** — varre conversas em limbo (open+null_assignee+msg recente) e devolve ao bot
- [x] Logar rastro do guard no `conversation.additional_attributes` pra debug via DB (hoje)

### KLaOS AI Agents tem que garantir:

- [ ] **Responder webhook em <2s SEMPRE** — ACK imediato, processa em fila depois
- [ ] **Idempotência** — webhook duplicado não gera resposta duplicada
- [ ] **Handoff completo**: 3 chamadas (`toggle_status`, `assignments`, private note) quando decidir transbordar
- [ ] **Verificar `conversation.assignee_id`** — se tem humano atribuído, abortar processamento (não pisar em cima)
- [ ] **Usar `display_id`** no path da URL, não id interno (**corrigido** commit `9837d52a`)
- [ ] **Sincronizar `access_token`** junto com `bot_id` ao reprovisionar (**corrigido** hoje)
- [ ] **Dedup de mensagens idênticas** em janela curta
- [ ] **Detecção de timeout do próprio bot** usando timestamp da mensagem atual (**corrigido** commit `4ab690da` hoje)
- [ ] **Usar template WABA aprovado** quando postar fora da janela 24h
- [ ] **Desativar agente no Frontdesk** quando agent_instance é pausado/deletado

### KLaOS CRM tem que garantir:

- [ ] **CRM Bridge** atualiza conversation.custom_attributes com dados do deal (já implementado)
- [ ] **Endpoints não dependem do bot** — deal lookup funciona mesmo sem bot ativo
- [ ] **Agendamento de closer** registra `scheduled_at` + `closer_assigned` no Frontdesk

---

## 7. Diagrama de estados (simplificado)

```
         ┌─────────────────┐
         │  Cliente 1ª msg │
         └────────┬────────┘
                  ▼
         ┌─────────────────┐
  ┌─────▶│     PENDING     │◀──────┐
  │      │ (bot + null)    │       │
  │      └────────┬────────┘       │ (humano "Transferir pro bot")
  │               │                │
  │ (cliente msg  │ (bot handoff:  │
  │  resolved>24h │   set humano + │
  │  via política)│   status=open) │
  │               ▼                │
  │      ┌─────────────────┐       │
  │      │      OPEN       ├───────┘
  │      │ (humano atende) │
  │      └────────┬────────┘
  │               │
  │               │ (humano resolve)
  │               ▼
  │      ┌─────────────────┐
  └──────┤    RESOLVED     │
         └─────────────────┘
                  ▲
                  │ (cliente volta <24h: reabre como OPEN com humano)
                  │ (cliente volta >24h: reabre como PENDING pro bot)
```

---

## 8. Catálogo de "momentos críticos" pra debugar

Quando algo não funciona, verificar nessa ordem:

1. **Conversa** — qual status? qual assignee? inbox qual?
2. **Inbox** — tem bot vinculado? `agent_bot_inboxes.status=active`?
3. **Bot** — `outgoing_url` correto? `access_token` existe?
4. **Webhook dispatch** — `conversation.additional_attributes.agent_bot_guard_log` mostra a última tentativa? HTTP code?
5. **KLaOS side** — tem buffer travado? agent_instance ativo? `frontdesk_chatwoot_bot_access_token` bate com Frontdesk?
6. **Mensagem do bot** — Chatwoot recebeu? sender_id correto? display_id no path?

---

## 9. Testes de QA para cobrir

Novos TCs pra adicionar ao plano (seção Integração §6 do `PLANO_TESTES_INTEGRACAO.md`):

| ID | Título | Fluxo | Prioridade |
|---|---|---|---|
| TC-790 | Bot timeout 5s → conv vai pra open + erro visível | Gap 2 | Crítica |
| TC-791 | Guard síncrono grava em additional_attributes | Gap 2 fix | Crítica |
| TC-792 | Humano atribuído + cliente manda msg → bot fica quieto | Gap 10 | Alta |
| TC-793 | Múltiplas msgs cliente em <1s → bot dedup | Gap 17 | Média |
| TC-794 | Botão "Transferir pro bot" (SDD) | Gap manual | Alta |
| TC-795 | Reabertura >24h vai pro bot (SDD) | Gap 5 | Crítica |
| TC-796 | Handoff completo: 2 PATCH + notification | Gap 1 | Crítica |
| TC-797 | Token desalinhado após reprovision | Gap 3 regressão | Alta |
| TC-798 | Display_id no POST (regressão) | Gap 4 regressão | Crítica |
| TC-799 | Conv órfã recuperada via script | Gap 13 | Média |

---

## 10. Multi-tenancy — gaps específicos da plataforma

O KLaOS serve múltiplos workspaces simultaneamente. O que quebra com 1 tenant pode ser catastrófico com N. Cada fluxo acima precisa ser reavaliado por essa lente.

### 10.1 Isolamento dos tenants

Cada tenant (= account no Chatwoot / workspace no KLaOS) tem:

| Recurso | Isolamento |
|---|---|
| Inboxes | por `account_id` |
| Agents humanos | `account_users` por account |
| Bots | `agent_bots.account_id` (cada bot pertence a 1 account) |
| Contatos | por `account_id` |
| Conversas | por `account_id` |
| Custom attributes | por `account_id` |
| WhatsApp Connections | por `account_id` (WABA dedicado) |
| Evolution Instances | **compartilhadas no pool** (ver Gap 23) |
| Agent_instances KLaOS | por `workspace_id` |

### 10.2 Gaps multi-tenant novos

#### 🔴 Gap 18 — Buffer do KLaOS afeta tenants
**Sintoma**: KLaOS tem fila/buffer de processamento compartilhado. Tenant A manda 1000 mensagens em rajada → fila enche → latência pra B, C, D sobe junto → Chatwoot de todos eles dá timeout 5s → Gap 2 propaga pra todo mundo.  
**Evidência**: incidente 2026-04-22 — Lara da Mais Saúde ficou com backlog desde 17/04, mas a gente não sabe se afetou outros bots (Klaus, Iris, Klaus Ross) nesse período.  
**Responsável**: KLaOS — **filas por workspace** (ou por agent_instance), com QoS separado. Um tenant ruim não pode degradar os outros.

#### 🔴 Gap 19 — Token leak entre tenants
**Sintoma**: KLaOS tem race condition ao armazenar `frontdesk_chatwoot_bot_access_token`. Ao reprovisionar bot do tenant A, sobrescreve o token do tenant B.  
**Evidência**: bug de 2026-04-21 (Klaus Ross usando token do Klaus) foi dentro do mesmo tenant (GMB), mas a mecânica é a mesma pra cross-tenant.  
**Responsável**: KLaOS — transação atômica ao atualizar bot_id + access_token, sempre escopado ao `agent_instance_id` correto.

#### 🔴 Gap 20 — Cross-tenant data access via bot
**Sintoma**: bot do tenant A consegue, via tool call, consultar dados (deals, contatos) do tenant B por ID vazado ou bug no serviço CRM.  
**Evidência**: não vimos em prod, mas é CVE em potencial.  
**Responsável**: KLaOS CRM — toda tool call valida `workspace_id` do agent_instance bate com `workspace_id` do recurso consultado. **Chatwoot já faz isso no nível da API** (conversations scoped por account_id), mas tools do bot podem burlar se chamarem direto o CRM interno.  
**QA test**: TC-582 (bot acessa deal de outro workspace → bloqueado). Cobrir explicitamente.

#### 🟡 Gap 21 — Config de reopen policy por tenant
**Sintoma**: política de 24h é global hoje (ver SDD). Cliente A quer 12h, cliente B quer 48h.  
**Status**: SDD já prevê (DP-5 — opt-in por workspace), mas falta UI.  
**Responsável**: Frontdesk — tela `Configurações → Automação → Política de Reabertura`.

#### 🟡 Gap 22 — Limite Meta API compartilhado
**Sintoma**: Meta Cloud API tem rate limits (messages/sec por WABA). Tenant que tem campanha massiva queima o limite, outros ficam esperando.  
**Impacto**: maior em templates de broadcast. Menor em mensagens individuais (bot responde 1-1).  
**Responsável**: KLaOS + Frontdesk — throttling por tenant ao enfileirar templates.

#### 🟡 Gap 23 — Pool Evolution compartilhado
**Sintoma**: Evolution tem instâncias compartilhadas entre tenants (cliente pequeno usa número do pool). Se um cliente exagera, o número é banido pelo WhatsApp, afetando outros tenants no mesmo número.  
**Responsável**: KLaOS — isolar pool por tenant OU implementar cota de uso por tenant/número.

#### 🟡 Gap 24 — Métricas e logs misturados
**Sintoma**: logs do KLaOS e Chatwoot não marcam `account_id` em todos os logs. Debug de incidente multi-tenant fica difícil.  
**Responsável**: ambos — todo log estruturado tem `account_id` + `workspace_id` + `agent_instance_id`.

#### 🟢 Gap 25 — Super Admin vê tudo, mas e suporte?
**Sintoma**: funcionário KLaOS de suporte precisa investigar bug no tenant A sem comprometer dados. Hoje ou é Super Admin (full access) ou nada.  
**Responsável**: Frontdesk — role "suporte KLaOS" read-only cross-account (feature futura).

#### 🟢 Gap 26 — Custom attributes renomeados em tenant diferente
**Sintoma**: CRM Bridge cria custom_attributes com mesmo nome em todos os tenants (`crm_deal_stage`). Se cliente renomear pra "Pipeline_Stage" no tenant dele, CRM Bridge escreve no nome errado.  
**Status**: ainda não teve caso mas conceitualmente é frágil.  
**Responsável**: Frontdesk — CRM Bridge usa prefixo `klaos_` + identificador fixo, não permite rename.

#### 🟢 Gap 27 — Política de handoff por tenant
**Sintoma**: tenant A quer handoff pra time X. Tenant B quer pra admin Y. Hoje lógica de handoff do KLaOS pode estar hardcoded.  
**Responsável**: KLaOS — configuração de handoff target por `agent_instance`, não global.

#### 🟢 Gap 28 — Horário de atendimento por tenant
**Sintoma**: tenant A atende 24/7, tenant B das 8h-18h. Bot precisa saber pra dizer "fora do horário, vamos te responder amanhã".  
**Responsável**: KLaOS — config de horário por `agent_instance`. Frontdesk já tem `inbox.working_hours`.

#### 🟢 Gap 29 — Ambientes dev vs prod misturados
**Sintoma**: agent_instance em KLaOS dev aponta pra Chatwoot prod por config stale. Resposta de teste vaza pra cliente real.  
**Evidência**: analogia com o bug do display_id que só apareceu em account maduro.  
**Responsável**: KLaOS — config de ambiente (dev/prod) por agent_instance com validação cruzada.

---

### 10.3 Responsabilidades revisadas sob lente multi-tenant

**Frontdesk (Chatwoot fork):**
- [x] Tenant isolation via `account_id` em todas as queries (nativo do Chatwoot)
- [ ] **Política de reopen opt-in por account** (SDD)
- [ ] **CRM Bridge usa nomes de atributo com prefixo fixo** que cliente não pode renomear
- [ ] **Logs estruturados incluem account_id** em todos os custom
- [ ] **Webhook guard registra account_id** no `agent_bot_guard_log`

**KLaOS AI Agents:**
- [ ] **Filas/buffers separados por workspace** (QoS)
- [ ] **Transação atômica bot_id + access_token** escopada a `agent_instance_id`
- [ ] **Config de handoff target** por agent_instance (team/agente/admin)
- [ ] **Config de horário de atendimento** por agent_instance
- [ ] **Validação cruzada workspace_id** em toda tool call
- [ ] **Ambiente dev/prod** explícito no agent_instance

**KLaOS CRM:**
- [ ] **Tools do bot validam workspace_id** antes de qualquer query
- [ ] **Cross-tenant access bloqueado** por RLS no Supabase (ou equivalente)
- [ ] **Rate limit por workspace** em campanhas

**Pool/Shared:**
- [ ] **Evolution pool isolado por tenant** ou cota por tenant
- [ ] **Meta API throttling por WABA** (não global)
- [ ] **Observabilidade cross-tenant** (dashboards com `account_id` filtrável)

---

### 10.4 Catálogo "momentos críticos" revisado com multi-tenancy

Quando investigar bug, sempre começar por:

1. **Qual account/workspace?** — sem isso, análise é inútil
2. **Qual agent_instance do KLaOS?** — se aplicável
3. **Esse problema atinge só esse tenant ou múltiplos?** — resposta muda a severidade
4. **Tem infraestrutura compartilhada envolvida?** (pool, queue, token, API limit)

---

---

## 11. Consolidação com respostas do time KLaOS (2026-04-23)

Respostas obtidas ao briefing enviado. Atualização de cada área:

### 11.1 Status dos gaps identificados

| Gap | Status atualizado | Fonte |
|---|---|---|
| **Gap 1** (handoff sem ação completa) | 🟡 **Parcialmente resolvido** — KLaOS chama `sendMessage` + `sendMessage` (activity) + `toggleConversationStatus` + `assignConversationToTeam`. MAS: erros são só `logger.warn`, não abortam o fluxo. Se `assignConversationToTeam` dá 404 (team errado), conv fica `open` sem assignee — o pattern reportado. | KLaOS pt. 11 |
| **Gap 2** (webhook timeout 5s → conv vira open) | ✅ **RESOLVIDO hoje** — commit `9c327d8b` força ACK <100ms: `res.status(200).json({status:'ok'})` é primeira coisa, processing via `setImmediate`. Telemetria `webhook:acked {ackMs}` e `webhook:completed {totalMs}` adicionada. | KLaOS pt. 2-3 |
| **Gap 3** (token desalinhado) | ✅ **Arquitetura defensiva** — token encriptado AES-256-CBC em `agent_instances.frontdesk_chatwoot_bot_token`, write-path sempre `eq('id', agentInstanceId)`. Bug resolvido não volta. | KLaOS pt. 5 |
| **Gap 4** (display_id vs id) | ✅ Corrigido commit `9837d52a` | Ontem |
| **Gap 5-6** (reabertura sem regra de tempo) | 🔴 **Pior do que eu achava** — constante `HUMAN_AGENT_ACTIVITY_WINDOW_MS = 45_000` em `types/conversationStatus.ts`. **45 segundos HARDCODED**, nem 24h nem configurável. SDD precisa ser reescoped. | KLaOS pt. 19 |
| **Gap 17** (dedup msgs idênticas) | ✅ **Resolvido** — dedupKey `agentInstance.id:chatwootConversationId:webhookMessageId` em Map in-memory com TTL. | KLaOS pt. 4 |
| **Gap 18** (buffer afeta tenants) | 🟡 **Confirmado parcialmente** — buffer é por `conversation_id` (OK por conversa), mas Node é single-thread. Pico de LLM calls trava event loop inteiro → afeta TODOS os tenants. **Sem worker pool dedicado por tenant.** | KLaOS pt. 1 |
| **Gap 19** (token leak entre tenants) | 🟢 **Baixo risco** — write path escopado via `.eq('id', agentInstanceId)`. Sem unique constraint por (workspace_id, agent_instance_id) mas não vejo vetor prático de leak. | KLaOS pt. 5 |
| **Gap 20** (cross-tenant data access via tools) | 🔴 **Confirmado gap** — validação existe no servidor (tool adiciona `.eq('workspace_id', workspaceId)` manualmente), mas **SEM TESTE AUTOMATIZADO de cross-tenant access**. RLS no Supabase existe em algumas tabelas (crm_deals, crm_contacts, knowledge_bases), mas backend usa `service_role` que bypassa. Defesa em profundidade ausente. | KLaOS pt. 6-7 |
| **Gap 22** (Meta API limit compartilhado) | Não abordado — precisa investigar `evolutionApi.service.ts` | KLaOS pt. 8 |
| **Gap 23** (Evolution pool) | 🟡 **Precisa investigar** — leitura inicial do KLaOS é que cada workspace cria instância dedicada (não pool), mas não tem certeza. Sem rate limit por tenant. | KLaOS pt. 8-9 |
| **Gap 24** (logs sem account_id) | 🟡 **Parcialmente estruturado** — maioria dos logs tem `{agentInstanceId, workspaceId, conversationId}` mas não é uniforme. Filtrável via jq/regex no Railway, não tem campo fixo. | KLaOS pt. 17 |
| **Gap 27** (handoff target por tenant) | ✅ **Configurável** — via `agent_frontdesk_bridge` + `workspaces.closer_team_id`. Não é hardcoded. | KLaOS pt. 10 |
| **Gap 28** (horário por tenant) | 🔴 **Confirmado gap** — sem config. Depende do system_prompt mencionar o horário. Sem check automatizado no runtime. | KLaOS pt. 13 |
| **Gap 29** (dev/prod mistura) | 🟡 **Isolado por INFRA** — `api-dev.klaos.ai` → Chatwoot dev, `api.klaos.ai` → Chatwoot prod. Cada workspace existe em só um env. Risco se `PUBLIC_BACKEND_URL` for setada errado manualmente. | KLaOS pt. 15 |
| **Bot desativação ao pausar agent** | ✅ **Resolvido** — commit `a7cc48d7`: `updateStatus → paused/error/archived` desvincula bot de todas inboxes. Active → re-atacha via `agent_frontdesk_bridge`. | KLaOS pt. 20 |

### 11.2 Gaps novos descobertos via resposta KLaOS

#### 🔴 Gap 30 — Node event loop single-thread afeta todos os tenants
**Sintoma**: Pico de LLM calls de um tenant trava event loop do Node → webhook ACK demora → Chatwoot timeout → limbo em MASSA.  
**Novidade**: mesmo com buffer por conversation_id, não há isolamento de CPU.  
**Mitigação parcial**: ACK <100ms hoje (9c327d8b) diminui o risco pela janela menor de bloqueio.  
**Solução definitiva**: worker pool por tenant, ou mover LLM calls pra worker threads, ou horizontalizar (múltiplas instâncias Node por workspace).

#### 🔴 Gap 31 — `HUMAN_AGENT_ACTIVITY_WINDOW_MS = 45_000` hardcoded
**Sintoma**: janela de 45s (não 24h como eu achei antes) governa detecção de "humano ativo" pro bot calar. Hardcoded, não é por tenant, não é configurável via UI.  
**Impacto no SDD**: a proposta original de "24h" no `SDD_REOPEN_POLICY.md` precisa ser reescoped — ou é outro layer (reopening de resolved) ou é o mesmo e precisa ampliar essa constante pra 24h + tornar configurável.  
**Ação**: esclarecer com KLaOS se `HUMAN_AGENT_ACTIVITY_WINDOW_MS` é "janela de silêncio do bot quando humano respondeu" (makes sense 45s) ou "janela pra aplicar reopen policy" (deveria ser 24h).

#### 🔴 Gap 32 — Handoff silencioso quando API falha
**Sintoma**: se `assignConversationToTeam` dá 404 (team errado/inexistente), KLaOS só loga `logger.warn`. Conversa fica `open` sem assignee. Cliente não tem quem responda.  
**Evidência**: padrão reportado na conv 151.  
**Fix KLaOS**: tornar bloqueante ou ter retry com team fallback (ex: default `closer_team_id` do workspace).

#### 🟡 Gap 33 — RLS ausente em tabelas críticas do Supabase
**Sintoma**: backend usa `service_role` que bypassa RLS. Se um dev escrever código errado e esquecer `.eq('workspace_id', ...)`, vaza dados cross-tenant sem ninguém perceber.  
**Exemplo de alvo**: `agent_instances`, `frontdesk_users`, `frontdesk_accounts`, `agent_frontdesk_bridge`.  
**Fix**: RLS ativo em todas tabelas sensíveis + testes automatizados que tentam acesso cross-tenant e esperam falha.

#### 🟡 Gap 34 — `PUBLIC_BACKEND_URL` sem validação cruzada
**Sintoma**: se env var for setada errado no Railway, um workspace "dev" pode falar com Chatwoot "prod" (ou vice-versa). Resposta de teste vaza pra cliente real.  
**Fix**: startup check no KLaOS — cada workspace tem seu Chatwoot URL esperado, valida contra `PUBLIC_BACKEND_URL` ao boot.

#### 🟢 Gap 35 — Sem dashboard de métricas de agents por tenant
**Sintoma**: observabilidade pra bots/agents é gap. Klaus Analytics existe pra KLaOS mas não pra agents (handoff rate, latência, error rate por agent_instance).  
**Fix**: dashboard `/klaos-control-panel/agents-analytics` por workspace.

---

### 11.3 O que foi resolvido hoje (2026-04-23)

| Fix | Commit KLaOS | Impacto |
|---|---|---|
| ACK imediato do webhook <100ms | `9c327d8b` | Elimina timeout 5s do Chatwoot → fim do "marked open by system due to error" |
| Dedup de webhook por agentInstance.id:convId:msgId | (na mesma PR) | Retry não gera resposta duplicada |
| Desativação de bot ao pausar agent_instance | `a7cc48d7` | Status paused/error/archived desvincula bot no Chatwoot automaticamente |
| Telemetria `webhook:acked` + `webhook:completed` | `9c327d8b` | Observabilidade sobre latência real |
| Fix display_id | `9837d52a` (ontem) | Elimina 404 em POST pro Chatwoot |
| Fix timeout detector no buffer | `4ab690da` (ontem) | Mensagens não disparam handoff errado |
| Guard síncrono Frontdesk (Net::HTTP direto) | `02586d04f` (Frontdesk) | Bypassa Sidekiq stall, log direto no DB |

### 11.4 Áreas que ficaram sem resposta

O agente KLaOS marcou "não sei / precisa investigar" em:
- **Pool Evolution** — modelo exato (dedicated vs pool) e rate limiting
- **Plano de recuperação número WABA banido**

Essas questões devem ser elevadas pra eng lead ou investigadas com dev da Evolution.

### 11.5 Investigação forense da conv 151 (Gustavo) — 2026-04-23

O agente KLaOS puxou logs do Railway commit `9c327d8b` (após fix ACK+observability). Resultado:

**Fluxo completo operou verde:**

1. **Webhook ACK** — `ackMs: 0` — fix dos 5s funcionou
2. **Tool `consultar_debito` invocada** — `cpf: '71669926460'`, completou em 1087ms
3. **Tenex retornou dados reais**:
   - 1 cliente encontrado: `JOSE GUILLERMO SILVA QUINTERO`
   - `hasActivePlan: true, totalSales: 1`
   - 0 títulos com dados de pagamento (filtrados)
4. **Entrega**: `POST /api/v1/accounts/10/conversations/33/messages` ✅ (display_id correto)

**Conclusões da investigação:**

- ✅ Sistema funciona — webhook + tool + entrega, todos verdes
- ✅ Resposta da Lara "não consta nenhum boleto pendente" **está correta** (reflete retorno da Tenex)
- 🟢 **Não foi alucinação** — a tool foi chamada e o dado veio real
- ⚠️ **O CPF `71669926460` é de JOSE GUILLERMO, não do Gustavo** — provavelmente CPF de teste, parente, ou erro do cliente

**Circuit breaker no Chatwoot?**
O agente KLaOS reportou: "Chatwoot tinha circuit-breakeado o bot para a conv 151 após timeouts antigos de 5s". 

⚠️ **Nota técnica**: no código `lib/webhooks/trigger.rb` do Chatwoot 4.11 não achei circuit breaker explícito. Só há `update_conversation_status` que muda conv pra `open` em caso de erro. Hipótese: o "circuit breaker" foi **efeito colateral** — conv virava `open` → bot não atuava mais (open não é território dele) até intervenção manual pra voltar pra pending. Combinado com Sidekiq talvez ter deixado jobs em dead queue (3 attempts max no `AgentBots::WebhookJob`), a impressão é de circuit breaker.

**Fix efetivo:**
- ACK <100ms do KLaOS (commit `9c327d8b`) impede novo timeout
- Custom guard síncrono do Frontdesk (commit `02586d04f`) bypassa Sidekiq
- Desativação automática ao pausar agent_instance (commit `a7cc48d7`) evita binding stale

**Próxima validação recomendada pelo agente KLaOS:**
Testar a Lara com CPF que **tem boleto vencido** (algum de teste com título aberto no Tenex) pra validar o caminho feliz — o caminho atual (CPF sem boleto) está correto. Incluir como TC no plano QA:

| ID | Título | Prioridade |
|---|---|---|
| TC-800 | Lara consulta CPF com boleto ativo — responde com valor + dados | Crítica |
| TC-801 | Lara consulta CPF sem boleto — responde "tá tudo certinho" | Alta |
| TC-802 | Lara consulta CPF inexistente — fallback amigável | Alta |
| TC-803 | Lara consulta CPF de outro workspace (cross-tenant) — bloqueado | **Crítica** (segurança) |

---

## 12. Próximas ações recomendadas

### Imediato (hoje)
1. **Validar commit `02586d04f`** (guard síncrono) em dev — testar se próxima mensagem do cliente gera log no `additional_attributes`
2. **KLaOS implementar ACK imediato** — responder 200 em <2s independente do processamento

### Curto prazo (esta semana)
3. **KLaOS implementar handoff completo** — os 3 chamados de API (toggle_status, assignments, note)
4. **Fechar decisões do SDD** `SDD_REOPEN_POLICY.md` (DP-1 a DP-5)
5. **Implementar política de reabertura** conforme SDD

### Médio prazo (2 semanas)
6. **Script de recuperação de conversas órfãs** — varre open+null_assignee+última atividade < X min e devolve ao bot
7. **Botão "Transferir pro bot"** na UI (frontend + endpoint)
8. **Dedup de mensagens no KLaOS** por janela curta
9. **Adicionar TCs novos no plano QA** (TC-790 a TC-799)

### Longo prazo
10. **Dashboard de observabilidade** — volume de handoffs automáticos vs manuais, conversas em limbo, taxa de timeout do bot
11. **Alerta automático** quando conv fica em open+null_assignee+msg recente (limbo) por > X minutos
