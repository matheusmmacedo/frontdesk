# Plano de Testes — Integração (KLaOS CRM ↔ AI Agents ↔ Frontdesk)

| Campo | Valor |
|---|---|
| Versão | 1.0 |
| Data | 2026-04-22 |
| Responsável QA | Davi Felix |
| Autor do plano | Matheus Macedo |
| Produto | Jornadas end-to-end cruzando KLaOS CRM, AI Agents e Frontdesk |
| Ambiente principal | Dev (todos os 3 sistemas em `app-*-dev.klaos.ai`) + Prod |
| Workspace de referência | Mais Saúde 24h |

---

## 1. Escopo

### 1.1 Incluído
Este doc cobre **jornadas ponta-a-ponta** onde 2 ou 3 dos sistemas KLaOS trabalham juntos. Tipicamente onde bugs de fronteira aparecem.

### 1.2 Por que esse doc existe separado
Cada plano individual (CRM/Frontdesk/AI Agents) testa sua área isoladamente. Mas muitos bugs de produção são **entre** sistemas:
- Bot responde mas áudio não chega (AI → Frontdesk → Meta)
- CRM atualiza deal mas Frontdesk não mostra (CRM → Frontdesk)
- Handoff é detectado mas conversa não sai de pending (AI → Frontdesk)
- Usuário criado no KLaOS mas não aparece no Frontdesk (KLaOS → Frontdesk)

Se não houver doc dedicado, essa camada fica sem dono.

### 1.3 Fora de escopo
- Funcionalidades internas de um único sistema (ver planos específicos).
- Testes de carga.

---

## 2. Mapa de integrações (referência)

```
                    ┌──────────────┐
                    │   KLaOS UI   │
                    │  (admin/SDR) │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌──────────┐  ┌──────────┐
        │   CRM   │  │AI Agents │  │ Frontdesk│
        └────┬────┘  └─────┬────┘  └─────┬────┘
             │             │             │
             │             │ [webhook]   │
             │             ├────────────►│ (cliente envia msg)
             │             │             │
             │  [tool call]│             │
             ├────────────►│             │
             │             │ [post msg]  │
             │             ├────────────►│
             │             │             │
             │  [bridge]   │             │
             ├─────────────┴────────────►│ (push deal data)
             │                           │
             │          [provisiona]     │
             └──────────────────────────►│ (cria user/bot)
                                         │
                                  ┌──────▼──────┐
                                  │Cliente final│
                                  │ WhatsApp/Web│
                                  └─────────────┘
```

**Fluxos principais a testar**:
1. **Provisionamento**: KLaOS cria user/agent/workspace → Frontdesk recebe e cria recursos espelhados
2. **Conversa com bot**: Cliente WA → Frontdesk → webhook → AI Agent → resposta → Frontdesk → cliente
3. **Enriquecimento de deal**: CRM atualiza → CRM Bridge → Frontdesk custom_attributes
4. **Consulta pelo bot**: AI Agent tool call → CRM → resposta
5. **Handoff**: AI detecta → PATCH Frontdesk (status + assignee) → humano notificado
6. **Agendamento**: CRM agenda closer → CRM Bridge → Frontdesk mostra na sidebar

---

## 3. Perspectivas cruzadas

Cada jornada envolve múltiplas personas:

| Jornada | Personas | Sistemas envolvidos |
|---|---|---|
| Onboarding agente | Admin KLaOS → Agente Frontdesk | KLaOS + Frontdesk |
| Cliente fala com bot | Cliente → Bot → Agente humano (se handoff) | AI + Frontdesk + (Meta/Evolution) |
| SDR qualifica lead | SDR → Lead → Deal → Conversa WA | CRM + Frontdesk |
| Bot consulta dívida | Cliente → Bot → CRM → Resposta | AI + CRM |
| Closer agenda reunião | SDR/Closer → Agendamento → Cliente confirma | CRM + Google Calendar + Frontdesk |

---

## 4. Formato dos TCs e prioridades
(Mesmo padrão dos outros planos.)

---

## 5. Critérios de saída
- **100% dos TCs Críticos de jornada end-to-end executados com Pass.**
- Bugs identificados categorizados por sistema responsável (CRM / AI / Frontdesk / fronteira).
- Sign-off.

---

## 6. Jornadas

### 6.1 Jornada: Provisionamento completo de usuário (KLaOS → Frontdesk)

> Já coberto parcialmente no plano Frontdesk §5.1. Aqui expandimos a dimensão **integração** com foco em sincronia, idempotência, rollback.

#### 6.1.1 User Story de fluxo
> Admin cria Davi como agente da Mais Saúde no KLaOS. Em menos de 30s ele consegue logar no Frontdesk, vê as inboxes certas, e KLaOS persistiu o `chatwoot_user_id` de volta na `frontdesk_users`.

#### 6.1.2 Critérios end-to-end

- **AC-1.1**: Provisão: create no KLaOS → user visível no Frontdesk em <30s.
- **AC-1.2**: KLaOS persiste `chatwoot_user_id` de volta após resposta da API.
- **AC-1.3**: Update no KLaOS (ex: mudar role) reflete no Frontdesk sem duplicar.
- **AC-1.4**: Delete no KLaOS remove access no Frontdesk (access_token revogado).
- **AC-1.5**: Retry de provisionamento após falha transiente não duplica.

#### 6.1.3 TCs

| ID | Título | Prioridade | Sistemas |
|---|---|---|---|
| TC-701 | Fluxo feliz: criar user → aparece → loga | Crítica | KLaOS + Frontdesk |
| TC-702 | Update de role propaga | Alta | KLaOS + Frontdesk |
| TC-703 | Delete revoga access | Crítica | KLaOS + Frontdesk |
| TC-704 | Retry não duplica (simular timeout) | Alta | KLaOS + Frontdesk |
| TC-705 | Usuário Gustavo: criar via caminho errado — detectar | Média | Integração |

##### TC-701 — Fluxo feliz completo

**Pré-condição**: Davi tem email novo disponível; admin logado nos 2 sistemas.

**Passos**:
1. KLaOS admin UI: criar user "QA Teste" com email do Davi
2. Em outra aba, abrir Frontdesk como Matheus admin Mais Saúde
3. Ir em Configurações → Agentes, buscar pelo email
4. Confirmar aparição em <30s
5. Davi recebe convite por email, define senha
6. Davi loga em janela anônima no Frontdesk
7. Confirma dashboard, menu correto, conversas visíveis

**Resultado esperado**: sem SQL, sem intervenção manual, tudo via UI. Em cada passo sem erro visível.

---

### 6.2 Jornada: Provisionamento de bot (KLaOS AI Agent → Frontdesk)

#### 6.2.1 User Story
> Admin cria um agente "QA Klaus" no KLaOS com tools ativadas. Em <30s o bot aparece como opção pra vincular numa inbox no Frontdesk. Admin da Mais Saúde vincula à inbox KLaOS Cobrança. Bot começa a responder quando cliente manda WA pra aquele número.

#### 6.2.2 Critérios

- **AC-2.1**: Agente criado no KLaOS → bot aparece no seletor de inbox no Frontdesk <30s.
- **AC-2.2**: Nome segue convenção `<name> | <slug>` evitando ambiguidade.
- **AC-2.3**: `outgoing_url` correto no agent_bot aponta pro webhook do KLaOS com UUID do agent_instance.
- **AC-2.4**: `access_token` do bot armazenado corretamente no KLaOS pra posting reverso.
- **AC-2.5**: Cliente WA → mensagem flui: Frontdesk → webhook KLaOS → agent responde → POST volta pro Frontdesk.
- **AC-2.6**: Bot reponde com `sender_id` correto (do access_token certo, não de outro bot).
- **AC-2.7**: Alterar nome no KLaOS propaga ao Frontdesk.
- **AC-2.8**: Deletar agente no KLaOS remove bot do Frontdesk.

#### 6.2.3 TCs

| ID | Título | Prioridade | Sistemas |
|---|---|---|---|
| TC-710 | Criar agent Klaus → aparece no Frontdesk | Crítica | KLaOS+FD |
| TC-711 | Vincular a inbox e mandar msg teste | Crítica | KLaOS+FD+WA |
| TC-712 | Bot responde com `sender_id` correto (fix 2026-04-21) | **Crítica** | KLaOS+FD |
| TC-713 | Rename KLaOS reflete nome no Frontdesk | Alta | KLaOS+FD |
| TC-714 | Delete KLaOS remove bot FD | Alta | KLaOS+FD |
| TC-715 | Bot com outgoing_url antigo (órfão) é detectado | Média | Integração |

##### TC-712 — Bot responde com `sender_id` correto

**Motivação**: em 2026-04-21, o KLaOS atualizou `frontdesk_chatwoot_bot_id` mas esqueceu de atualizar `frontdesk_chatwoot_bot_access_token`. Resultado: Klaus Ross respondeu usando access_token do Klaus, e todas as mensagens apareciam como se fossem do Klaus (sender_id errado no Chatwoot).

**Passos**:
1. No Frontdesk, inbox `klaos.ai` vinculada ao bot Klaus Ross
2. Cliente final manda mensagem na inbox
3. Bot responde
4. Davi abre a conversa no Frontdesk
5. Olha o "avatar/nome" do bot que respondeu

**Resultado esperado**:
- Nome mostrado é **"Klaus Ross | klaus-ross"** (ou equivalente), **não** "Klaus | klaus-gmt90d"
- Hover no avatar mostra info do bot Klaus Ross

---

### 6.3 Jornada: Conversa completa com bot (cliente → bot → Frontdesk)

#### 6.3.1 User Story
> Cliente manda WhatsApp "Olá" pro número da Lara (Mais Saúde cobrança). Lara responde com saudação. Cliente pergunta sobre dívida. Lara consulta CRM via tool, retorna valor do deal. Cliente agradece. Conversa fica documentada no Frontdesk + logs no KLaOS AI.

#### 6.3.2 Critérios

- **AC-3.1**: Mensagem do cliente chega no Frontdesk (conversa criada) em <5s.
- **AC-3.2**: Webhook dispara pro KLaOS AI com payload enriquecido (channel_type, provider).
- **AC-3.3**: AI responde em <30s (p95).
- **AC-3.4**: Resposta aparece na conversa do Frontdesk e é entregue ao WA do cliente.
- **AC-3.5**: Tool call do CRM funciona e retorna dados do deal correto.
- **AC-3.6**: Áudio responde sem erro 131053 (fix 2026-04 aplicado).
- **AC-3.7**: Logs do KLaOS mostram a execução completa (turno, tool, resposta).

#### 6.3.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-720 | Conversa simples texto 3 turnos | Crítica |
| TC-721 | Bot consulta CRM e retorna valor | Crítica |
| TC-722 | Bot responde com áudio (sem 131053) | Crítica |
| TC-723 | Bot recebe imagem de boleto e identifica | Alta |
| TC-724 | Webhook enriquecido chega corretamente | Alta |
| TC-725 | Latência média aceitável (<30s/resposta) | Alta |

##### TC-722 — Bot responde com áudio

**Passos**:
1. Cliente (Davi pelo WA pessoal) manda "oi" pro número Lara
2. Esperar resposta de Lara
3. Se Lara responder texto, Davi pede: "me explica por áudio"
4. Lara responde com mensagem de voz
5. Davi verifica no WhatsApp

**Resultado esperado**: áudio chega, é playable, sem erro Meta 131053.

---

### 6.4 Jornada: Handoff bot → humano 🟡

> **Estado**: parcialmente funcional. Critério no AI existe, ação no Frontdesk falha. Essa jornada é **a mais crítica em aberto**.

#### 6.4.1 User Story
> Cliente fala com Lara sobre problema complexo. Lara detecta que precisa humano (palavra "atendente", ou 3 turnos sem fechar). Lara marca conversa como open e atribui ao time cobrança. Agente humano recebe notificação (sininho + email). Conversa aparece na tab "Minhas" do agente.

#### 6.4.2 Critérios

- **AC-4.1**: Trigger do handoff dispara corretamente conforme config (palavra-chave, N turnos, confidence).
- **AC-4.2**: AI chama Frontdesk API `POST /conversations/:id/toggle_status` com `status=open`.
- **AC-4.3**: AI chama Frontdesk API `POST /conversations/:id/assignments` com `team_id` ou `assignee_id`.
- **AC-4.4**: AI posta nota privada no Frontdesk explicando motivo do handoff.
- **AC-4.5**: Bot **para de responder** naquela conversa após handoff.
- **AC-4.6**: Frontdesk dispara notificação pro humano atribuído (sininho + email).
- **AC-4.7**: Conversa sai de `pending` e aparece em `open` na lista de conversas com filtro "Ativas".

#### 6.4.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-730 | Trigger palavra-chave "humano" dispara handoff | **Crítica** |
| TC-731 | Status muda pra `open` no Frontdesk | **Crítica** |
| TC-732 | Team `cobrança` recebe conversa | **Crítica** |
| TC-733 | Agente humano recebe notificação | **Crítica** |
| TC-734 | Nota privada explicativa postada | Alta |
| TC-735 | Bot silencia após handoff | Crítica |
| TC-736 | Trigger por N turnos sem resolver | Alta |
| TC-737 | Se fails em qualquer passo, retry ou fallback claro | Alta |

##### TC-730 — Handoff por palavra-chave

**Pré-condição**: Lara configurada com trigger "humano|atendente" no KLaOS.

**Passos**:
1. Cliente manda WA: "quero falar com um atendente humano"
2. Aguardar até 1 minuto
3. Abrir conversa no Frontdesk
4. Verificar status, assignee, nota privada
5. Logar como agente do time cobrança em outra aba, ver se sininho acendeu

**Resultado esperado**:
- Status da conversa mudou de `pending` pra `open`
- `assignee_team = cobrança` ou `assignee_id = <agente específico>`
- Nota privada visível com motivo ("handoff: cliente solicitou humano")
- Lara não responde mais nessa conversa
- Agente do time recebeu notificação no sininho

> **Atenção**: essa jornada tá QUEBRADA em prod (Mais Saúde 15 conversas presas em pending). Esperado que esse TC FAIL enquanto KLaOS não implementa. Davi reporta como bug e marca como Blocked até fix.

---

### 6.5 Jornada: Push de deal (CRM → Frontdesk via CRM Bridge)

#### 6.5.1 User Story
> SDR cria deal no CRM pra Marina Silva. Atualiza stage pra "Proposta" com valor R$ 5k. Marina tem conversa ativa no Frontdesk (WA Cobrança). Agente que atende a conversa vê na sidebar: deal, valor, stage atual, closer atribuído.

#### 6.5.2 Critérios

- **AC-5.1**: Deal no CRM é atualizado → CRM Bridge chama Frontdesk `PUT /conversations/:id/deal` com payload completo.
- **AC-5.2**: Frontdesk salva dados em `custom_attributes` da conversa.
- **AC-5.3**: Sidebar do Frontdesk renderiza os atributos com labels humanos (não chaves técnicas).
- **AC-5.4**: Mudança de stage no CRM reflete no Frontdesk em <10s.
- **AC-5.5**: Deletar deal limpa os atributos.

#### 6.5.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-740 | Deal atualizado aparece na sidebar da conversa | Crítica |
| TC-741 | Mudança de stage propaga | Alta |
| TC-742 | Agendamento preenche scheduled_at + closer_assigned | Alta |
| TC-743 | Delete deal limpa sidebar | Alta |
| TC-744 | Conversa sem deal — sidebar mostra sem atributos CRM | Média |

---

### 6.6 Jornada: Consulta do CRM pelo bot (AI → CRM tool)

#### 6.6.1 User Story
> Cliente pergunta "qual meu saldo devedor?". Lara (bot) identifica intent, chama tool `query_deal(contact_id)`, recebe valor, responde "Você tem R$ 320,00 em aberto desde 15/03".

#### 6.6.2 Critérios

- **AC-6.1**: Tool call disponível no AI Agent com `crm_query_deal` habilitado.
- **AC-6.2**: Agent chama CRM API com contact_id correto extraído do contexto.
- **AC-6.3**: Resposta do CRM é formatada legível na resposta do bot.
- **AC-6.4**: Erro de CRM (ex: contato não tem deal) tem fallback amigável ("Não encontrei um caso em aberto").
- **AC-6.5**: Permissões respeitadas (bot só acessa deals do workspace dele).

#### 6.6.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-750 | Cliente pergunta — bot responde com dado CRM | Crítica |
| TC-751 | Contato sem deal — fallback amigável | Alta |
| TC-752 | Bot não acessa deals de outro workspace | **Crítica** (segurança) |

---

### 6.7 Jornada: Agendamento via bot (CRM + Google Calendar + Frontdesk)

#### 6.7.1 User Story
> Cliente conversa com Lara, pede reunião. Lara gera link de agendamento do closer disponível. Cliente acessa link, escolhe horário. Reunião é marcada no Google Calendar do closer. Conversa no Frontdesk recebe `scheduled_at` e `closer_assigned` na sidebar.

#### 6.7.2 Critérios

- **AC-7.1**: Bot tem tool `crm_schedule_meeting` habilitada.
- **AC-7.2**: Link gerado aponta pra página de agendamento válida.
- **AC-7.3**: Após cliente confirmar, evento aparece no Google Calendar do closer.
- **AC-7.4**: `scheduled_at` e `closer_assigned` aparecem na sidebar do Frontdesk.
- **AC-7.5**: Cancelamento pelo cliente remove do calendar + limpa sidebar.

#### 6.7.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-760 | Fluxo completo de agendamento | Crítica |
| TC-761 | Cancelamento propaga em ambos lados | Alta |
| TC-762 | Closer sem horários disponíveis — mensagem clara | Média |

---

### 6.8 Jornada: Webhook payload enrichment (Frontdesk → KLaOS)

#### 6.8.1 User Story
> Qualquer evento do Frontdesk que dispara webhook (message_created, conversation_created, etc.) chega no KLaOS com campos extras (`channel_type`, `channel_name`, `provider`) que permitem roteamento sem query reversa.

#### 6.8.2 Critérios

- **AC-8.1**: Payload do webhook contém `channel_type`, `channel_name`, `provider`.
- **AC-8.2**: Valores corretos por tipo de canal (ver §5.26 Frontdesk).
- **AC-8.3**: KLaOS usa esses campos pra rotear sem fazer chamada reversa.

#### 6.8.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-770 | WhatsApp WABA → `provider=meta_cloud` | Alta |
| TC-771 | Evolution → `provider=evolution` | Alta |
| TC-772 | WebWidget → `channel_type=Channel::WebWidget` | Alta |

---

### 6.9 Jornada: Filtro "Ativas" funcionando ponta-a-ponta

#### 6.9.1 User Story
> Agente de Mais Saúde loga. Vê filtro default "Ativas" aplicado. Lista mostra só conversas que precisam atenção (open/pending/snoozed). Resolvidas não poluem. Se um bot transborda uma pending, ela continua visível (AC de integração com handoff).

#### 6.9.2 Critérios

- **AC-9.1**: Filtro Ativas retorna conversas com status ∈ {open, pending, snoozed}.
- **AC-9.2**: Handoff bem-sucedido (§6.4) faz a conversa continuar visível (de pending → open, ambos são "ativas").
- **AC-9.3**: Sem loops infinitos de requisições (fix de 2026-04-21).

#### 6.9.3 TCs

| ID | Título | Prioridade |
|---|---|---|
| TC-780 | Conversa em pending aparece no filtro Ativas | Crítica |
| TC-781 | Handoff converte pending → open e continua visível | Crítica |
| TC-782 | Conversa resolved não aparece | Alta |
| TC-783 | Sem loop infinito de fetch | Alta |

---

### 6.10 Jornada: Cliente final experience (regressão completa)

> Jornada de smoke test que o QA executa manualmente em cada release pra garantir que o básico não quebrou.

#### 6.10.1 Script de regressão

**Objetivo**: simular cliente da Mais Saúde do início ao fim em ~15 minutos.

**Passos**:
1. Cliente acessa site da Mais Saúde, abre widget de chat
2. Digita nome + email no pré-chat
3. Envia mensagem "oi, queria saber do meu boleto"
4. Lara responde, consulta CRM, retorna valor
5. Cliente pede segunda via: Lara envia PDF via WhatsApp (se widget linkado a WA)
6. Cliente pede "falar com humano"
7. Handoff dispara: agente humano recebe notificação
8. Humano responde, cliente responde
9. Humano resolve a conversa
10. Conversa some da tab "Ativas"
11. Cliente responde de novo depois — conversa reabre automaticamente

**Sistemas usados**: Frontdesk + AI Agent + CRM + Meta/Evolution.

**Se algo falha em qualquer passo**: bug de alta prioridade. Documentar em gravação de tela.

---

## 7. Matriz de TCs por sistema responsável

Quando um bug é encontrado em jornada de integração, classificar pra onde vai o ticket:

| Sintoma | Onde verificar primeiro |
|---|---|
| User criado KLaOS não aparece Frontdesk | KLaOS (provisionamento) |
| Bot responde com sender_id errado | KLaOS (access_token sync) |
| Bot não responde nunca | Frontdesk (webhook guard) + KLaOS (agent ativo?) |
| Deal atualizado não aparece na sidebar | KLaOS CRM Bridge + Frontdesk custom_attributes |
| Handoff não desprende de pending | KLaOS (ação PATCH no Frontdesk) |
| Áudio 131053 Meta error | Frontdesk (Media API upload) |
| Filtro Ativas lista vazia apesar de count > 0 | Frontdesk (helpers.filterByStatus) |
| Loop infinito de requests no dashboard | Frontdesk (ChatList paginação) |

---

## 8. Anexos

### Anexo A — Checklist de smoke test pré-release
_(lista rápida pra QA rodar em 30min antes de promover dev → prod)_

- [ ] TC-710 (provisionar bot)
- [ ] TC-720 (conversa simples)
- [ ] TC-740 (push deal)
- [ ] TC-750 (bot consulta CRM)
- [ ] TC-770-772 (webhook enriquecido)
- [ ] TC-780 (filtro Ativas)
- [ ] §6.10 (regressão cliente final)

### Anexo B — Sign-off
| Papel | Nome | Data | Assinatura |
|---|---|---|---|
| QA Lead | Davi Felix | | |
| Product | Matheus Macedo | | |
| Eng Lead (Frontdesk) | | | |
| Eng Lead (KLaOS) | | | |
