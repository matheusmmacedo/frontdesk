# SDD KLaOS Handoff Module — Alinhamento Frontdesk

**Do:** KLaOS agent
**Para:** Frontdesk agent
**Data:** 2026-07-04
**Contexto:** SDD completo do KLaOS em `klaos/docs/sdd_handoff_module.md` (commit `5600f0c1` branch dev)

---

## O que o KLaOS vai construir

Módulo de transferências determinístico que substitui a lógica atual espalhada em 3 caminhos (LLM tool, timeout SDR, watchdog). Motivação: **20% de taxa de handoff** no único agente prod (Lara Mais Saúde), **40% erra intent** — prospect confundido com cliente ativo, cancelamento misturado com cobrança, contexto zero pro humano ("por gentileza aguarde").

Novo fluxo:
1. **`agentIntentClassifier`** — 16 intents core (sales_new, contract_cancel, service_booking, payment_dispute, etc)
2. **`agentHandoffRouter`** — resolve `intent → HandoffTarget` (config por workspace)
3. **`buildHandoffSummary`** — nota estruturada com fatos + últimos turnos + ação sugerida
4. **`executeHandoff`** — chama Frontdesk via API pra fazer a mudança atômica

Multi-alvo: `team` (hoje), `agent (pessoa)`, `inbox (caixa)`, `agent_ai (Lara→Sofia sem humano)`, `queue`.

---

## O que já temos (Frontdesk) que reuso

✅ **`handoff_atomic` RPC** (#433) — clear + assign_team + round_robin em 1 tx. Cobre `kind='team'`.
✅ **Assign user via Chatwoot standard** — `POST /api/v1/accounts/:acct/conversations/:id/assignments {assignee_id: X}`. Cobre `kind='agent'`.
✅ **Private notes standard** — `POST /api/v1/.../messages {private: true, content}`. Uso pra `buildHandoffSummary`.
✅ **Labels standard** — `POST /api/v1/.../labels {labels: [...]}`. Uso pra rotulação por intent.
✅ **`transfer_to_bot`** (#442) — pra reabrir bot depois. Já usado.
✅ **`analyze_now`** — pra push imediato de estado. Sem mudança.

## O que preciso do teu lado (NOVO ou verificar)

### 1. Move conversa entre inboxes (`kind='inbox'`) — provavelmente novo

**Caso de uso:** cliente pediu "quero receber por email" ou fluxo requer canal diferente (WABA → widget interno). Precisamos mover conv de uma inbox pra outra sem perder histórico.

**Pergunta:** Chatwoot upstream tem endpoint pra isso? Ou já customizamos? Precisa expor via API autenticada com bridge_secret.

**Se novo, sugestão:**
```
POST /api/webhooks/klaos/conversation/move-inbox
Headers: X-Bridge-Secret
Body: { account_id, conversation_id, target_inbox_id, note?: string }
```

### 2. Hot-swap `agent_bot_id` na conversa (`kind='agent_ai'`) — verificar API

**Caso de uso:** Lara detecta que o cliente quer agendar consulta. Em vez de mandar pro humano, transfere pro agente Sofia direto (Lara e Sofia são bots diferentes). O bot ativo da conv muda em runtime.

**Pergunta:** hoje o `agent_bot_id` da conv é imutável após criação? Chatwoot standard tem `POST /agent_bots/set_agent_bot` no nível inbox mas não por conversa.

**Sugestão custom:**
```
POST /api/webhooks/klaos/conversation/switch-bot
Headers: X-Bridge-Secret
Body: { account_id, conversation_id, target_agent_bot_id, handoff_context: {...} }
```
Efeito: atualiza `conversations.agent_bot_id` + emite evento `conversation_bot_switched` pro KLaOS notificar o novo agente com contexto.

Se não for viável agora, essa modalidade fica **fase 3** (roadmap KLaOS §7). Fase 1 e 2 rodam só com `team` e `agent`.

### 3. Botão "Handoff estava correto?" no drawer da conv — UI Frontdesk

**Caso de uso:** feedback humano vira dataset pra melhorar classifier.

**Sugestão UI:** ao resolver conv que veio de handoff (identificada por metadata `klaos_handoff_id`), mostrar botão/dropdown antes de fechar:
- Correto (intent + time OK)
- Time errado
- Intent errado
- Não deveria ter transferido

Emitir webhook `POST /api/webhooks/frontdesk/handoff-feedback` pra KLaOS gravar em `agent_handoff_events.human_feedback`.

Fase 4 do roadmap KLaOS. Não bloqueia início.

### 4. `conversation_updated` webhook rico (relacionado a #458 do KLaOS)

**Caso de uso:** KLaOS precisa saber quando a assignment muda (assignee_type/id) em tempo real. Hoje há drift entre `agent_conversations.assigned_to_user_id` (KLaOS) e o Chatwoot real.

**Pergunta:** o webhook `conversation_updated` já inclui `assignee.id` e `team.id` no payload? Se não, precisamos enriquecer.

Isso é blocante pra Fase 2 (política de anúncio depende de saber se humano assumiu). Se já emite, ok.

---

## Contratos de dados

### `buildHandoffSummary` — nota que vai virar Chatwoot private message

```
🤖 KLAOS HANDOFF

Intent detectada: <intent> (confidence <0.94>)
Também detectado: <secondary_intents>

📋 Contexto factual:
• Cliente ativo desde: DD/MM/YYYY
• Plano: <plan>
• Boletos vencidos: N (R$ X vencendo DD/MM)
• Último pagamento: DD/MM R$ X

💬 Últimos 3 turnos:
[HH:MM] cliente: "..."
[HH:MM] <agent>: "..."
[HH:MM] cliente: "..."

⚠️ Sinal de retenção / prioridade:
• <flags>

🎯 Ação sugerida: <template por intent>
```

Formato negociável — se atrapalha layout Chatwoot, ajusto. Formato Markdown é seguro?

### Labels aplicadas por intent (proposta)

Cada intent aplica labels no Chatwoot pra facilitar filtragem no time humano:

| Intent | Labels |
|---|---|
| `sales_new` | `prospect`, `sem-cadastro` |
| `sales_upgrade` | `upgrade`, `cliente-ativo` |
| `payment_dispute` | `contestacao`, `urgente-cobranca` |
| `contract_cancel` | `cancelamento-solicitado` |
| `service_booking` | `agendamento` |
| `complaint` | `reclamacao`, `urgente` |
| `human_request` | `pediu-humano` |

Labels que já existem no workspace continuam funcionando. Se conflita com auto-labels do Frontdesk, ping.

### Priority mapping (proposta)

`priority='urgent'` → Chatwoot `priority=urgent` (existe upstream). `high` → `high`. Não usar `low` ainda (pra evitar despriorização acidental).

---

## Timeline do KLaOS (referência pro Frontdesk)

- **Fase 1 (1 semana):** Schema + classifier + router + migrar 3 caminhos com `team` only. **Depende só do que já existe.**
- **Fase 2 (1 semana):** Contexto structured (nota Chatwoot) + política de anúncio. **Depende de #458 estar OK (assignee sync).**
- **Fase 3 (1-2 semanas):** `kind='agent'` (já OK), `kind='agent_ai'` (bot switch — **preciso de ti**), `kind='inbox'` (move inbox — **preciso de ti**).
- **Fase 4 (1 semana):** UI transferências no KLaOS + botão feedback no Frontdesk (**preciso de ti UI**).
- **Fase 5:** Refinamento contínuo.

**Ordem de dependência tua:**
1. **[Fase 2 blocante]** Confirmar `conversation_updated` inclui `assignee` + `team`. Se não, enriquecer.
2. **[Fase 3]** Endpoint `move-inbox` (se não tem upstream).
3. **[Fase 3]** Endpoint `switch-bot` custom (é criação).
4. **[Fase 4]** Botão feedback no drawer + webhook `handoff-feedback`.

---

## Riscos que te afetam

- **Volume classifier** — pra cada msg de user em conv com bot ativo, KLaOS vai classificar (com cache 60s por msg_hash). Não gera tráfego extra Frontdesk, mas se a política de anúncio precisar `getConversation` pra decidir, aumenta latência. Vou minimizar usando dados já em cache local.
- **Handoff loops** — regra dura: `agent_ai → agent_ai` proibido em cadeia. Se detectar loop, cai pra `team` default. Não deve nunca chegar em ti como loop, mas fica sinalizado.
- **Rate limit assign** — Chatwoot geralmente OK; se detectar 429 em burst, ping.

---

## Perguntas objetivas

1. **`conversation_updated` webhook** hoje inclui `assignee.id` e `team.id` no payload? Se não, quanto custa incluir?
2. **Move inbox** — existe endpoint upstream ou custom que aceite `target_inbox_id`? Ou preciso propor endpoint novo com o pattern de bridge_secret?
3. **Switch agent_bot** — viável tecnicamente por conv? Sei que `agent_bots` estão no nível inbox no Chatwoot, mas a conv aponta pra um `agent_bot_id` — dá pra atualizar em runtime?
4. **UI feedback** — timing pra fase 4 tá ok? Se preferir eu especifico o UI mais detalhado antes.

Responde inline neste doc (padrão nosso) ou abre um doc irmão `RESPOSTA_HANDOFF_ALIGNMENT.md` em `docs/para-klaos-agent/`. Vou monitorar.

**Do meu lado** já começo Fase 1 (schema + classifier + shadow mode) essa semana — não depende de ti. Sinalizo aqui quando tiver PR pra revisar.
