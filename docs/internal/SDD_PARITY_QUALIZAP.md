# SDD — Paridade Frontdesk × Kualiz (Gustavo / Mais Saúde)

**Origem**: Estudo do sistema atual do Gustavo (Kualiz, hospedado em `atendmedbh.atenderbem.com`, v12.1.7) — referenciado pelo cliente nos pontos **8** e **9** do doc "AJUSTES" como o padrão de UX que ele quer que o Frontdesk imite.
**Data**: 2026-05-27
**Branch**: `klaos-dev`
**Acesso**: admin (`gustavo`) + agente (`gustavo Agente`) — credenciais em `memory/reference_qualizap_atendmedbh.md`.

> Objetivo: documentar **o que o Kualiz faz que o Gustavo ama** e **traduzir pro Frontdesk** mantendo a nossa paleta KLaOS. Cobre os **9 itens de plataforma** dos 17 (1, 2, 6, 7, 8, 9, 10, 11, 12) + oportunidades extras identificadas durante a exploração.

---

## ⚠️ Princípio NÃO-negociável — MODULARIDADE UPSTREAM-SAFE

> **Regra fixa do projeto** (também em `memory/feedback_custom_modules_upstream_safe.md`): o Frontdesk é um **fork do Chatwoot** e queremos **continuar puxando atualizações do upstream** quando decidirmos — sem perder nada do que customizamos.
>
> **Toda paridade com Kualiz que adicionarmos DEVE respeitar:**
>
> 1. **Código Ruby/Rails (backend)** → vive em `custom/app/...`, `custom/lib/...`, `custom/config/initializers/...`. NUNCA modificar `app/`, `lib/`, `config/environments/` upstream. Usa `prepend`/`class_eval`/`Rails.application.config.to_prepare` pra estender comportamento.
>
> 2. **Vue (frontend)** → componentes custom em pasta `Klaos*` dentro de `app/javascript/dashboard/components-next/` (ex: `KlaosTransferToBot/`, `KlaosTimeline/`). Wiring via **string-replace patches** em `custom/vite/klaos-patches.js` (transforma upstream `.vue` no build, com `from`/`to` literal — se upstream renomear, o build **FALHA explicitamente**, sinal claro pra ajustar).
>
> 3. **i18n** → idealmente patch via `klaos-patches.js` modificando o `t()` resolver ou via override no resolver (NÃO editar JSONs upstream em `app/javascript/dashboard/i18n/locale/`). Casos antigos onde editamos direto (TRANSFER_TO_BOT*) viraram dívida — não criar mais.
>
> 4. **DB / Migrations** → migrations custom em `custom/db/migrate/` quando precisar. Nunca alterar migrations upstream. Schemas custom novos (whatsapp_connections, whatsapp_phone_numbers) vivem em `custom/app/models/`.
>
> 5. **Rotas / Controllers** → namespace `Api::Custom::V1::*` em `custom/app/controllers/api/custom/v1/...` + rota appendada via `Rails.application.routes.append` em `custom/config/initializers/*_routes.rb`. Não tocar em `config/routes.rb` upstream.
>
> 6. **Cores / Tema** → CSS custom em pasta `custom/app/javascript/...` ou via vite patch num arquivo de tema dedicado. Não editar variáveis de tema upstream.
>
> 7. **i18n strings novas** → quando hardcoded em componente Klaos*, **OK** (não polui upstream). Quando precisa override de string upstream → patch via klaos-patches.
>
> **Critério de aceite por feature**: `git merge upstream/master` em branch limpo deve aplicar **zero conflito** nos arquivos upstream. Se conflitar, a feature está mal-modularizada e precisa refatorar.

---

## ⚠️ Princípio companheiro — REAPROVEITAR O CHATWOOT, REDESENHAR O LAYOUT

> **Regra de avaliação por feature:** antes de implementar QUALQUER paridade, perguntar:
>
> 1. **O Chatwoot upstream JÁ TEM essa funcionalidade no backend?** → Reaproveitar (endpoint, modelo, serviço, ActionCable). Não reescrever motor.
> 2. **O Chatwoot tem layout/UX pra isso?** → Avaliar: o layout dele é "limpo o suficiente" ou "torto"? Se torto, **trocar o layout** (via Vue patch / componente Klaos*) **mantendo o backend dele intacto**.
>
> **Exemplos práticos** dessa filosofia:
> - **Auto-attribuir** (ponto 2): Chatwoot tem `auto_assignment` por inbox (round-robin) + `assignee_id` no modelo Conversation. **Reusar** o `assignee_id` + criar só um hook custom de quando setar. NÃO reescrever assignment.
> - **✓✓ delivery status** (ponto 12): Chatwoot tem `message.status` (sent/delivered/read) + `MessageMeta.vue` que renderiza. **Layout do MessageMeta é ok**, reusar. Backend webhook Meta já processa via `process_statuses`. **Reusar tudo.**
> - **Painel de Agentes em tempo real** (O.1): Chatwoot tem `ActionCable` + `OnlineStatusTracker` + endpoint `/agents` com `availability_status`. **Reusar backend completo.** Layout do Chatwoot pra isso é **inexistente/torto** (só mostra avatar com bolinha colorida na sidebar) → **redesenhar visual completo** estilo Kualiz com cores KLaOS.
> - **Reabertura** (ponto 7): Chatwoot tem comportamento nativo + nosso `lock_to_single_conversation`. **Reusar.** Layout (bolinha verde, som, etc.) já está na UI. **Reusar.**
> - **Custom Views / Pastas** (item 10 e oportunidade): Chatwoot tem **CustomFilter** completo. **Reusar backend** (já investigado). O bug que bati foi de serialização específica, não da feature em si — resolver bug ou usar i18n escopado.
>
> **Quando NÃO reaproveitar (= redesenhar layout):**
> - Sidebar / navegação principal — Chatwoot tem layout denso e técnico, Kualiz tem top-bar simples com 10 áreas claras. Redesenhar top-bar.
> - Lista de conversas — Chatwoot mostra info técnica (channel icon, status), Kualiz mostra **tempo desde última msg em destaque**, etiqueta como ícone, ações inline. Redesenhar ConversationCard.
> - Header da conversa — Chatwoot tem botão Resolver + dropdown. Kualiz tem 4 botões claros + alerta janela 24h banner. Redesenhar header.
> - Tela inicial do agente — Chatwoot manda direto pra lista, Kualiz tem "Gerenciar filas" + cronômetro + frase motivacional. Redesenhar home.
>
> **Resultado**: backend = 95% Chatwoot intocado. Frontend = mix (60% Chatwoot reusado + 40% Klaos* custom redesenhado pra UX limpo). Merge upstream continua viável.
>
> **Já temos histórico de bons patches modulares** que servem de referência:
> - `custom/lib/attachment_url_strategy.rb` + `custom/config/initializers/attachment_url_strategy.rb` (módulo Ruby prepended em Attachment).
> - `custom/config/initializers/human_message_prefix.rb` (`before_create` em Message).
> - `custom/config/initializers/lock_single_conversation_default.rb` (`before_create` em Inbox).
> - `app/javascript/dashboard/components-next/KlaosTransferToBot/TransferToBotButton.vue` + 2 patches em `klaos-patches.js` (componente Vue custom + wiring).
> - `app/javascript/dashboard/components-next/KlaosTimeline/KlaosTimeline.vue` (histórico do contato).
>
> Toda feature do §3 e §2 abaixo segue esse padrão. Anexei a cada item do plano a **localização sugerida** do código.

---

## ⚠️ Princípio crítico — MULTI-TENANT (a Frontdesk não é só da Mais Saúde)

> **Regra fixa do projeto** (definida em 2026-05-28, durante reavaliação da Onda 1 com o Matheus): a aplicação Frontdesk é **multi-tenant** — atende **vários clientes** simultaneamente. Toda paridade que viermos a trazer da Kualiz **DEVE servir para todos os clientes**, não pode ser hardcoded para a Mais Saúde.
>
> **Critério de aceite por feature:**
>
> 1. **Custom-safe** — vive em `custom/`, sobrevive a `git merge upstream/develop`.
> 2. **Multi-tenant** — funciona para qualquer conta. Se o comportamento precisa variar por cliente, vira **toggle/campo configurável** (em `account.custom_attributes`, `inbox.custom_attributes`, ou `account_user.ui_settings` conforme o escopo). Cliente liga/preenche; quem não quer, mantém o default.
> 3. **Reaproveitamento antes de criação** — se o Chatwoot já tem o motor (modelo, endpoint, serviço, ActionCable), **prepended/sobrescrito**, não duplicado. O que reescrevemos é a **UI**, não o motor.
>
> **Anti-padrão proibido** (já cometido e corrigido):
> - ❌ "Cria um initializer que aplica `auto_offline=false` só pras accs 9 e 10."
> - ✅ Em vez disso: `account.custom_attributes[:auto_offline_default]` + campo em Configurações → Geral por conta.
>
> **Como aplicar o filtro no momento de implementar cada item:**
>
> Antes de codar, perguntar:
> 1. "Esse comportamento serve a TODOS os clientes? Ou só faz sentido pra Mais Saúde?"
>    - Se serve todos → genérico, ativo por padrão.
>    - Se só pra Mais Saúde → vira **toggle/campo** com default `off`/`null`. Mais Saúde liga; outros nem sabem que existe.
> 2. "O Chatwoot já tem motor pra isso?"
>    - Se sim → **reaproveito** (prepend/concern/wiring custom). Só **redesenho UI** se a UI dele é torta/inexistente.
>    - Se não → componente Klaos* novo + modelo custom em `custom/`.
> 3. "Tem feature parecida no Frontdesk que dá pra evoluir?"
>    - Se sim → **adequo UI/comportamento** dela em vez de criar paralelo.

---

## 0. Visão geral do Kualiz

### Topologia (admin x agente)
| Perfil | URL pós-login | O que vê |
|---|---|---|
| Admin (`gustavo`) | `/base/reports/kpidashboard` | Dashboard de KPIs, top-bar com 10 áreas, modal de retenção de dados |
| Agente (`gustavo Agente`) | `/base/agentdashboard` | "Gerenciar filas" — filas atendidas + cronômetro de turno + botões status (online/pausa/offline) + frase motivacional + Novidades |

### Top-bar (igual nos dois perfis, com itens contextuais)
Da esquerda pra direita:
1. **Logo Kualiz** (link pra home)
2. **Painel e Indicadores** / **Painel de filas** (botão laranja com badge — pega o foco de quem você é: admin vê KPIs, agente entra na fila)
3. **Painel de agentes** — *só admin* (real-time agent grid)
4. **CRM**
5. **Chat Interno** — *chat entre atendentes da operação*
6. **Tarefas**
7. **Contatos** (book/agenda)
8. **Relatórios** (gerados/baixados)
9. **Notificações** (sino com dot vermelho)
10. **Configurações** (engrenagem)
11. **Sair** (power off)

À direita: avatar + nome do usuário ("Administrador GUSTAVO" / "Atendente GUSTAVO Gustavo Agente"), com dropdown.

### Paleta visual do Kualiz (pra adaptar pra KLaOS)
| Elemento | Cor Kualiz | Cor KLaOS sugerida |
|---|---|---|
| Header / top-bar | Navy escuro `#1B2A4E` (aprox) | KLaOS dark (manter padrão atual do Frontdesk) |
| Botão ativo / acento principal | Laranja `#F2994A` (aprox) | KLaOS primary (verde-azulado do logo / cor brand) |
| Estado online | Verde `#27AE60` | Verde KLaOS |
| Estado pausa | Amarelo `#F2C94C` | Amarelo KLaOS |
| Estado offline / erro | Vermelho `#E74C3C` | Vermelho KLaOS |
| Background | Cinza claro `#F4F4F6` | Manter cinza do Frontdesk |
| Texto principal | Preto `#222` | Manter |

> Princípio: **estrutura/layout do Kualiz**, **cores do KLaOS**. O Gustavo está acostumado com o fluxo dele; mantemos a familiaridade do "onde clicar" e trocamos a identidade visual.

---

## 1. Mapa dos 9 pontos do Gustavo × telas do Kualiz

Pra cada ponto: o que Gustavo pediu · como o Kualiz resolve hoje (com tela) · gap atual do Frontdesk · plano de paridade.

---

### Ponto 1 — Ordem dos templates (protesto em 1º)
**O que Gustavo pediu**: o template mais usado (protesto) deve aparecer primeiro no seletor.

**Como o Kualiz faz**: não confirmado nesta sessão (a tela de envio de template fica dentro do "Painel de filas" do agente — não acessei ao vivo). Padrão típico em sistemas como Kualiz é ordenação por **frequência de uso** automática + possibilidade de pinar/favoritar manualmente.

**Frontdesk hoje**: já tem ordenação automática por frequência de uso (`top_templates_controller`), implementada em sessão anterior. Mas o ranking "esfriou" ou não está refletindo o uso. Ver item 1 do `RESPOSTAS_GUSTAVO_v2.md`.

**Plano de paridade**:
- Verificar por que "protesto" caiu do topo (cache TTL? contagem zerada?).
- **Oportunidade**: adicionar ícone de **fixar template no topo** (pino) — controle manual além da frequência automática. Ver "Oportunidades" abaixo.

---

### Ponto 2 — Auto-atribuir conversa ao remetente da notificação
**O que Gustavo pediu**: ao disparar template ativo, a conversa cai em "Minhas" automaticamente.

**Como o Kualiz faz**: o agente envia mensagens **a partir da fila dele** — a conversa já é "dele" por natureza (entrou na fila atribuída ao agente). No painel de admin (`Painel de atendimentos`), cada conversa mostra o **Agente atribuído** ou **"Não atribuído"** explicitamente — admin transfere via botão dedicado.

**Frontdesk hoje**: ao enviar template proativo, a conversa **não** é atribuída ao remetente — fica sem dono. Item 2 do `RESPOSTAS_GUSTAVO_v2.md`: vai pra rotina.

**Plano de paridade**:
- Hook no envio de template/notificação ativa: setar `assignee_id = current_user.id` automaticamente.
- Aparece em "Minhas" do remetente na hora.

---

### Ponto 6 — Negrito com 1 asterisco (estilo WhatsApp)
**O que Gustavo pediu**: `*texto*` = negrito (não itálico).

**Como o Kualiz faz**: não validei o editor do agente nesta sessão (precisava de uma fila ativa). Como o público do Kualiz é operação de WhatsApp puro, é provável que o editor já trate `*` como negrito (estilo WhatsApp), sem passar por markdown padrão.

**Frontdesk hoje**: usa padrão Markdown (`*` = itálico, `**` = negrito). Item 6 do `RESPOSTAS_GUSTAVO_v2.md`: vai pra rotina.

**Plano de paridade**:
- Pré-processador no envio pro WhatsApp: converter `*texto*` (não-aninhado, com espaço/borda antes e depois) → negrito WhatsApp `*texto*`.
- Mais simples: customizar o renderer markdown-to-WhatsApp pra mapear single `*` como bold em vez de italic.

---

### Ponto 7 — Reabertura + bolinha verde + som por atendente
**O que Gustavo pediu**: cliente manda mensagem em conversa resolvida → reabre + não-lida + toca som.

**Como o Kualiz faz**:
- **Reabertura**: o conceito de "conversa resolvida" no Kualiz é mais leve — o atendimento fica em fila e fecha por timeout/ação. Mensagem nova reentra automaticamente.
- **Bolinha de não-lida**: vista nos cards de fila do agente.
- **Som**: o agente tem controle do estado (botões 🔴 stop / 🟢 play / 🟡 pausa no canto sup. direito da tela de filas). Som é parte do **play** (atendimento ativo).

**Frontdesk hoje**:
- Reabertura: já tem (via `lock_to_single_conversation=true` aplicado globalmente).
- Bolinha verde: já é automática.
- Som: requer permissão do navegador + ajuste em Configurações do Perfil → Alertas de áudio (passo a passo no `RESPOSTAS_GUSTAVO_v2.md`).

**Plano de paridade**:
- Reabertura: validar comportamento ao vivo na conta da Mais Saúde (entrou na rotina).
- Som: criar passo-a-passo claro + verificar push_flags backend (memória `reference_notificacoes_push_som` documenta que push_flags=2 precisa virar 31).

---

### Ponto 8 — Caminho admin: ver / assumir / transferir conversas (★ GOLD)
**O que Gustavo pediu**: "muito fácil, simples e rápido conseguir ver todas as conversas, interagir e transferir" — exatamente como no Kualiz.

**Como o Kualiz faz** (3 telas que o admin usa):

#### 8.1 **Painel de Agentes** (`/base/dashboard` aba "Painel de agentes")
Grid em tempo real com TODOS os agentes da operação. Por linha:

| Coluna | O que mostra |
|---|---|
| Avatar + Nome | Foto/iniciais do agente + nome |
| Filas (Agora) | Quantas filas o agente atende neste momento (2 Filas / 4 Filas / etc.) |
| Estado (Agora) | ▶ verde (online) · ⏸ amarelo (em pausa) · ✕ vermelho (offline) |
| chats (Agora) | Quantos chats em atendimento AGORA por agente (8, 91, 37, etc.) |
| N/D + métricas (Hoje) | Atendidos / abandonados / médias do dia |
| Logado | Tempo total logado hoje |
| Pausa | Tempo total em pausa hoje |
| Funções | 🔒 forçar offline · ⏸⏸ pause/play · ⓘ info · ⋮ menu |

**Topo direito**: resumo em badges → 🔴 6 ocupados · 🟠 1 pausa · 🟢 4 online · 🔒 0 offline.

**Sidebar esquerda**: lista de **canais** (API OFICIAL, Reserva Boletos, Facebook MAIS SAÚ, Instagram MAIS SAÚ...) com contador de conversas por canal e cor de status.

#### 8.2 **Painel de Atendimentos** (mesma URL, aba ao lado)
Tabela com TODAS as conversas (39 + 98 + 100 no resumo do topo direito):

| Coluna | O que mostra |
|---|---|
| Etiqueta | Tag/label da conversa |
| Cliente | Avatar + nome + indicador online/offline + ❤ favorito |
| Agente | Quem está atendendo (ou "Não atribuído") |
| Status | ✕ aberta / outras |
| Tempo última msg | Quanto tempo sem interação (5d 12h, 8h 17m...) — **gold pra SLA** |
| Tempo total | Duração total do atendimento |
| Funções | 👤 abrir contato · 💬 abrir atendimento · ⇄ transferir · ✖ encerrar |

#### 8.3 **Visualizar Conversa** (modal abre via 💬)
Modal com:
- Header: nome do agente + canal + número do cliente
- Timeline da conversa renderizada (templates como cards, mensagens com timestamp e ✓✓)
- Alerta automático da **janela 24h do WhatsApp** ("Atendimento bloqueado devido ao fim da janela de 24hrs. Será desbloqueado se o cliente enviar nova mensagem")
- Campo de **mensagem de alerta privada** (admin manda nota só pro agente, não vai pro cliente)
- Botões topo direito: ⇄ transferir / ✖ fechar

**Frontdesk hoje**:
- Ver todas: ✅ existe (Conversas → Todas → aba "Todos").
- Assumir: ✅ existe (painel direito → Agente atribuído → Atribuir a mim).
- Transferir: ✅ existe (mesmo painel).
- **Gap**: não tem o **resumo de agentes em tempo real com chats por agente, tempo logado, controle de pausa/offline forçado pelo admin** (item 8.1 acima). Falta a tela "Painel de Agentes" como visão de SUPERVISÃO.
- **Gap**: não tem **tempo desde última mensagem** na lista de conversas (item 8.2).
- **Gap**: não tem **alerta visual da janela 24h** dentro da conversa.

**Plano de paridade**:
- **P1 — Tela Painel de Agentes (novo)**: criar rota `/app/accounts/:id/supervisor/agents` com grid de agentes em tempo real, chats por agente, tempo logado, controle admin.
- **P2 — Tempo última msg nas listas**: adicionar coluna "Última msg há X" na lista de conversas (extensão do `ChatListItem` via klaos-patch).
- **P3 — Alerta janela 24h**: banner na conversa quando `last_inbound_message > 24h` E status pode_falar.
- **P4 — Documentar passo-a-passo** dos 3 caminhos atuais (já entregue no `RESPOSTAS_GUSTAVO_v2.md`).

---

### Ponto 9 — Sempre online (★ GOLD)
**O que Gustavo pediu**: "100% online o tempo todo" igual o Kualiz.

**Como o Kualiz faz**: o agente tem **3 botões grandes** no canto superior direito da tela dele:
- 🔴 **Stop** (offline / encerrar turno)
- 🟢 **Play** (online / iniciar turno)
- 🟡 **Pausa** (pausa temporária)

Estado é **explícito e controlado pelo agente** — não tem "auto-offline por inatividade". O agente entra "Logado - Em pausa" nas filas (estado padrão visto na tela de filas) e ele controla manualmente.

Bonus: tela mostra **cronômetro de turno** em destaque ("00:33" — tempo desde que apertou play hoje) + frase motivacional rotativa + seção "Novidades".

**Frontdesk hoje**:
- Tem `account_user.auto_offline` (boolean). Default `true` (sai offline por inatividade).
- Setting fica num menu dropdown do avatar (não em destaque).
- Sem cronômetro de turno. Sem botões grandes de status.

**Plano de paridade**:
- **P1** (config inicial): desligar `auto_offline` para os atendentes da Mais Saúde (4-5 rows DB). Imediato.
- **P2** (UI): trazer os **botões grandes de status** (🔴 Stop / 🟢 Play / 🟡 Pausa) pra área visível — header ou sidebar topo, não no menu do avatar.
- **P3** (oportunidade): cronômetro de turno + frase motivacional + Novidades. Ver "Oportunidades".

---

### Ponto 10 — Renomear "Não atribuídas" → "Inteligência Artificial"
**O que Gustavo pediu**: renomear a aba pra deixar claro que são conversas com a IA.

**Como o Kualiz faz**: o "Não atribuído" do Kualiz aparece no campo Agente da linha (Ex.: cliente "Amanda Mendes Pires Neves" → coluna Agente: "Não atribuído"). É só um rótulo de coluna, não tem aba dedicada.

**Frontdesk hoje**: aba dedicada "Não atribuídas" no topo da lista de conversas, com counter. Renomeação tem que ser por conta (multi-tenant, outras contas não tem IA).

**Plano de paridade**:
- Patch Vue escopado por `currentAccount.id`: renomeia label só pra acc 9 (Mais Saúde prod) e acc 10 (Mais Saúde dev). Detalhado no item 10 do `RESPOSTAS_GUSTAVO_v2.md`.
- **Nota**: tentei via Pastas/Custom Views nativas mas bati num bug de renderização — virou item separado de investigação.

---

### Ponto 11 — Busca de contato sem acento/cedilha
**O que Gustavo pediu**: digitar "cassia" acha "CÁSSIA".

**Como o Kualiz faz**: não testei a busca de contatos ao vivo, mas o sistema tem **campo "Buscar"** no topo da maioria das telas (visto no Painel de Atendimentos) — busca é central na UX do Kualiz.

**Frontdesk hoje**: busca de contato distingue acento (ILIKE puro, sem unaccent). Item 11 do `RESPOSTAS_GUSTAVO_v2.md`: vai pra rotina.

**Plano de paridade**:
- Habilitar extensão `unaccent` no Postgres do Frontdesk.
- Alterar a query do `ContactsController` (controller custom prepended) pra `unaccent(name) ILIKE unaccent(:search)`.
- Também replicar no campo de **busca de conversa** ("Buscar por nome, telefone ou #ID").

---

### Ponto 12 — Mídia em tempo real + ✓✓ de entrega
**O que Gustavo pediu**:
- 12.1 — imagem aparece em tempo real (sem refresh).
- 12.2 — áudio toca (recebido).
- 12.3 — enviar imagem sem erro + ✓/✓✓ visível.
- 12.4 — enviar áudio idem.

**Como o Kualiz faz** (visto no modal Visualizar Conversa):
- ✓✓ azul na mensagem do agente (timestamp + check duplo + cor azul = lido).
- Templates renderizados como **cards visuais** (com ícone bot e estrutura clara) — não só texto.
- Banner de **bloqueio janela 24h** explícito.

**Frontdesk hoje**:
- 12.1 / 12.2: ✅ resolvido em 25/05 (fix do `FRONTEND_URL` do worker).
- 12.3 / 12.4: parcial — erro de envio de áudio resolvido em 22/05; ✓✓ visíveis nativamente (`MessageMeta.vue`) **se** os webhooks de status da Meta chegarem; envio de imagem ainda na rotina.

**Plano de paridade**:
- Validar que os ✓✓ aparecem ao vivo em prod (Mais Saúde) — confirmar webhook status da Meta tá chegando.
- Investigar 12.3 (envio imagem com erro intermitente) — entra na rotina.
- **Oportunidade visual**: renderizar templates do bot como **cards** (não texto puro) — já fizemos parcialmente no `KlaosTimeline`. Extender pra view principal de conversas.

---

## 2. Oportunidades extras (features fora dos 17 pontos, mas valiosas)

Identificadas durante a exploração. Não foram pedidas pelo Gustavo, mas seriam ganho real no Frontdesk:

### O.1 — Painel de Agentes (supervisão em tempo real)
**Já citado no ponto 8.** Repete porque vale uma feature dedicada: **dashboard de SUPERVISÃO** pro admin. Métricas hoje (TMA, atendidos, médias) + estado atual de cada agente + ações de força (logout, pause). Frontdesk não tem nada parecido.

### O.2 — Painel de Produtividade (aba ao lado em `/base/dashboard`)
Não explorei a fundo mas pelo nome é dashboard de produtividade por agente / período. Métricas de SLA, TMA, % resolução. Pra cobrança / planejamento, valeria muito.

### O.3 — KPI Dashboard como home do admin
Quando admin loga, cai num dashboard com KPIs principais: Atendimentos / Clientes únicos / Mensagens enviadas / Mensagens recebidas / Méd. atend/agente / TMA / gráficos de Contatos por hora e Contatos por dia. Frontdesk tem "Visão geral" mas não tão denso.

### O.4 — URA (filtro) + Filas como conceito de primeira classe
Kualiz organiza tudo em **filas** (e na visão admin tem "filtros da URA"). Frontdesk usa "inboxes" — conceito mais genérico. **Filas com prioridade e capacidade por agente** seria upgrade real (cf. tela do agente: "Administrativa - Máximo: ilimitada" — controle de carga máxima por fila).

### O.5 — Minhas Tarefas + Meus Agendamentos (por agente)
Vistos no submenu "Painel de filas" do agente. Tarefas atreladas a conversas / agendamentos futuros. Frontdesk hoje só tem Conversations + Macros. Tarefas seriam um diferencial pra cobrança (follow-up futuro).

### O.6 — Chat Interno entre atendentes
Item de menu top-bar dedicado. Operação tem chat lateral pra falar entre si sem misturar com cliente. Frontdesk tem "menção" (`@`) mas não chat interno dedicado.

### O.7 — Cronômetro de turno + Frase motivacional + Novidades
Tela do agente: ao entrar, cronômetro grande "00:33" do tempo logado + citação rotativa (Charles Chaplin, etc.) + seção "Novidades" pra avisos da gestão. Pequenos detalhes que afetam **engajamento do atendente**.

### O.8 — 3 botões grandes de status do agente
**Já citado no ponto 9.** Stop/Play/Pausa visíveis e óbvios — não enterrados em menu. Operação não-técnica acha imediato.

### O.9 — Coluna "Tempo desde última mensagem" nas listas
Vista no Painel de Atendimentos. "5d 12h sem resposta" gritando na linha. Frontdesk só mostra timestamp da última msg — o tempo decorrido o agente calcula de cabeça.

### O.10 — Alerta visual da janela 24h do WhatsApp
Banner amarelo dentro da conversa quando passou de 24h. Frontdesk não destaca isso — o agente descobre quando dá erro tentando enviar.

### O.11 — Botões de ação na linha da lista (não só no chat)
Cada conversa na lista do Painel de Atendimentos tem 4 botões: 👤 contato · 💬 atendimento · ⇄ transferir · ✖ encerrar. Frontdesk só permite ação ao **abrir** a conversa. Ações em lote / por linha ganhariam tempo.

### O.12 — Resumo em badges no topo da lista
"🔴 39 / 🟠 98 / 🟢 100" sempre visível. Frontdesk tem contadores nas abas (Minhas, Não atribuídas, Todos) mas não por status semântico (esperando / em atendimento / pausada).

### O.13 — Modal "Visualizar Conversa" como leitura admin (sem entrar na conversa)
Admin abre, vê histórico, manda nota privada pro agente — sem assumir nem atrapalhar. Hoje no Frontdesk pra ver uma conversa tem que abrir efetivamente (e o agente vê que alguém está olhando).

### O.14 — Aviso de "Exclusão de dados" / retenção
Modal de boas-vindas pro admin: "A cota de armazenamento foi excedida e uma limpeza automática foi agendada para 31/05/2026. Atendimentos antigos serão apagados". Política de retenção explícita. Frontdesk não tem isso surfaceado.

### O.15 — Sidebar de canais com cor de status
Visão do admin tem lista de canais (API OFICIAL, Reserva Boletos, Facebook, Instagram) com **dot colorido** ao lado (verde / azul / cinza) indicando saúde da integração. Frontdesk lista inboxes mas sem status de saúde visual.

---

## 2.B Oportunidades DESCOBERTAS NO DEEP-DIVE (não no scan inicial)

> Estas só apareceram quando entrei em Configurações de fato. Não estavam nos 17 pontos, mas são significativas.

### O.16 — Role "Supervisora" (intermediário entre Admin e Atendente) — ★ GAP estrutural
**Visto em**: `Configurações > Usuários` (kualiz-10).
**O que é**: o Kualiz tem **3 roles** (Administrador 5 · Supervisora 8 · Atendente 12). A Supervisora pode acompanhar produtividade e atendimentos do time mas não tem poder de mudar configs do sistema. O Frontdesk só tem **2 roles** (administrator/agent) — admin tem TUDO, agent tem só a operação.

**Impacto**: Mais Saúde tem **8 supervisoras**. Hoje no Frontdesk elas viraram admin → têm acesso a coisas que não deveriam. Falta o nível intermediário.

**Plano de paridade (P2)**:
- Criar `accounts.account_users.role = supervisor` (extender enum: administrator/supervisor/agent).
- Em `custom/app/models/concerns/klaos_supervisor_role.rb` (concern prepended em AccountUser).
- Permissões granulares: ver Painel de Agentes + Painel de Atendimentos + Relatórios; SEM editar configs/integrações/agentes.

### O.17 — Permissões granulares por usuário (com toggle)
**Visto em**: `Configurações > Usuário expandido > Permissões` (kualiz-12).
**O que é**: cada usuário tem aba dedicada de Permissões (toggles tipo "Gestão de tarefas"). Sistema preparado pra granularidade fina, não roles fixos.

**Plano de paridade (P3)**: extender o modelo de Frontdesk com permissões granulares opcionais sobre o role. Por exemplo, um Atendente que pode editar etiquetas (sem virar admin).

### O.18 — Notificações Push por dispositivo com revogação manual — ★ governance
**Visto em**: `Configurações > Usuário > Notificações Push` (kualiz-13).
**O que é**: cada usuário lista os **dispositivos registrados pra receber push** (com validade do token de sessão). O admin pode **revogar manualmente** — usuário deixa de receber notificações naquele device até relogar.

**Impacto**: governance de tokens. Útil pra LGPD/segurança (devolvimento de dispositivo de funcionário desligado).

**Plano de paridade (P3)**: surfacar a tabela `notification_subscriptions` do Chatwoot (já existe) com UI de listagem + botão de revogar. Backend já tem (Chatwoot), falta só UI.

### O.19 — Tipos de Pausa configuráveis com tempo máx + cota/dia + alerta — ★★ FEATURE GOLD
**Visto em**: `Configurações > Pausas` (kualiz-15).
**O que é**: o admin **cadastra os motivos de pausa permitidos** (Almoço 60min×1/dia, ALMOÇO 30M 30min×1/dia, Banheiro 5min×3/dia, Reunião 1440min×10/dia). Cada motivo tem:
- **Tempo máximo** por pausa (em minutos).
- **Vezes por dia** permitidas.
- **Ação quando estoura**: "Alertar" (notifica admin).

**Quando o agente entra em pausa, ele escolhe o motivo da lista** — não é texto livre. Resulta em **operação rastreável** (Painel de Agentes mostra o motivo e o tempo atual).

**Impacto**: gestão de SLA/produtividade real. Frontdesk hoje tem só `availability_status = busy` sem motivo/tempo/cota.

**Plano de paridade (P2)**:
- Nova entidade `klaos_pause_reasons` (motivo, max_minutes, max_per_day, action).
- Modelo `klaos_agent_pause_event` (agente, motivo, started_at, ended_at, exceeded).
- UI: dropdown na hora de pausar (em vez de só "ficar busy"), + listagem no Painel de Agentes mostrando motivo + tempo restante, + alerta automático quando passa o limite.
- Tudo em `custom/` — zero toque em upstream Chatwoot.

### O.20 — Backup local de atendimentos antigos + política de retenção
**Visto em**: modal "Exclusão de dados" + `Configurações > Geral > Backup e Housekeeping` (mencionada).
**O que é**: o Kualiz mostra **proativamente** que a cota de storage está sendo excedida e que vai apagar atendimentos antigos em data específica. Admin pode fazer **backup local** em Configurações > Geral antes que apague.

**Plano de paridade (P3)**: surfacar política de retenção do Frontdesk + endpoint de export por inbox/período. Não é P0 mas é higiene de dados.

### O.21 — Botões "Reiniciar servidor" / "Apagar caches locais" no admin
**Visto em**: `Configurações > Geral` (kualiz-16).
**O que é**: admin tem botões diretos:
- "Atualizar licença"
- "Apagar caches locais"
- "Reiniciar servidor"
- "Reiniciar servidor e invalidar sessões"

**Não vamos trazer isso** — no Frontdesk admin não deve poder reiniciar o servidor (a infra é Railway, separada). Mas **invalidar sessões** seria útil ("forçar logout de todos" em incidentes de segurança). Considerar P4.

### O.22 — Aba "IA" + Aba "Telefonia" em Configurações > Geral
**Visto em**: `Configurações > Geral` (kualiz-16, tabs no topo).
**O que é**: Kualiz tem **abas dedicadas pra IA e Telefonia** dentro da config global. Sugere que IA é built-in (não é "integração externa" como o nosso KLaOS) e Telefonia (canal de voz) é parte do sistema.

**Implicação pro Frontdesk**: nosso modelo de IA externa (KLaOS) e canal-só-WhatsApp é compatível, mas o Gustavo está acostumado com **menu mental** que tem IA + Voz integrados. Não é gap funcional, é **mapa mental** — explicar pra ele que no Frontdesk a IA mora num produto irmão (KLaOS) e a voz é roadmap futuro.

### O.23 — Integração BigQuery nativa pra analytics
**Visto em**: `Configurações > Geral > Configuração Geral` (kualiz-16, seção "Integração BigQuery").
**O que é**: campos pra Auth Key + Project ID do BigQuery. Exporta dados de atendimento pra warehouse. **Toggle**: "Excluir registros atualizados" (presumo: pula re-export de registros já mandados).

**Plano de paridade (P4)**: avaliar custo/benefício. Mais Saúde provavelmente não usa BigQuery hoje. Se for relevante no futuro, exportador modular.

### O.24 — Configuração "Bloquear criar contatos com mesmo número"
**Visto em**: `Configurações > Geral` (kualiz-16, checkbox).
**O que é**: opção pra impedir duplicação de contatos por número. Defensive UX.

**Plano de paridade (P2)**: Frontdesk hoje **permite** duplicar contato com mesmo número (já vi acontecer). Adicionar validação custom no `Contact` antes de create.

### O.25 — Cap de licença explícito + chave global de API
**Visto em**: `Configurações > Geral` (kualiz-16).
**O que é**: admin vê quantos slots de Agente/Supervisor/Admin estão usados vs comprados ("Agentes: 12 - Sup/Adms: 50"). E tem uma **Chave global de API** pra integrar com sistemas externos (não a chave por usuário).

**Plano de paridade**: Frontdesk tem API tokens por usuário. Chave global ficaria como P4 (raramente precisa).

### O.26 — Documentação da API acessível direto da config (devexp)
**Visto em**: `Configurações > Filas` botão topo direito "Documentação da API" (kualiz-14).
**O que é**: link direto pra documentação da API ao lado do "+ Adicionar". Quando admin vai criar fila via API, encontra a doc na hora.

**Plano de paridade (P3)**: link pra docs da API do Frontdesk nas telas relevantes. Pequeno toque de devexp.

---

## 3.0 — Onda 1 (entrega rápida) com filtro multi-tenant aplicado

> Resultado da reavaliação de 2026-05-28: dos 9 pontos do Gustavo + 12.3 (envio de imagem), 7 viram itens de **Onda 1** — esforço Trivial/Pequeno/Médio, baixo risco, podem entrar em DEV → Playwright pesado → PROD individualmente. Cada um foi passado pelo **filtro multi-tenant** (§ Princípio crítico) e **filtro de reaproveitamento Chatwoot**.
>
> **Ordem de execução** (do mais barato/seguro → mais arriscado):

| # | Item Gustavo | Capability genérica (multi-tenant) | Onde mora a config por conta | Reusa do Chatwoot |
|---|---|---|---|---|
| 1 | **9** — sempre online | Toggle "Manter agentes online até logout manual" (impede `auto_offline` automático) | `account.custom_attributes[:auto_offline_default]` (boolean) + checkbox em Configurações → Geral | ✅ Reusa `account_user.auto_offline` (campo já existe) — só sobrescreve default via concern prepended em `AccountUser` |
| 2 | **10** — "Não atribuídas" | Rótulo customizável da aba "Não atribuídas" | `account.custom_attributes[:unassigned_label]` (string, default `nil` → fallback i18n nativo) + campo em Configurações → Geral | ✅ Reusa label nativo — getter custom em Vue retorna override se presente |
| 3 | **6** — `*` = negrito WhatsApp | Toggle "Single-asterisk = bold no editor WhatsApp" (default `true` para inboxes WhatsApp Cloud) | `inbox.custom_attributes[:single_asterisk_bold]` (boolean, default `true` para WhatsApp Cloud, `false` para outros canais) | ✅ Reusa `Messages::MarkdownRenderers::WhatsAppRenderer`, prepended para swap `emph`↔`strong` quando flag ativa |
| 4 | **11** — busca sem acento | **Sem config** — sempre on. Habilitar `unaccent` no PG e usar em todas as buscas de contato/conversa | n/a (multi-tenant nato — beneficia todos sem ligar nada) | ✅ Reusa query do `Api::V1::Accounts::ContactsController#index`, prepend só substitui `ILIKE` por `unaccent ILIKE unaccent` |
| 5 | **1** — protesto no topo dos templates | Investigar por que esfriou + **pino manual por usuário** (template fixado fica acima da ordenação por frequência) | `account_user.ui_settings[:pinned_templates]` (array de IDs) — cada agente pina o seu | ✅ Reusa `top_templates_controller` custom já existente, estende com pin override |
| 6 | **2** — auto-atribuir template ativo | Toggle "Auto-atribuir conversa ao remetente ao enviar template ativo" (default `false`) | `account.custom_attributes[:auto_assign_on_template_send]` (boolean) + checkbox em Configurações → Geral | ✅ Reusa `Conversation#assignee_id` (campo nativo) — hook `after_create` em Message customizado |
| 7 | **12.3** — envio de imagem + ✓✓ | **Sem config** — sempre on. Estender resilience de upload para image (igual áudio) + validar webhook status Meta em prod | n/a (multi-tenant nato) | ✅ Reusa `MessageMeta.vue` nativo (✓✓) + pattern de `whatsapp/cloud_service_resilience.rb` que já fizemos pra áudio |

### Ciclo por item (regra fixa)

Para **CADA** linha da tabela acima:

1. **Explicar antes** — Claude detalha aqui no chat: arquivos exatos tocados, riscos, plano de teste. Matheus aprova/ajusta.
2. **Implementar em `klaos-dev`** (regra fixa — nunca direto em prod).
3. **Deploy DEV** (push → Railway redeploy automático).
4. **Playwright pesado**:
   - Login no Frontdesk dev (`app-desk-dev.klaos.ai`)
   - Login no Kualiz (`gustavo` / `Atendmedbh756`) para comparar UX lado-a-lado quando faz sentido
   - Cenários: golden path + edge cases + regressão (verificar que feature não quebrou cliente sem o toggle ligado)
5. **Reportar** com prints.
6. **Aprovação explícita** do Matheus para subir a prod.
7. **Merge `klaos-dev` → `klaos-production`** + deploy.
8. **Smoke test em PROD** com login real.
9. Próximo item.

### Onda 2 (entrega depois — aprovação explícita)

Tudo do §2 e §2.B. Filtro multi-tenant já aplicado nos itens grandes (O.1 Painel de Agentes, O.16 Role Supervisora, O.19 Pausas tipadas) — todos genéricos para qualquer cliente. Detalhe modular na tabela do §3 abaixo.

---

## 3. Plano de paridade (prioridade × esforço × **localização modular**)

> Cada item indica **onde o código vive** pra sobreviver a `git merge upstream/master`. Veja §0.5 (princípio modular).

| Item | Prioridade | Esforço | Onde vive (upstream-safe) |
|---|---|---|---|
| 9 — sempre online (`auto_offline=false` pros agentes Mais Saúde) | **P0** | Trivial (DB) | SQL one-time + opcional `custom/config/initializers/account_user_auto_offline_default.rb` (default false p/ accs específicas) |
| 8.1 — passo-a-passo admin | **P0** | Trivial | `docs/para-frontdesk-agent/RESPOSTAS_GUSTAVO_v2.md` (já entregue) |
| 10 — renomear "Não atribuídas" → "IA" (acc 9/10) | **P1** | Pequeno | `custom/vite/klaos-patches.js` (string-replace na string i18n, condicional por accountId no componente que usa) |
| 11 — busca sem acento | **P1** | Pequeno | `custom/app/controllers/api/v1/accounts/contacts_controller_unaccent.rb` (prepend `Api::V1::Accounts::ContactsController`, override do search query) + migration custom habilita `unaccent` extension em `custom/db/migrate/` |
| 2 — auto-atribuir conversa ao remetente | **P1** | Médio | `custom/config/initializers/auto_assign_on_template_send.rb` (hook `after_create` em Message quando `message_type=outgoing` AND `is_template`, set `conversation.assignee_id ||= sender_id`) |
| 6 — `*` = negrito estilo WhatsApp | **P1** | Pequeno | `custom/app/services/messages/markdown_renderers/whats_app_renderer_klaos.rb` + initializer prependa `Messages::MarkdownRenderers::WhatsAppRenderer`, swap `emph`↔`strong` outputs |
| 1 — verificar/reposicionar template "protesto" | **P1** | Pequeno | Investigação em `custom/app/controllers/api/custom/v1/accounts/usage_frequents_controller.rb` (já custom) + eventual hook de pino: nova coluna `pinned` em CustomFilter ou metadata em accounts.custom_attributes |
| 12.3 — envio de imagem (erro + ✓✓) | **P1** | Médio | `custom/app/services/whatsapp/cloud_service_resilience.rb` (já existe — estender pra image upload retry/content-type, igual fizemos pra audio). ✓✓ visíveis já são nativos (`MessageMeta.vue` upstream) — validar webhook Meta. |
| 7 — reabertura/som/bolinha | **P1** | Pequeno | Reabertura já tem em `custom/config/initializers/lock_single_conversation_default.rb`; som = config por agente + push_flags (script ad-hoc); doc no `RESPOSTAS_GUSTAVO_v2.md` |
| **O.1** — Painel de Agentes (supervisão real-time) | **P2** | Grande | `app/javascript/dashboard/components-next/KlaosSupervisor/AgentsPanel.vue` (componente novo) + `custom/app/controllers/api/custom/v1/accounts/supervisor_controller.rb` (endpoint com stats por agente em tempo real, websocket-aware) + `custom/config/initializers/supervisor_routes.rb` + 1 patch em `klaos-patches.js` pra adicionar item de sidebar |
| **O.8** — 3 botões grandes status agente | **P2** | Médio | Componente novo `KlaosAgentStatusButtons.vue` em `components-next/KlaosAgentStatus/` + patch em `klaos-patches.js` injetando no header (provavelmente `Sidebar.vue` ou `App.vue`) |
| **O.9** — coluna "Tempo desde última msg" | **P2** | Médio | Patch em `klaos-patches.js` no `ConversationCard.vue` adicionando computed + render do tempo decorrido. Sem backend novo (campo `last_activity_at` já existe). |
| **O.10** — alerta janela 24h | **P2** | Médio | Componente `KlaosWindow24Banner.vue` em `components-next/KlaosWindow24/` + patch em `klaos-patches.js` injetando no topo da `MessagesView.vue`. Cálculo: `last_inbound_at + 24h < now`. |
| **O.7** — cronômetro turno + frase motivacional | **P3** | Médio | Componente `KlaosShiftTimer.vue` + componente `KlaosMotivationalQuote.vue` em `components-next/KlaosAgentHome/`. Patch injeta na home do agente. |
| **O.5** — tarefas + agendamentos | **P3** | Grande | Nova entidade. Modelos em `custom/app/models/klaos_task.rb`, `klaos_appointment.rb` + migrations custom + controllers custom + Vue novo. Zero toque em upstream. |
| **O.11** — ações por linha da lista | **P3** | Médio | Patch no `ConversationCard.vue` adicionando hover-buttons. Lógica reusa endpoints existentes (transfer_to_bot, assign, resolve). |
| **O.2** — Painel de Produtividade | **P3** | Grande | Componente `KlaosProductivity.vue` + controller custom de relatórios em `custom/app/controllers/api/custom/v1/accounts/productivity_reports_controller.rb` |
| **O.4** — Filas com prioridade/capacidade | **P3** | Muito grande | Estender Inbox via `custom/app/models/concerns/klaos_queue_capacity.rb` (concern prepended) + UI patches. Não criar tabela nova se possível. |
| **O.6** — Chat Interno | **P4** | Muito grande | Nova entidade `klaos_internal_chats` em `custom/app/models/`, controllers custom, Vue novo. Isolado de upstream. |
| **O.16** — Role "Supervisora" intermediário | **P2** | Médio | `custom/app/models/concerns/klaos_supervisor_role.rb` (concern em AccountUser) + migration custom estendendo enum role + UI patch pra esconder áreas de config pro supervisor |
| **O.17** — Permissões granulares por usuário | **P3** | Grande | Nova tabela `klaos_user_permissions` em `custom/db/migrate/` + model `klaos_user_permission.rb` + concern em User. Frontend: aba "Permissões" via componente custom |
| **O.18** — Notif Push: revogação por dispositivo | **P3** | Pequeno | Componente Vue novo `KlaosPushDevices.vue` no perfil. Backend reusa `notification_subscriptions` (Chatwoot já tem). Endpoint custom de revoke. |
| **O.19** — Pausas tipadas c/ tempo+cota+alerta ★ | **P2** | Grande | Nova entidade `klaos_pause_reasons` + `klaos_agent_pause_events` (migrations + models em `custom/`) + UI no Painel de Agentes (componente Klaos*) + dropdown na pausa. Integra com `availability_status` nativo. |
| **O.20** — Política de retenção visível + backup | **P3** | Médio | `custom/app/jobs/klaos_retention_alert_job.rb` (calcula quota, dispara modal) + export controller custom |
| **O.21** — Invalidar todas as sessões | **P4** | Pequeno | Endpoint custom em `custom/app/controllers/api/custom/v1/security_controller.rb` que limpa Redis SSO tokens. Usado raramente. |
| **O.22** — IA + Telefonia abas (apenas comunicação) | n/a | n/a | Não é dev — explicar pro Gustavo que a IA mora no produto irmão (KLaOS) e Voz é roadmap. |
| **O.23** — BigQuery export | **P4** | Médio | Job custom em `custom/app/jobs/klaos_bigquery_export_job.rb` se cliente pedir. |
| **O.24** — Bloquear contatos duplicados por número | **P2** | Pequeno | `custom/config/initializers/contact_uniqueness_guard.rb` — `before_create` em Contact, valida número único por inbox |
| **O.25** — Cap de licença visível | **P4** | Pequeno | Já temos `INSTALLATION_PRICING_PLAN_QUANTITY=10000` no Frontdesk. UI pra surfacar. |
| **O.26** — Link "Documentação da API" nas telas | **P3** | Trivial | Patches pequenos em klaos-patches.js |

**Convenção**: P0 imediato, P1 = rotina dev (Mais Saúde), P2 = sprint atual ou próxima, P3 = roadmap próximo trimestre, P4 = avaliar custo/benefício.

**Critério de aceite modular** (aplica a TODO item da tabela): após implementação, rodar `git merge upstream/develop --no-commit --no-ff` num branch limpo de teste e confirmar **zero conflitos em arquivos `app/`, `lib/`, `config/` upstream**. Único arquivo upstream tocado deve ser via `klaos-patches.js` (que não modifica o disco — é build-time).

---

## 4. Próximos passos imediatos

1. **Confirmar com cliente quais P2/P3 entram**: nem tudo do Kualiz precisa virar Frontdesk. Apresentar o quadro acima e o Gustavo escolhe o que prioriza.
2. **Wireframe da tela "Painel de Agentes"** (O.1) — pedir aprovação visual antes de codar (cores KLaOS aplicadas).
3. **Replicar paleta de status** (verde/amarelo/vermelho consistente) onde já mostramos estado de agente / conversa / canal — coerência visual com o que o Gustavo já está acostumado.
4. **Pinar templates** (ponto 1 + oportunidade): adicionar ícone de pino além da ordenação por frequência.
5. **Validar webhook de status Meta** em prod pra confirmar ✓✓ ao vivo (ponto 12).

---

## 5. Anexos — screenshots capturadas nesta sessão

Pasta: `docs/internal/screenshots/`

### 5.1 Telas principais (mapeamento inicial)
| # | Tela | Arquivo |
|---|---|---|
| 01 | Login do Kualiz v12.1.7 | [kualiz-01-login.png](./screenshots/kualiz-01-login.png) |
| 02 | KPI Dashboard (admin) | [kualiz-02-kpi-dashboard.png](./screenshots/kualiz-02-kpi-dashboard.png) |
| 03 | ★ Painel de Agentes (real-time grid) | [kualiz-03-painel-agentes.png](./screenshots/kualiz-03-painel-agentes.png) |
| 04 | ★ Painel de Atendimentos (todas as conversas) | [kualiz-04-painel-atendimentos.png](./screenshots/kualiz-04-painel-atendimentos.png) |
| 05 | Modal "Visualizar Conversa" (admin read-only) | [kualiz-05-abrir-atendimento.png](./screenshots/kualiz-05-abrir-atendimento.png) |
| 06 | Agente Dashboard (Gerenciar filas + turno + status) | [kualiz-06-agente-dashboard.png](./screenshots/kualiz-06-agente-dashboard.png) |
| 07 | Submenu "Painel de Filas" (Filas / Minhas tarefas / Meus agendamentos) | [kualiz-07-painel-filas.png](./screenshots/kualiz-07-painel-filas.png) |
| 08 | Filas submenu (detalhe) | [kualiz-08-filas-submenu.png](./screenshots/kualiz-08-filas-submenu.png) |

### 5.2 Deep-dive em Configurações (admin)
| # | Tela | Arquivo |
|---|---|---|
| 09 | Menu de Configurações (14 seções) | [kualiz-09-configuracoes-menu.png](./screenshots/kualiz-09-configuracoes-menu.png) |
| 10 | Config > Usuários (3 roles: Admin 5 / Supervisora 8 / Atendente 12) | [kualiz-10-config-usuarios.png](./screenshots/kualiz-10-config-usuarios.png) |
| 11 | Config > Usuário expandido (4 abas: Geral/Permissões/Notif Push/Variáveis) | [kualiz-11-user-expanded.png](./screenshots/kualiz-11-user-expanded.png) |
| 12 | Config > Usuário > Permissões (toggle "Gestão de tarefas") | [kualiz-12-user-permissoes.png](./screenshots/kualiz-12-user-permissoes.png) |
| 13 | Config > Usuário > Notificações Push (lista de dispositivos + revogar) | [kualiz-13-user-notif-push.png](./screenshots/kualiz-13-user-notif-push.png) |
| 14 | Config > Filas (com badge "WA", status "Autenticado", "Doc da API") | [kualiz-14-config-filas.png](./screenshots/kualiz-14-config-filas.png) |
| 15 | ★ Config > Pausas (motivos tipados c/ tempo máx + cota dia + alerta) | [kualiz-15-config-pausas.png](./screenshots/kualiz-15-config-pausas.png) |
| 16 | ★ Config > Geral (5 abas: Geral / Segurança / Backup&Housekeeping / IA / Telefonia) | [kualiz-16-config-geral.png](./screenshots/kualiz-16-config-geral.png) |

### 5.3 Honestidade — o que ficou de fora desta varredura
Para o SDD ser fonte real (não chute), explicito o que **eu vi** vs o que ainda **inferi**:

**Vi de verdade (observação direta + DOM via evaluate)**:
- Login · KPI Dashboard · Painel de Agentes · Painel de Atendimentos · Modal Visualizar Conversa · Agente Dashboard · Submenu Painel de Filas
- Configurações: menu completo (14 seções) · Usuários (lista + 4 abas internas: Geral/Permissões/Notif Push/Variáveis) · Filas (lista) · Pausas (lista com tempo/cota/ação) · Geral (visão da aba Geral com 5 sub-abas no topo)

**Não consegui entrar (limite read-only / clique não navegou / tempo)**:
- Tela do agente atendendo de fato (não posso tirar o agente Gustavo da pausa — viola "não modificar nada").
- Chat ao vivo dentro de uma fila ativa (idem).
- Composer do agente (negrito `*` ao vivo) — depende da tela acima.
- Seletor de templates dentro do composer — idem.
- Contatos (não navegou via top-bar nesta sessão; URL chutei errado).
- Painel de Produtividade (aba ao lado de Painel de Agentes — só vi a aba existe).
- Relatórios (top-bar) — só sei que existe.
- CRM / Tarefas / Chat Interno / Notificações — só item de menu visto.
- Configurações > Filas/Pausas com formulário de criação aberto (não cliquei + pra não criar nada).
- Configurações > sub-abas: Segurança, Backup&Housekeeping, IA, Telefonia (vi os nomes das abas, não entrei).
- Configurações > Cadastros / Etiquetas / Grupos / Automação / Monitoramento de Produtividade / Log de Auditoria / CRM e Tarefas / Campanhas (vi nome no menu, não entrei).

**Plano**: cada item do §3 que for entrar em rotina de implementação tem uma **flag de verificação prévia** — antes de codar, voltar ao Kualiz na tela específica pra **confirmar com observação direta** (não premissa). Sessão atual é o **mapa do território**, não o cadastro de cada rua.

---

**Manutenção**: este SDD evolui à medida que pegamos mais detalhe do Kualiz / mais retorno do Gustavo. Atualizar a tabela do §3 conforme itens são entregues.
