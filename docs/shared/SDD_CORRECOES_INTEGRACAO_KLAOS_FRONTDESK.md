# SDD v2 — Correções de integração KLaOS ↔ Frontdesk (Mais Saúde 24h)

| Campo | Valor |
|---|---|
| Status | **Draft — v2 com evidências Supabase KLaOS verificadas** |
| Prioridade | 🔴 Crítica |
| Autores | Frontdesk agent (investigação DB Chatwoot + Supabase KLaOS) |
| Data | 2026-04-24 |
| Dev Supabase KLaOS | `szkzkyexagunvadzzaec` |
| Workspace Mais Saúde | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` |
| Lara `agent_instance_id` | `1b092e03-9418-4352-956c-db0a560d904a` |

## Sumário executivo

Investigação com queries diretas no **Supabase do KLaOS** + **Postgres do Chatwoot** confirmou 14 bugs. Todas as hipóteses da v1 foram verificadas (ou refutadas) com dados reais.

### Dados-base da Lara em Mais Saúde (verificado no Supabase)

| Campo | Valor |
|---|---|
| Model | `gpt-5.2` |
| Temperature | 0.7 |
| max_tokens (config) | 2000 |
| max_tokens (observado em produção) | **4000** ⚠️ 2× maior que config |
| system_prompt (chars) | **40.620** (~10k tokens) |
| tokens_input médio por turno | 12.969 |
| tokens_input máximo | 21.600 |
| processing_time_ms médio | 7.158 |
| processing_time_ms máximo | **45.550** (45s — o meltdown) |
| Tools habilitadas | 6 (incluindo `transferir_para_time`) |
| `handoff_team_map` populado | ✅ contratos=8, cancelamento=6, cobranca=2, etc |

**Conclusão chave**: a config `max_tokens=2000` não está sendo respeitada pelo runtime (observado 4000). O prompt de 40k chars + histórico longo gera 20k+ tokens de input por turno → custo alto + latência + risco de loop.

---

## Legenda

| Sigla | Significado |
|---|---|
| **[KLaOS]** | Fix no repo/deploy do KLaOS |
| **[Frontdesk]** | Fix no fork Chatwoot (custom/ pattern) |
| **[Ambos]** | Coordenação cross-repo |
| **[Dados]** | Cleanup no banco |

🔴 Crítico · 🟠 Alto · 🟡 Médio · 🟢 Baixo

---

## Bug 1 — 🔴 [KLaOS] Tool `transferir_para_time` emitida como TEXTO, não invocada

### Evidência verificada (Supabase)

Conv `b88adaa6-18d2-4c65-bd2b-3f10b4364917` (desk 36), msg assistant 2026-04-23 19:15:26:
```
content: {"team_name":"contratos","reason":"cliente solicitou atendimento humano"}
Vou te transferir para o **setor de contratos**, gentileza aguardar.

tokens_input: 21.216
tokens_output: 56
processing_time_ms: 7.086
confidence_score: 0.85
model_used: gpt-5.2
metadata: {} (vazio — sem function_call registrado)
```

Depois desse turno, `agent_conversations.handoff_at` continuou **null**, `desk_conversation_id` sem team assignment. `handoff_team_map` tem `"contratos": 8` correto — mas o runtime nunca chegou a ler o map porque **a tool nunca foi invocada**.

Contagem sistêmica: **2 msgs com tool-call-as-text** + **1 com `namespace=functions` vazando** em 114 msgs assistant analisadas.

### Root cause (confirmado)
LLM `gpt-5.2` está emitindo o JSON da tool no `content` textual em vez de usar o canal `function_call` do protocolo. O runtime KLaOS não tem guardrail de detecção/recuperação: emite o content "cru" pro Chatwoot.

### Fix [KLaOS]
1. **Sniffer de pattern** antes de enviar ao Chatwoot:
   ```ts
   const TOOL_LEAK = /^\s*\{"(?:team_name|tool_name)"/;
   const NAMESPACE_LEAK = /namespace=functions|to=functions\./;
   if (TOOL_LEAK.test(content) || NAMESPACE_LEAK.test(content)) {
     // recovery path — ver Bug 2
     return executeToolRecovery(content, conversation);
   }
   ```
2. **Force tool_choice** quando detectar intent de handoff por keyword match (handoff_triggers.keywords já existe) ANTES de chamar o LLM:
   ```ts
   if (matchHandoffKeywords(userMsg)) {
     tool_choice = { type: 'function', name: 'transferir_para_time' };
   }
   ```
3. **Logar no `agent_audit_log`** cada leak pra medir tendência.

### Critério de sucesso
- [ ] 0 msgs assistant com `content LIKE '{"team_name%'` em 7 dias
- [ ] Conv teste "quero cancelar" → `handoff_at` preenchido + team_id Chatwoot=8 em <5s

---

## Bug 2 — 🔴 [KLaOS] Loop de tokens ignora `max_tokens` config e bate limite WhatsApp

### Evidência verificada

Msg assistant 2026-04-23 20:41:31 conv 36:
```
tokens_input: 21.600
tokens_output: 4.000  ← 2× o max_tokens configurado (2000)!
processing_time_ms: 45.550ms
confidence_score: 0.7 (baixo)
content (primeiros 150 chars): {"team_name":"contratos",...}namespace=functions.transferir_para_time<commentary 全民彩票天...
```

Content completo (no Chatwoot msg 10458) passou de 4096 chars → `external_error: "Param text.body must be at most 4096 characters long"`. Cliente não recebeu.

### Root cause
1. `agent_instances.max_tokens = 2000` mas runtime emitiu 4000 → **config não está sendo aplicada** no request ao OpenAI
2. Sem `frequency_penalty` / `presence_penalty` → modelo loopa quando perde contexto em prompts gigantes (20k input tokens)
3. Sem **stop sequences** pra markers internos
4. Sem **guard de tamanho** antes de enviar ao Chatwoot

### Fix [KLaOS]
1. **Auditar** o LLM client: por que max_tokens=2000 não foi respeitado? Config sobrescrita em runtime?
2. Configurar:
   ```ts
   frequency_penalty: 0.5
   presence_penalty: 0.3
   stop: ["namespace=", "to=functions.", "<commentary"]
   ```
3. **Hard guard no pipeline**:
   ```ts
   if (content.length > 3500) {
     logger.error('[LaraGuard] Output truncated — too long', { conversationId, len: content.length });
     await executeToolRecovery(content, conversation);
     return;
   }
   ```
4. **Reduzir o system prompt de 40.620 chars** — está redundante. Consolidar seções duplicadas; usar RAG pros blocos raramente usados (manual de produtos, exceções raras).

### Critério de sucesso
- [ ] 0 msgs assistant com `tokens_output >= 2500` (margem sobre config 2000)
- [ ] 0 msgs com `external_error` de tamanho WhatsApp em 7 dias
- [ ] system_prompt reduzido pra <15k chars (auditar o que está lá hoje)

---

## Bug 3 — 🟠 [KLaOS] Pensamento interno (thinking) vaza como mensagem ao cliente

### Evidência verificada

Msg assistant 2026-04-23 18:59:57 conv 36:
```
content: Não pode transferir sem quitação; pedir aguardar baixa e oferecer link.
No momento, conferi no nosso registro do CPF **454.501.218-30** e ainda consta...
```

A primeira linha é **instrução interna** (decisão de próximo passo). Foi enviada pro Gustavo no WhatsApp. Stats iniciais: 1 leak detectado por regex conservador em 114 msgs.

Adicional: 48 de 178 msgs no Chatwoot começam com `*Lara*:` — padrão de self-identifier que também parece artefato de prompt.

### Root cause
System prompt da Lara (40.620 chars) provavelmente instrui algo como: *"antes de responder, decida o próximo passo e escreva em uma linha"*. O LLM gera o plan + action tudo junto no content.

### Fix [KLaOS]
1. Extrair thinking pra formato delimitado:
   ```
   Regra: sua resposta deve ter formato:
   <planning>plano em 1 linha</planning>
   <reply>mensagem pro cliente</reply>
   ```
   E strip `<planning>...</planning>` no pipeline antes de enviar ao Chatwoot.

2. Ou melhor: migrar pro modo `thinking` nativo de modelos mais novos (Claude 3.7+, GPT-o1+) que separa thinking do output no protocolo, não no content.

3. Remover do prompt qualquer instrução de "raciocinar em voz alta antes da resposta".

### Critério de sucesso
- [ ] Regex de thinking leak (`^(Não pode|Pedir|Oferecer|Perguntar|Confirmar|Aguardar|Validar|Verificar)[^.]{10,80};`) retorna 0 matches em 7 dias

---

## Bug 4 — 🟠 [KLaOS] Resposta fragmentada em múltiplas mensagens por \n

### Evidência verificada

Msg assistant 2026-04-23 19:01:05 conv 36:
```
content: Vou te transferir para o setor de contratos gentileza aguardar.
Vou te transferir para o setor de contratos gentileza aguardar.
No nosso registro do C...
```

Na tabela `agent_messages` é 1 row com \n. No Chatwoot virou **3 msgs separadas** (10445, 10446, 10447). O pipeline KLaOS está splitando por \n.

### Root cause
Chunker do pipeline dividindo no `\n` simples. Sem agregação por semântica.

### Fix [KLaOS]
- Dividir apenas em `\n\n` (parágrafo, não linha) OU por tamanho fixo (>1000 chars)
- Garantir mínimo de X segundos entre submissões sequenciais ao Chatwoot (debounce)

### Critério de sucesso
- [ ] Ratio `agent_messages row` vs `Chatwoot bot msgs` ≈ 1:1 em janela de 24h

---

## Bug 5 — 🟠 [KLaOS] `handoff_at` preenchido mas `assigned_to_user_id` não sincroniza

### Evidência verificada

Conv `b88adaa6-...` (desk 36) após intervenção manual hoje:
```
status: waiting_human
handoff_at: 2026-04-24 01:55:55
handoff_reason: manual_recovery — meltdown anterior
assigned_to_user_id: null  ← deveria ser o user do atendente
```

Também convs antigas:
- Conv `234092a3-...` (desk 33, Daniel Limeira): `handoff_at` desde 2026-03-23 20:47, status=active, `assigned_to_user_id=null` — **1 mês stuck**
- Conv `fec46550-...` (desk 8): handoff 2026-03-23, status=active, `assigned_to_user_id=null`

### Root cause
O KLaOS grava `handoff_at` quando recebe sinal de handoff (webhook, tool call, ou manual) mas **não espelha** o assignee real do Chatwoot no `agent_conversations.assigned_to_user_id`. Fica desincronizado.

### Fix [KLaOS]
- Webhook `conversation_updated` do Chatwoot deveria atualizar `agent_conversations`:
  - `assigned_to_user_id` = KLaOS-user-uuid correspondente ao `conversation.assignee.id` do Chatwoot (mapear via tabela de lookup)
  - `status` adequado (active/waiting_human/resolved)
- Reconciliation job diário que varre convs com `handoff_at IS NOT NULL AND assigned_to_user_id IS NULL` e tenta re-sync via API do Chatwoot.

### Critério de sucesso
- [ ] Após handoff (qualquer origem), `assigned_to_user_id` populado em <10s
- [ ] Reconciliation limpa as convs stuck (33 e 8 por exemplo)

---

## Bug 6 — 🔴 [KLaOS] `/limpar` e fluxos admin deletam inboxes sem cascade

### Evidência
4 conversations órfãs em dev (inbox_id=22, inbox deletada). IDs: 32, 62, 63, 90.
KLaOS agent confirmou em `KLAOS_UPDATES.md` (hoje): `/limpar` só deleta 1 conv; os 4 outros fluxos admin (admin delete, reconcile, reset, waba unlink) não tinham cascade.

### Fix já aplicado
- **KLaOS**: commits `15b7979e` (dev) + `735611bb` (main) — `frontdeskAccountApi.deleteInbox` agora lista+deleta convs antes
- **Frontdesk**: `custom/config/initializers/conversation_orphan_guard.rb` (`can_reply?` null-safe)
- **Dados**: 4 órfãs deletadas em dev hoje

### Pendente
- [ ] QA: rodar fluxos admin novamente, verificar que não gera órfãs
- [ ] Manter o guard Frontdesk como defesa em profundidade

---

## Bug 7 — 🔴 [Frontdesk] `content_attributes` salvo como string JSON literal

### Evidência
311 rows na conta 10 Mais Saúde tinham:
```sql
content_attributes::text = '"{\"external_error\":\"...\"}"'  -- string, não hash
```

Causava crash no jbuilder: `ActionView::Template::Error (no implicit conversion of Hash into String)` → 500 no endpoint `/messages`.

### Fix aplicado
- SQL cleanup (311 rows normalizadas)
- **Pendente identificar o write path** que grava string em vez de Hash

### Pendente
- [ ] Caçar write path (provavelmente em adapters WhatsApp Cloud ou listener de delivery events)
- [ ] Prepend `Message` pra coagir string→Hash automaticamente
- [ ] Auditar prod (0 rows hoje, mas pode aparecer)

---

## Bug 8 — 🟡 [Frontdesk] Filtro "Ativas" ausente no modal de filtro avançado

### Fix aplicado
`components-next/filter/provider.js` — adicionado `'active'` ao array. Commit `e2f4155d9`.

### Pendente
- [ ] Deploy dev concluir (último build falhou mas containers antigos servem — não bloqueante)
- [ ] Teste manual: abrir advanced filter modal → "Ativas" aparece

---

## Bug 9 — 🟠 [KLaOS] Convs stuck com `handoff_reason="AI confidence too low"` sem assignee há semanas

### Evidência
```
conv desk=33 (Daniel Limeira): handoff_at=2026-03-23, status=active, assigned=null (31 dias stuck)
conv desk=8:                   handoff_at=2026-03-23, status=active, assigned=null (31 dias)
conv desk=31 (Daniel teste):   handoff_at=null,       status=active, 31 msgs, last_msg 2026-04-17
```

### Root cause
- `AI confidence too low` dispara handoff mas KLaOS não assigna ninguém
- Bug cruzado com Bug 5 (handoff_at sem assignee)
- Ninguém olha essas convs — invisíveis

### Fix [Ambos]
- **KLaOS**: implementar assignment real no handoff (ver Bug 5)
- **Frontdesk**: folder "Aguardando humano" pra admins enxergarem; notification ao workspace owner se stuck >24h

### Critério de sucesso
- [ ] 0 convs com `handoff_at >= 24h ago AND assigned_to_user_id IS NULL`

---

## Bug 10 — 🟡 [Ambos] Msgs `status=failed` ficam invisíveis pro atendente

### Evidência
15 msgs failed na conta 10:
- 7× "Required parameter is missing" (template)
- 4× "Number of parameters does not match"
- 4× "Template not found"
- 1× "Media upload error"
- 1× "User's number is part of an experiment"
- 1× 4096 chars (loop da Lara)

### Fix
- **Frontdesk**: UI mostrar indicador de falha em msgs com `external_error`
- **KLaOS**: validação pré-submit de templates (param count match); retry/fallback pra texto simples

### Critério de sucesso
- [ ] `msg.status='failed'` rate < 1% em 7 dias

---

## Bug 11 — 🟡 [KLaOS] 4 bugs de comportamento da Lara (parcialmente fixados)

Ver `KLAOS_UPDATES.md`. Status atual:
- ✅ Nome errado (Daniel vs cliente) — fixado
- ✅ Transferência prematura sem consultar débito — fixado
- ✅ `[STAGE:closing]` vazando — fixado
- ⬜ Falso "cadastro inativo" — fixado em dev system_prompt, precisa QA

### Pendente
- [ ] Davi roda suite QA completa (ver `docs/shared/PLANO_TESTES_AI_AGENTS.md`)

---

## Bug 12 — 🟡 [Ambos] Convs aguardando cliente não têm alerta/visibilidade

### Evidência
Conv desk 37 (Gustavo/Matheus): Lara pediu CPF 2026-04-23 22:37, cliente nunca respondeu. Fica `pending` indefinidamente. Só visível no filtro "Ativas".

### Fix
- **Frontdesk**: saved filter "Aguardando cliente" (pending + incoming >X min)
- **KLaOS**: `reactivation_at` + reminder opt-in (ver `SDD_REOPEN_POLICY.md`)

### Critério de sucesso
- [ ] Reminder automático após 24h sem resposta do cliente (opt-in workspace)

---

## Bug 13 — 🟢 [KLaOS] Prefixo `*Lara*:` hard-coded nas mensagens

### Evidência
48/178 msgs do bot começam com `*Lara*:`. WhatsApp já mostra nome do remetente — prefixo é redundante e feio.

### Fix
Remover auto-assinatura do system prompt. Usar `sender.available_name` do Chatwoot.

### Critério de sucesso
- [ ] 0% novas msgs com prefixo

---

## Bug 14 — 🟡 [KLaOS] Ausência de observability sobre tool success rate

### Evidência
Pra descobrir que Lara "fala mas não invoca", foi preciso SQL manual cruzando `agent_messages.content` com `agent_conversations.handoff_at`. Não há dashboard.

Métricas que deveriam existir mas não têm UI:
- Tool invocation attempted vs executed rate
- Tokens input/output P50/P95/P99
- processing_time_ms P99
- External error rate por tipo
- Conversas stuck com handoff há >X horas

### Fix [KLaOS]
Dashboard em `/klaos-control-panel/agents/:id/operations` com:
- Cards de métrica real-time
- Alertas via Slack/email quando thresholds estourados
- Tabela de convs stuck

### Critério de sucesso
- [ ] Dashboard acessível pro admin
- [ ] Alert dispara se tool-success-rate < 95% em 1h

---

## Matriz resumo — responsabilidades + impacto

| # | Bug | Resp | Severidade | Evidência | Status |
|---|---|---|---|---|---|
| 1 | Tool call como texto | KLaOS | 🔴 | 2 leaks em 114 msgs | Pendente |
| 2 | Loop tokens / 4000 out | KLaOS | 🔴 | 1 meltdown confirmado | Pendente |
| 3 | Thinking vaza | KLaOS | 🟠 | 1+ msgs com "Não pode transferir sem quitação" | Pendente |
| 4 | Fragmentação por \n | KLaOS | 🟠 | 3 msgs Chatwoot por 1 msg KLaOS | Pendente |
| 5 | handoff_at sem assignee | KLaOS | 🟠 | Convs 33, 8 stuck 31 dias | Pendente |
| 6 | /limpar cascade | KLaOS | 🔴 | 4 órfãs dev | ✅ Fix merged (15b7979e) |
| 7 | content_attributes string | Frontdesk | 🔴 | 311 rows normalizadas | ✅ Dados; 🔲 write path |
| 8 | Filtro Ativas modal | Frontdesk | 🟡 | provider.js:92 | ✅ Commit e2f4155d9 |
| 9 | Handoff sem assignee | Ambos | 🟠 | Conv 33 stuck 31 dias | Pendente |
| 10 | Failed invisível | Ambos | 🟡 | 15 msgs failed | Pendente |
| 11 | Comportamento Lara | KLaOS | 🟡 | Parcial | 3/4 ✅; 🔲 QA |
| 12 | Cliente esperando | Ambos | 🟡 | Conv 37 stuck | Pendente |
| 13 | Prefixo Lara | KLaOS | 🟢 | 48/178 msgs | Pendente |
| 14 | Observability | KLaOS | 🟡 | SQL manual obrigatório | Pendente |

## Priorização

**Semana 1** (críticos + desbloqueadores):
- Bug 1, 2 (KLaOS) — tool execution + loop
- Bug 7 write path (Frontdesk) — identificar origem
- Bug 6 QA (KLaOS) — validar fix /limpar em staging

**Semana 2** (robustez):
- Bugs 3, 4, 5 (KLaOS) — thinking, fragmentação, assignee sync
- Bug 10 retry (Ambos)

**Semana 3** (UX/obs):
- Bug 9 folder + alertas (Frontdesk)
- Bug 12 reminder (KLaOS)
- Bug 14 dashboard (KLaOS)
- Bug 11 QA completo (KLaOS)
- Bug 13 prefixo (KLaOS)

---

## Bugs novos descobertos no Supabase que NÃO estavam na v1

Comparando com v1 deste doc, as queries direto no Supabase revelaram:

1. **Max_tokens=2000 config ignorado** — runtime emitiu 4000 tokens (Bug 2, novo fato)
2. **system_prompt de 40.620 chars** — raiz provável de loops e latência (Bug 2, 3)
3. **tokens_input médio 12.969** — custo financeiro significativo (Bug 2)
4. **Model = `gpt-5.2`** (OpenAI, released 2025-12-11). Já existe gpt-5.3 (fev/26), 5.4 (mar/26), 5.5 (abr/26 — hoje). Upgrade pode trazer melhorias em instruction-following e reasoning, reduzindo Bugs 1-4. Avaliar custo/benefício.
5. **Convs stuck desde março** com handoff sem assignee (Bug 5, 9 — antes era hipótese, agora é fato)
6. **handoff_team_map já populado** corretamente — refuta hipótese de que o problema era o mapa; confirma que é só a tool não executar (Bug 1)

## Referências

- `SDD_HANDOFF_TOOL_INVOCATION.md`, `SDD_HANDOFF_ROUTING.md`, `SDD_REOPEN_POLICY.md`
- `BUG_LIMPAR_INBOX_DELETION.md`, `BUG_LARA_TOKEN_LOOP.md`
- `docs/para-frontdesk-agent/KLAOS_UPDATES.md`

## Meta

SDD v2 substitui o v1 com evidência real do Supabase KLaOS. Pode ser arquivado quando todos os 🔴/🟠 estiverem fechados.
