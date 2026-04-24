# SDD — Correções de integração KLaOS ↔ Frontdesk (Mais Saúde 24h)

| Campo | Valor |
|---|---|
| Status | **Draft — aguarda divisão de issues e implementação** |
| Prioridade | 🔴 Crítica (impacta atendimento real em dev e pode ir pra prod) |
| Autores | Frontdesk agent (investigação + workarounds), com contribuição do KLaOS agent (pendente de revisão) |
| Data | 2026-04-24 |
| Contexto | Sessão de investigação de 2026-04-23 em Mais Saúde DEV: filtro "Ativas" quebrado, Lara silenciosa, conversas stuck, tool calls vazando |

## Sumário executivo

Investigamos o fluxo completo Chatwoot (Frontdesk) ↔ KLaOS (AI Agents) em dev e encontramos **14 bugs distintos** afetando o atendimento real. A maioria é de responsabilidade do **KLaOS** (runtime do LLM, pipeline de mensagens, comandos admin), com 3 bugs de **Frontdesk** (null-safety, filtro avançado, content_attributes).

Impacto observado em Mais Saúde DEV:
- **Conv 36** (Gustavo cliente): Lara "tentou transferir" **5 vezes** em texto, 0 vezes de verdade — cliente ficou esperando, só desbloqueado com intervenção humana manual hoje
- **15 mensagens** rejeitadas pelo WhatsApp Meta (templates/params errados ou >4096 chars), **invisíveis** pro atendente
- **311 mensagens** com `content_attributes` salvos como string JSON literal (quebra render do jbuilder → 500)
- **4 conversas órfãs** com `inbox_id` apontando pra inbox deletada
- **Vazamento** de tool calls, prefixos `*Lara*:` e raciocínio interno do LLM como mensagem ao cliente

Este SDD lista cada bug com responsável, fix recomendado e critério de sucesso.

---

## Legenda de responsáveis

| Sigla | Significado |
|---|---|
| **[KLaOS]** | Fix no agente KLaOS (runtime LLM, pipeline, comandos admin) |
| **[Frontdesk]** | Fix no fork Chatwoot (custom/ pattern preferencialmente) |
| **[Ambos]** | Requer coordenação cross-repo |
| **[Dados]** | Cleanup no banco Postgres do Chatwoot |

## Legenda de severidade

🔴 Crítico — quebra fluxo principal | 🟠 Alto — degrada UX ou perde mensagens | 🟡 Médio — tem workaround | 🟢 Baixo — cosmético

---

## Bug 1 — 🔴 [KLaOS] Tool `transferir_para_time` vaza como texto JSON

### Evidência
Conv 161 (Mais Saúde dev), msg 10452:
```
*Lara*:
{"team_name":"contratos","reason":"cliente solicitou atendimento humano"}
```

Depois dessa "tool call", a conv continuou `status=pending`, `team_id=null`, `assignee_id=null`. Handoff não aconteceu. Lara repetiu 5x no mesmo thread. Cliente ficou preso.

### Root cause
LLM gera chamada da tool `transferir_para_time` em formato OpenAI (`to=functions.transferir_para_time` ou `namespace=functions.`), mas o runtime KLaOS está **emitindo o output como texto** em vez de detectar e **invocar** a tool. Ver `SDD_HANDOFF_TOOL_INVOCATION.md` que já previa isso — não foi implementado ainda.

### Fix
- Implementar o guardrail descrito em `SDD_HANDOFF_TOOL_INVOCATION.md` §Parte 2
- Detectar pattern `{"team_name"` ou `namespace=functions` no stream antes de commit da msg
- Forçar execução real da tool (resolveTeamId + assignTeam + postPrivateNote)
- Remover o texto do JSON antes de enviar ao cliente

### Critério de sucesso
- [ ] Teste manual: "quero cancelar" → Lara chama tool real → `team_id != null` no DB em <5s
- [ ] Dashboard: 0 tool-call-as-text em janela de 24h

---

## Bug 2 — 🔴 [KLaOS] Lara entra em loop de tokens e estoura limite do WhatsApp

### Evidência
Msg 10458 conv 161: conteúdo de **4.096+ caracteres** com repetição em múltiplos idiomas (chinês, tailandês, russo) misturando `to=functions.transferir_para_time` e JSON fragmentado. Meta retornou:
```json
"external_error": "Param text.body must be at most 4096 characters long."
```

Mensagem ficou com `status=failed`, cliente **não recebeu** nada. Do ponto de vista dele: Lara parou.

### Root cause
Combinação de:
- Sem `frequency_penalty` / `presence_penalty` no LLM client → modelo loopa
- Sem **stop sequences** configuradas pra markers internos (`namespace=`, `to=functions.`)
- Sem **guard de tamanho** no pipeline KLaOS antes de submeter ao Chatwoot

### Fix
Ver `BUG_LARA_TOKEN_LOOP.md`. Resumo:
1. Guard de tamanho (>4000 chars → substitui por msg padrão + força tool exec)
2. Guard de padrão (`namespace=functions` no texto → loop detectado → recovery)
3. `frequency_penalty: 0.5`, `presence_penalty: 0.3` no LLM client
4. Stop sequences: `["namespace=", "to=functions."]`
5. Revisar system prompt da Lara (ver Bug 4)

### Critério de sucesso
- [ ] 0 mensagens do bot com `content_length > 4000` em janela de 7 dias
- [ ] 0 mensagens com `status=failed` por `external_error` de tamanho

---

## Bug 3 — 🟠 [KLaOS] Pensamento interno do LLM vaza como mensagem ao cliente

### Evidência
Msg 10442 conv 161:
```
*Lara*:
Não pode transferir sem quitação; pedir aguardar baixa e oferecer link.
No momento, conferi no nosso registro do CPF...
```

A primeira linha é **instrução interna** (algo como decisão de raciocínio/chain-of-thought) — NÃO deveria ir pro cliente. Padrão: 48 de 178 msgs (27%) do bot começam com `*Lara*:` e a linha seguinte é "meta-texto" de decisão antes da resposta real.

### Root cause
System prompt da Lara provavelmente instrui: *"antes de responder, pense em voz alta o que você vai fazer"* — o LLM gera o pensamento + resposta num único turno, e o pipeline do KLaOS **emite ambos** como mensagem visível.

### Fix
- Revisar system prompt: tirar qualquer instrução de "pensar em voz alta" antes da resposta
- Se for necessário raciocínio estruturado, usar formato delimitado (ex: `<thinking>...</thinking>` ou `scratchpad:`) e **filtrar** no pipeline antes de enviar ao Chatwoot
- Alternativa: usar API `thinking` do Claude 3.7+/4.x (que separa thinking de response output nativamente)

### Critério de sucesso
- [ ] 0 mensagens do bot começando com `*Lara*:` no formato atual
- [ ] Teste: conversa com intent de handoff → cliente recebe mensagem limpa, sem meta-texto

---

## Bug 4 — 🟠 [KLaOS] Lara fragmenta resposta em múltiplas mensagens sem lógica clara

### Evidência
Padrão observado em conv 161:
```
10439 (bot): *Lara*: Conferi no nosso registro do CPF **454.501.218-30**...
10440 (bot): Se você **já pagou agora**, me confirma se foi por esse link?
10441 (contact): foi sim, agora pode me transferir por favor?
10442 (bot): *Lara*: Não pode transferir sem quitação; pedir aguardar baixa...
10443 (bot): Se você pagou **agora** por esse mesmo link, pode ser que ainda esteja...
```

O turno do bot é sempre 2 msgs. A primeira com `*Lara*:` (thinking/decisão), a segunda com ação. Pro cliente fica:
- Notificação #1: "*Lara*:..."
- Notificação #2: "Se você..."

### Root cause
O chunker/splitter do KLaOS está detectando quebra de linha ou marcador interno e criando múltiplas requisições `POST /conversations/:id/messages`.

### Fix
- Agregar pensamento + resposta numa **única** mensagem outgoing
- Se a resposta for muito longa, dividir por parágrafos ou frases completas — nunca por marcadores LLM
- Considerar limite de tamanho por msg (ex: 1000 chars) e dividir apenas se exceder

### Critério de sucesso
- [ ] Ratio bot msgs / client msgs = ~1:1 em conversas normais (sem intent múltiplo)
- [ ] Nunca duas msgs do bot em <1 segundo

---

## Bug 5 — 🟠 [KLaOS] `/limpar` e fluxos admin deletam inboxes sem cascade de conversations

### Evidência
- 4 conversas órfãs encontradas em dev (inbox_id=22, inbox que não existe mais)
- IDs afetados: 32, 62, 63, 90
- Mensagens órfãs = 0 (destroy_async pegou parte, mas não as conversas)

### Root cause
KLaOS agent confirmou em `KLAOS_UPDATES.md`: o `/limpar` deleta 1 conversation apenas, mas os outros 4 fluxos admin (admin delete, reconcile, reset, waba unlink) chamam `deleteInbox` direto sem cascade.

### Fix (KLaOS)
Commits `15b7979e` (dev) + `735611bb` (main) já aplicados:
- `frontdeskAccountApi.deleteInbox` lista e deleta conversations antes do DELETE

### Fix (Frontdesk — workaround)
`custom/config/initializers/conversation_orphan_guard.rb` (commit `0992446b8`):
- `Conversation#can_reply?` retorna false se inbox é nil → evita 500 no jbuilder

### Cleanup (Dados)
4 órfãs deletadas em dev hoje. Prod auditado (0 órfãs).

### Critério de sucesso
- [x] Cleanup dev completo (2026-04-23)
- [x] Workaround Frontdesk deployado (`0992446b8` em dev)
- [ ] Fix KLaOS merged e verificado: rodar `/limpar` novamente → sem gerar órfãs
- [ ] Manter workaround Frontdesk como defesa em profundidade (NÃO remover)

---

## Bug 6 — 🟠 [Frontdesk] `content_attributes` armazenado como string JSON literal

### Evidência
311 mensagens na conta 10 Mais Saúde com formato:
```sql
content_attributes::text = '"{\"external_error\":\"Template not found...\"}"'
```

Ou seja: coluna `json` mas valor é uma **string** contendo JSON (dupla serialização).

Consequência: `GET /api/v1/accounts/10/conversations/:id/messages` retorna 500 com `ActionView::Template::Error (no implicit conversion of Hash into String)` no jbuilder.

### Root cause
Alguma parte do código do Chatwoot (provavelmente adapter do WhatsApp Cloud em `app/builders/messages/whatsapp/...` ou similar) grava `external_error` via `update_column` passando **string pré-serializada** em vez de Hash. Rails não tem oportunidade de aplicar o store+coder JSON.

Candidato específico a investigar: `lib/integrations/responses/message_builder.rb`, `app/models/concerns/whatsapp_send.rb` ou callbacks de delivery em `app/listeners/whatsapp_events_listener.rb`.

### Fix (curto prazo — Dados)
SQL cleanup aplicado em 2026-04-23:
```sql
UPDATE messages SET content_attributes = (content_attributes #>> '{}')::json
WHERE content_attributes::text LIKE '"%';
```
311 rows normalizadas.

### Fix (estrutural — Frontdesk)
Caçar o write path que salva string em vez de Hash e corrigir. Pode ser patch em `custom/` se o código vier de gem/upstream.

### Fix complementar (Frontdesk)
Adicionar validator no Message model:
```ruby
# custom/config/initializers/message_content_attributes_guard.rb
module KlaosMessageContentAttributesGuard
  def content_attributes=(value)
    if value.is_a?(String)
      parsed = JSON.parse(value) rescue nil
      value = parsed if parsed.is_a?(Hash)
    end
    super(value)
  end
end
Rails.application.config.to_prepare do
  Message.prepend(KlaosMessageContentAttributesGuard) unless Message.include?(KlaosMessageContentAttributesGuard)
end
```

### Critério de sucesso
- [x] Cleanup dev (311 rows)
- [ ] Auditoria prod (se tiver rows com mesmo pattern)
- [ ] Write path identificado e patched
- [ ] Guard preventivo aplicado

---

## Bug 7 — 🟠 [Frontdesk] `Conversation#can_reply?` explode com inbox nil

### Evidência
Ver Bug 5. Stack trace:
```
ActionView::Template::Error (undefined method 'channel_type' for nil):
app/services/conversations/message_window_service.rb:18
app/models/conversation.rb:128
```

### Fix
Workaround aplicado — `custom/config/initializers/conversation_orphan_guard.rb` (commit `0992446b8`).

### Critério de sucesso
- [x] Guard ativa em dev+prod (aguardando deploy concluir)

---

## Bug 8 — 🟡 [Frontdesk] Filtro "Ativas" não aparece no custom filter modal

### Evidência
`components-next/filter/provider.js:92` tinha array hardcoded `['open', 'resolved', 'pending', 'snoozed', 'all']`. Advanced filter modal (funnel icon) não expõe "Ativas".

### Fix
Commit `e2f4155d9` — adicionado `'active'` ao array.

### Critério de sucesso
- [x] Deploy do commit `e2f4155d9` em dev (pendente — build falhou uma vez)
- [ ] Teste manual: abrir modal → Ativas aparece

---

## Bug 9 — 🟠 [KLaOS] Pipeline Frontdesk webhook recebe 200 OK mas KLaOS não gera resposta em conversas específicas

### Evidência
Conv 158 (Mais Saúde dev, histórico anterior) e conv 161 pós-deleção 151: guard log do Frontdesk mostra todas as mensagens do cliente despachadas com 200 OK no tempo < 200ms, mas **Lara não responde**. Intervenção manual via `curl POST webhook` dispara a resposta.

Presumido: KLaOS tem cache/dedupe de `conversation_id` que considera a conv "já processada" e skipa o buffer processor.

### Root cause (hipótese)
`agentBufferProcessor.service.ts` no KLaOS tem dedup cache keyed por `conversation_id` — quando a conv original é deletada no Chatwoot e recriada com novo `id` mas mesmo `display_id` ou `contact_id`, cache não invalida.

### Fix (KLaOS)
- Keyed cache deveria incluir `chatwoot_conversation_id + latest_message_id` em vez de só `conversation_id`
- TTL adequado (ex: 1h) e invalidação explícita em deletes

### Critério de sucesso
- [ ] Teste reprodutor: deletar conv X no Chatwoot, contato remanda msg, Lara responde em <10s
- [ ] Métrica: taxa de webhook-received → bot-replied > 99% em janela de 24h

---

## Bug 10 — 🟡 [Ambos] Mensagens com `status=failed` ficam invisíveis pro atendente

### Evidência
15 mensagens em status=failed na conta 10. Atendente humano abrindo a conversa não vê indicador claro de que mensagens do bot foram rejeitadas pelo WhatsApp.

Erros encontrados:
- 7× "(#131008) Required parameter is missing" — template mal formatado
- 4× "(#132000) Number of parameters does not match" — params template errados
- 4× "Template not found or invalid template name"
- 1× "131053: Media upload error"
- 1× "130472: User's number is part of an experiment"
- 1× "4096 chars" (loop da Lara)

### Fix (Frontdesk)
Na UI da conversa, mostrar badge/warning em msgs com `status=failed` + `content_attributes.external_error`. Já existe parcialmente mas pode ser melhorado.

### Fix (KLaOS)
- **Retry policy**: quando Meta rejeita por template ausente/params errados, logar e fallback pra mensagem de texto simples
- **Validation pré-submit**: validar template_name + param_count antes de mandar ao Chatwoot
- **Alerta operacional** quando rate de `failed` passa de X% em Y min

### Critério de sucesso
- [ ] UI mostra indicador visual em msg failed
- [ ] Rate failed / total bot msgs < 1% em 7 dias

---

## Bug 11 — 🟡 [KLaOS] 4 bugs de comportamento da Lara (já parcialmente fixados)

Ver `KLAOS_UPDATES.md` seção "2026-04-23 — Fix 3 bugs de comportamento da Lara". Status:
- ✅ Nome "Daniel" em vez de cliente real — fixado
- ✅ Transferência prematura sem consultar débito — fixado
- ✅ Metadata `[STAGE:closing]` vazando — fixado
- ⬜ Falso "cadastro inativo" — corrigido no system_prompt da Lara em dev, mas precisa testar com cenários

### Critério de sucesso
- [ ] QA (Davi) roda suite de testes cobrindo os 4 cenários
- [ ] Spot-check em 10 conversas reais após deploy

---

## Bug 12 — 🟡 [Frontdesk] Conversas stuck (pending sem team/assignee) não têm visibilidade

### Evidência
Conv 162 (Gustavo "Quero cancelar"): cliente pediu cancelamento, Lara pediu CPF, cliente **nunca respondeu**. Conv ficou `pending`, `team=null`, `assignee=null`. Só aparece no filtro "Ativas" (novo) ou "Pendentes".

Sem algum indicador/alerta, atendente não sabe que tem cliente esperando.

### Fix (Frontdesk)
- Adicionar view/saved filter "Aguardando cliente" (pending + incoming há mais de X min)
- Alerta no Dashboard do Frontdesk se conv fica pending >24h sem progresso

### Fix (KLaOS)
- Conversas que ficam pending sem resposta do cliente por X tempo deveriam:
  - Marcar `reactivation_at` (ver `SDD_REOPEN_POLICY.md`)
  - Enviar reminder auto após 24h ("oi, ainda precisa de ajuda?")

### Critério de sucesso
- [ ] Filtro/alerta visível no sidebar do Frontdesk
- [ ] Reminder automático com opt-in por workspace

---

## Bug 13 — 🟢 [Ambos] Prefixo `*Lara*:` hard-coded nas mensagens do bot

### Evidência
48 de 178 msgs do bot começam com `*Lara*:` ou `*Lara*:\n`.

### Root cause
Lara assina mensagens com o próprio nome no system prompt.

### Fix (KLaOS)
- Remover auto-assinatura do system prompt — WhatsApp já mostra nome do remetente (inbox)
- Se necessário, usar `sender.available_name` no Chatwoot em vez de vazar no `content`

### Critério de sucesso
- [ ] 0% das novas msgs com prefixo

---

## Bug 14 — 🟡 [KLaOS] Ausência de métrica end-to-end de tool call success rate

### Evidência
Descobrir que Lara "fala transferir" mas não executa tool requer análise manual SQL em `additional_attributes.agent_bot_guard_log` vs `team_id`. Não há dashboard operacional.

### Fix (KLaOS)
Dashboard com:
- Tool invocation rate (tentativas vs execuções reais)
- Per-tool success rate
- Tempo médio de resposta do bot
- % mensagens rejeitadas pelo Meta
- % conversas que terminam em handoff humano vs auto-resolve

### Critério de sucesso
- [ ] Dashboard interno acessível via `/klaos-control-panel`
- [ ] Alertas se tool success rate < 95%

---

## Priorização (ordem sugerida de execução)

### Semana 1 — Desbloquear atendimento
1. **Bug 1** (KLaOS) — tool call real executar
2. **Bug 2** (KLaOS) — guard de tamanho + loop
3. **Bug 9** (KLaOS) — cache/dedupe do buffer processor
4. **Bug 6** (Frontdesk) — identificar e patchar write path do content_attributes

### Semana 2 — Robustez
5. **Bug 3** (KLaOS) — pensamento interno não vazar
6. **Bug 4** (KLaOS) — fragmentação de mensagens
7. **Bug 10** (Ambos) — retry + UI failed indicator

### Semana 3 — UX / observability
8. **Bug 12** (Ambos) — view stuck conversations + reminder
9. **Bug 14** (KLaOS) — dashboard operacional
10. **Bug 11** (KLaOS) — QA full do system prompt da Lara
11. **Bug 13** (KLaOS) — remover prefixo Lara

### Manter como safety net
- Bug 5 (KLaOS fixou, Frontdesk guard fica)
- Bug 7 (Frontdesk guard fica)
- Bug 8 (Frontdesk — deploy quando concluir)

---

## Referências cruzadas

- `SDD_HANDOFF_TOOL_INVOCATION.md` — detalhe do Bug 1
- `SDD_HANDOFF_ROUTING.md` — dependência do Bug 1 (mapa `team_name → team_id`)
- `SDD_REOPEN_POLICY.md` — dependência do Bug 12
- `BUG_LIMPAR_INBOX_DELETION.md` — detalhe do Bug 5
- `BUG_LARA_TOKEN_LOOP.md` — detalhe do Bug 2
- `docs/para-frontdesk-agent/KLAOS_UPDATES.md` — log das mudanças KLaOS

## Meta do documento

Este SDD consolida **evidências de DB** coletadas em 2026-04-23/24 em dev Mais Saúde. Cada bug tem repro identificado, responsável claro e critério de sucesso mensurável.

Ao fechar cada bug, atualizar aqui com commit/PR. Quando todos os 🔴 e 🟠 estiverem fechados, este SDD pode ser arquivado.
