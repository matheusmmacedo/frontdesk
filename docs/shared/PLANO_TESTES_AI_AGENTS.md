# Plano de Testes — KLaOS AI Agents

| Campo | Valor |
|---|---|
| Versão | 1.0 |
| Data | 2026-04-22 |
| Responsável QA | Davi Felix |
| Autor do plano | Matheus Macedo |
| Produto | KLaOS AI Agents (módulo do KLaOS Platform) |
| Ambiente principal | Dev (`app-dev.klaos.ai`) + Prod (`app.klaos.ai`) |
| Workspace de referência | Mais Saúde 24h (agente "Lara"), GMB (agentes Klaus/Iris/Klaus Ross), E-Cassini |

---

## 1. Escopo

### 1.1 Incluído
- Criação, configuração e publicação de agentes de IA.
- Templates pré-built (Klaus, Iris, Lara, Cassini).
- Knowledge Base (RAG).
- Playground de teste.
- Handoff bot → humano (regras, triggers).
- TTS (voz), multimodal (imagem, áudio).
- Integração com CRM e Frontdesk.
- Métricas, logs, ambientes.

### 1.2 Fora de escopo
- Backend LLM, escolha de modelo a nível técnico (dev).
- Frontdesk (plano dedicado).
- CRM (plano dedicado).
- Jornadas end-to-end (plano Integração).

### 1.3 Estado atual
**AI Agents: ~80% implementado**. Algumas áreas parciais (handoff, ambientes dev/prod separados, multimodal áudio STT). Marcadas com 🟡 ao longo.

---

## 2. Perspectivas de teste

| Perspectiva | Uso típico | Features principais |
|---|---|---|
| **Admin KLaOS** | Cria e configura agentes pro workspace | Criação, config, prompt, tools, knowledge base, publishing |
| **Operador (usa agente em produção)** | Monitora conversas do bot, intervém quando preciso | Métricas, logs, handoff |
| **Cliente final (usuário do bot)** | Conversa com Lara/Klaus via WhatsApp/Web | Experiência do chat, qualidade de resposta |
| **Super Admin KLaOS** | Mantém templates globais, audita | Templates pré-built, analytics cross-workspace |

### 2.1 Credenciais
Mesma lógica (emails próprios do Davi não cadastrados no KLaOS). O QA vai:
- Criar agentes de teste no workspace Mais Saúde dev (com prefixo "QA" no nome pra não confundir)
- Usar WhatsApp próprio como "cliente final" pra conversar com os agentes

### 2.2 Dados seed
- Pelo menos 1 agente do template Klaus configurado
- 1 Knowledge Base com 3-5 documentos (PDF, docx)
- 1 inbox Frontdesk com bot vinculado (pra testar publishing)
- Credenciais OpenAI/Anthropic válidas em dev (Matheus fornece)

### 2.3 Ferramentas
- Browser Chrome/Edge
- WhatsApp pessoal (pra testar respostas do bot real)
- Microfone + fone (pra testar TTS e áudio)
- Gravação de tela

---

## 3. Formato dos TCs
Mesmo padrão (User Story + ACs + TC table + detalhes dos Críticos).

---

## 4. Critérios de saída
Mesmos (100% Crítica Pass, etc).

---

## 5. Features

### 5.1 Feature: Criação de agente (wizard)

#### 5.1.1 User Story
> Como **admin**, quero **criar um novo agente de IA com um wizard passo a passo (template → nome → prompt → tools → revisão)**, para **colocar um bot operando sem precisar entender LLM a fundo**.

#### 5.1.2 Critérios de Aceitação

- **AC-1.1**: `Agentes → Novo Agente` abre wizard de 5 passos.
- **AC-1.2**: Passo 1 — escolher template (Klaus/Iris/Lara/Cassini/Blank).
- **AC-1.3**: Passo 2 — nome + descrição + slug (auto-gerado mas editável).
- **AC-1.4**: Passo 3 — prompt (simples: perguntas guiadas / avançado: texto livre).
- **AC-1.5**: Passo 4 — tools (marcar quais integrações o agente pode usar: CRM, WhatsApp, etc.).
- **AC-1.6**: Passo 5 — revisão + botão criar.
- **AC-1.7**: Após criar, redireciona pra detalhe do agente em modo "Rascunho" (não ativo).
- **AC-1.8**: Validação em cada passo (campos obrigatórios, nomes únicos).

#### 5.1.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-501 | Wizard completo com template Klaus | Crítica | UI |
| TC-502 | Nome duplicado bloqueia | Alta | UI |
| TC-503 | Slug auto-gerado normalizando acento/espaço | Alta | UI |
| TC-504 | Navegar wizard pra frente e trás preserva dados | Alta | UI |
| TC-505 | Prompt modo avançado aceita texto longo | Média | UI |
| TC-506 | Agente criado fica em Rascunho | Alta | Funcional |

##### TC-501 — Wizard completo com template Klaus

**Passos**:
1. Login admin Mais Saúde
2. `Agentes → Novo Agente`
3. Escolher template "Klaus"
4. Nome "QA Klaus Teste", descrição livre
5. Prompt: manter o do template, modo simples
6. Tools: marcar "CRM Query" e "WhatsApp Templates"
7. Revisar e criar

**Resultado esperado**: agente criado, redireciona pra detalhe; status "Rascunho"; prompt do template Klaus carregado; 2 tools ativas.

---

### 5.2 Feature: Configuração do agente (prompt, modelo, tools)

#### 5.2.1 User Story
> Como **admin**, quero **ajustar configurações do agente após criação (prompt, modelo LLM, tools, temperatura)**, para **refinar comportamento sem recriar**.

#### 5.2.2 Critérios de Aceitação

- **AC-2.1**: Tela de detalhe do agente tem abas: Geral, Prompt, Tools, Knowledge, Testes, Publicação, Métricas.
- **AC-2.2**: Editar prompt e salvar aplica na próxima execução.
- **AC-2.3**: Seletor de modelo: GPT-4o, Claude Opus, Claude Sonnet, etc. (lista configurada).
- **AC-2.4**: Slider de temperatura (0-1).
- **AC-2.5**: Enable/disable tool individual com toggle.
- **AC-2.6**: Histórico de alterações ao prompt (versionamento básico).

#### 5.2.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-510 | Editar prompt e testar aplica | Crítica | Funcional |
| TC-511 | Trocar modelo GPT-4o → Claude Opus | Alta | Integração |
| TC-512 | Ajustar temperatura reflete no playground | Alta | Funcional |
| TC-513 | Disable tool "CRM Query" — agente não usa | Alta | Funcional |
| TC-514 | Versionamento mostra mudanças de prompt | Média | UI |

---

### 5.3 Feature: Knowledge Base (RAG)

#### 5.3.1 User Story
> Como **admin**, quero **subir documentos (PDFs, docx, txt) pra o agente consultar ao responder**, para **ele ter conhecimento específico do meu negócio sem precisar treinar modelo**.

#### 5.3.2 Critérios de Aceitação

- **AC-3.1**: Aba Knowledge permite upload drag-drop de múltiplos arquivos.
- **AC-3.2**: Formatos suportados: PDF, DOCX, TXT, MD. (Confirmar outros)
- **AC-3.3**: Após upload, status: Processando → Indexado / Erro.
- **AC-3.4**: Lista de documentos com nome, tamanho, data, status.
- **AC-3.5**: Deletar documento remove do índice (não volta nas buscas RAG).
- **AC-3.6**: Teste no playground: pergunta sobre conteúdo do documento retorna resposta baseada nele.

#### 5.3.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-520 | Upload PDF 10 páginas — processa e indexa | Crítica | Integração |
| TC-521 | Upload arquivo não suportado (.exe) rejeita | Alta | UI |
| TC-522 | Pergunta sobre conteúdo no playground retorna RAG | Crítica | Funcional |
| TC-523 | Deletar doc — pergunta não retorna mais | Alta | Integração |
| TC-524 | Upload de 10 arquivos simultâneos | Alta | UI |
| TC-525 | Doc com erro de parsing — status Erro claro | Média | UI |

---

### 5.4 Feature: Playground de teste

#### 5.4.1 User Story
> Como **admin/dev**, quero **conversar com o agente diretamente na UI do KLaOS (sem publicar) pra testar respostas**, para **iterar rápido antes de jogar em produção**.

#### 5.4.2 Critérios de Aceitação

- **AC-4.1**: Aba Testes abre chat simulado.
- **AC-4.2**: Escolher canal simulado (WhatsApp, WebWidget) muda formatação.
- **AC-4.3**: Resposta chega em <30s (p95).
- **AC-4.4**: Mostra tool calls executadas e resultado (debug view).
- **AC-4.5**: Resetar conversa limpa contexto.
- **AC-4.6**: Idioma detectado automaticamente conforme a mensagem do teste.

#### 5.4.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-530 | Conversa de 3 turnos com contexto | Crítica | Funcional |
| TC-531 | Tool call visível no debug | Alta | UI |
| TC-532 | Resetar limpa histórico | Alta | UI |
| TC-533 | Pergunta em inglês respondida em inglês | Alta | Funcional |
| TC-534 | Timeout de resposta > 60s mostra erro | Média | Resiliência |

---

### 5.5 Feature: Templates pré-built (Klaus, Iris, Lara, Cassini)

#### 5.5.1 User Story
> Como **admin**, quero **partir de um template pré-configurado com perfil pronto (ex: Klaus = vendas GMB, Lara = cobrança Mais Saúde)**, para **não começar do zero**.

#### 5.5.2 Critérios de Aceitação

- **AC-5.1**: Biblioteca de templates acessível no passo 1 do wizard.
- **AC-5.2**: Cada template tem descrição, caso de uso, preview do prompt.
- **AC-5.3**: Criar a partir de template copia prompt + tools sugeridas.
- **AC-5.4**: Templates são versionados — atualização do template não quebra agentes já criados.

#### 5.5.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-540 | Listar todos templates com preview | Alta | UI |
| TC-541 | Criar a partir de Lara copia config | Alta | UI |
| TC-542 | Editar agente criado de template — não afeta template | Alta | Funcional |

---

### 5.6 Feature: Handoff (bot → humano) 🟡

> **Estado**: implementado parcialmente. Critério de trigger existe, mas ação final (mudar status `pending` → `open` no Frontdesk e atribuir team) **ainda não está funcionando** em prod (incidente identificado em 2026-04: Mais Saúde com 15 conversas presas em pending).

#### 5.6.1 User Story
> Como **admin**, quero **configurar quando o bot deve transbordar pra humano (intenção "falar com atendente", N turnos sem fechar, frustração detectada)**, para **não deixar cliente preso com bot e garantir experiência**.

#### 5.6.2 Critérios de Aceitação

- **AC-6.1**: Aba Handoff permite configurar triggers: palavras-chave, N turnos, confidence score, frustration keywords.
- **AC-6.2**: Ação: atribuir team X, mudar status pra open, postar nota privada.
- **AC-6.3**: Ao disparar, agente para de responder naquela conversa.
- **AC-6.4**: Humano atribuído recebe notificação (via Frontdesk).
- **AC-6.5**: 🟡 **Validar que a integração com Frontdesk dispara os 2 PATCH (toggle_status + assignments)**. Se não dispara, é bug Crítico.

#### 5.6.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-550 | Configurar handoff por palavra-chave "humano" | Alta | UI |
| TC-551 | Cliente manda "quero humano" — bot silencia | **Crítica** | Integração |
| TC-552 | Frontdesk recebe status=open + assignee | **Crítica** | Integração |
| TC-553 | Agente humano é notificado (sininho) | Crítica | Integração |
| TC-554 | Handoff por N=3 turnos sem fechar | Alta | Funcional |
| TC-555 | Nota privada criada explicando motivo | Média | UI |

---

### 5.7 Feature: TTS (Text-to-Speech / Voice)

#### 5.7.1 User Story
> Como **admin**, quero **configurar o agente pra responder com áudio TTS (voz sintetizada)**, para **clientes WhatsApp que preferem áudio e melhorar experiência**.

#### 5.7.2 Critérios de Aceitação

- **AC-7.1**: Aba Voz permite escolher provider (OpenAI, ElevenLabs, etc.), voz específica, velocidade.
- **AC-7.2**: Preview do áudio na UI antes de salvar.
- **AC-7.3**: No playground, agente responde com áudio se configurado.
- **AC-7.4**: Em WhatsApp real, áudio chega como mensagem de voz (não anexo).
- **AC-7.5**: Fix 131053 (áudio Opus) aplicado — áudio é entregue sem erro Meta.

#### 5.7.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-560 | Escolher voz ElevenLabs + preview | Alta | Integração |
| TC-561 | Playground retorna áudio | Alta | Funcional |
| TC-562 | WhatsApp real recebe áudio playable | **Crítica** | Integração |
| TC-563 | Texto longo gera áudio sem truncar | Média | Funcional |
| TC-564 | Alterar velocidade reflete no preview | Baixa | UI |

---

### 5.8 Feature: Multimodal (imagem, áudio)

#### 5.8.1 User Story
> Como **cliente final**, quero **mandar imagem ou áudio pro bot (ex: foto do boleto, áudio descrevendo problema)**, para **o bot entender e responder adequadamente**.

#### 5.8.2 Critérios de Aceitação

- **AC-8.1**: Agente recebe imagem e consegue descrever/agir sobre ela (modelos com vision).
- **AC-8.2**: 🟡 Agente recebe áudio e transcreve via STT — validar se tá funcionando (estado 70%).
- **AC-8.3**: Resposta do bot pode incluir áudio via TTS.
- **AC-8.4**: Formatos suportados: JPG, PNG, MP3, OGG, WEBM.

#### 5.8.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-570 | Mandar foto de boleto — bot identifica | Alta | Funcional |
| TC-571 | Mandar áudio pt_BR — bot transcreve e responde | Alta | Integração |
| TC-572 | Imagem acima do limite — mensagem clara | Média | UI |
| TC-573 | Áudio ruidoso — qualidade de STT aceitável | Baixa | Funcional |

---

### 5.9 Feature: Integração com CRM (tool calls)

#### 5.9.1 User Story
> Como **cliente/SDR**, quero **o bot consultar dados do deal (valor, stage, próxima ação) durante a conversa**, para **dar respostas precisas baseadas no contexto comercial real**.

#### 5.9.2 Critérios de Aceitação

- **AC-9.1**: Tool "Query Deal" disponível pro agente quando habilitada.
- **AC-9.2**: Tool "Create Deal" e "Update Deal Stage" também.
- **AC-9.3**: Cliente pergunta "qual o status do meu caso?" → bot consulta CRM e responde.
- **AC-9.4**: Permissões respeitadas — bot não acessa deals de outros workspaces.

#### 5.9.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-580 | Bot consulta deal do contato atual | Alta | Integração |
| TC-581 | Bot cria deal novo via tool call | Alta | Integração |
| TC-582 | Bot tenta acessar deal de outro workspace — bloqueado | Crítica | Segurança |
| TC-583 | Tool call falhar — bot responde com fallback humano | Média | Resiliência |

---

### 5.10 Feature: Métricas e Analytics

#### 5.10.1 User Story
> Como **admin/gestor**, quero **dashboard com métricas do agente (conversas, turnos médios, taxa de handoff, CSAT)**, para **avaliar qualidade e ROI**.

#### 5.10.2 Critérios de Aceitação

- **AC-10.1**: Aba Métricas mostra cards com: total conversas, turnos médios, taxa de handoff, tempo médio de resposta.
- **AC-10.2**: Gráfico temporal dos últimos 7/30 dias.
- **AC-10.3**: Top 5 tools mais chamadas.
- **AC-10.4**: Filtro por canal (WA, Web).

#### 5.10.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-590 | Dashboard carrega com dados | Alta | UI |
| TC-591 | Filtrar últimos 7 dias | Alta | UI |
| TC-592 | Zero dados mostra mensagem | Média | UI |
| TC-593 | Taxa de handoff bate com realidade | Alta | Funcional |

---

### 5.11 Feature: Logs de execução

#### 5.11.1 User Story
> Como **dev/admin**, quero **ver logs das execuções do agente (cada turno, cada tool call, cada erro)**, para **debugar comportamento inesperado**.

#### 5.11.2 Critérios de Aceitação

- **AC-11.1**: Aba Logs mostra última N execuções com timestamp, conversa, turno, tokens, tool calls.
- **AC-11.2**: Clicar em turno expande detalhes: prompt enviado, resposta, tool results.
- **AC-11.3**: Filtro por erro, por conversa, por tool.
- **AC-11.4**: Export CSV de logs pra auditoria.

#### 5.11.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-600 | Lista recentes com info básica | Alta | UI |
| TC-601 | Expandir turno mostra prompt completo | Alta | UI |
| TC-602 | Filtrar só erros | Alta | UI |
| TC-603 | Export CSV de 100 logs | Média | UI |

---

### 5.12 Feature: Ambientes (dev vs prod) 🟡

> **Estado**: separação lógica existe, mas UI pra promover dev → prod ainda não tá completa.

#### 5.12.1 User Story
> Como **admin**, quero **testar agente em dev e promover pra prod quando aprovado**, para **não quebrar clientes com mudanças não testadas**.

#### 5.12.2 Critérios de Aceitação

- **AC-12.1**: 🟡 Agente tem atributo "ambiente" (dev/prod).
- **AC-12.2**: 🟡 Alterações em dev não afetam prod.
- **AC-12.3**: 🟡 Botão "Promover pra prod" copia config.
- **AC-12.4**: 🟡 Rollback possível.

#### 5.12.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-610 | Editar dev não afeta prod | 🟡 Alta | Funcional |
| TC-611 | Promover dev → prod | 🟡 Alta | Funcional |
| TC-612 | Rollback volta versão anterior | 🟡 Média | Funcional |

> **Nota pro Davi**: essa área está em construção. Se feature não estiver disponível na UI ainda, marcar TCs como "Blocked — não implementado".

---

### 5.13 Feature: Publicação (ativar agente em inbox Frontdesk)

#### 5.13.1 User Story
> Como **admin**, quero **ativar o agente pra começar a atender**, para **ele sair do estado rascunho e efetivamente responder clientes no Frontdesk**.

#### 5.13.2 Critérios de Aceitação

- **AC-13.1**: Aba Publicação tem botão "Ativar" visível quando agente tá em Rascunho.
- **AC-13.2**: Ao ativar, sistema chama Frontdesk Platform API criando `agent_bot` com o outgoing_url correto (`/webhooks/chatwoot-bot/<uuid>`).
- **AC-13.3**: Bot aparece como opção pra vincular a uma inbox no Frontdesk (§5.25 do plano Frontdesk).
- **AC-13.4**: Desativar agente no KLaOS deve também remover/invalidar bot no Frontdesk.
- **AC-13.5**: Reativação após desativação não duplica bot no Frontdesk (idempotência).

#### 5.13.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-620 | Ativar agente — aparece no Frontdesk | Crítica | Integração |
| TC-621 | Bot recebe webhook quando vinculado | Crítica | Integração |
| TC-622 | Desativar agente — bot some/inativa | Alta | Integração |
| TC-623 | Reativar — não duplica | Alta | Integração |

> **Contexto pro Davi**: em 2026-04 teve incidente onde `reprovisionChatwootBot` deletava e recriava bots, causando ID desalinhado entre KLaOS e Frontdesk (bots "fantasmas" id=79, 80 referenciados pelo KLaOS mas inexistentes no Chatwoot). Corrigido com dedup por outgoing_url. Esse TC valida a correção.

---

### 5.14 Feature: Detecção automática de idioma

#### 5.14.1 User Story
> Como **cliente final**, quero **mandar mensagem em português ou inglês e o bot responder no mesmo idioma**, para **experiência natural sem configuração manual**.

#### 5.14.2 Critérios de Aceitação

- **AC-14.1**: Agente detecta idioma da mensagem do cliente (pt, en, es principal).
- **AC-14.2**: Responde no idioma detectado.
- **AC-14.3**: Troca de idioma no meio da conversa é acompanhada.
- **AC-14.4**: Override manual via config do agente (força pt_BR mesmo que cliente escreva em en).

#### 5.14.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-630 | Cliente em pt — resposta pt | Crítica | Funcional |
| TC-631 | Cliente em en — resposta en | Crítica | Funcional |
| TC-632 | Troca pt→en mid-conversa | Alta | Funcional |
| TC-633 | Override força pt | Média | Funcional |

> **Contexto**: em 2026-04 Klaus (agente GMB) respondia em pt mesmo pra mensagens em en — problema de prompt no KLaOS, não Frontdesk. Esse TC valida.

---

### 5.15 Feature: Frontdesk Bridge (provisionamento e webhook)

Ver também §5.25, §5.26 do plano Frontdesk. Aqui foca na perspectiva do admin **dentro** do KLaOS.

#### 5.15.1 User Story
> Como **admin KLaOS**, quero **que ao criar um agente no KLaOS ele automaticamente vire disponível no Frontdesk pra meu admin do workspace escolher**, para **eliminar coordenação manual entre os 2 sistemas**.

#### 5.15.2 Critérios de Aceitação

- **AC-15.1**: Criar agent_instance → chamada automática pra Platform API do Frontdesk cria `agent_bot`.
- **AC-15.2**: Nome segue convenção `<display_name> | <slug>` quando necessário pra unicidade.
- **AC-15.3**: `outgoing_url` único por agent_instance garantindo roteamento correto.
- **AC-15.4**: `access_token` do bot é sincronizado com o KLaOS pra poder postar respostas (fix de 2026-04-21).
- **AC-15.5**: Alteração de nome no KLaOS reflete no Frontdesk via call de update.

#### 5.15.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-640 | Criar agente — bot aparece no Frontdesk em <30s | Crítica | Integração |
| TC-641 | Agente KLaOS responde usando access_token correto | **Crítica** | Integração |
| TC-642 | Rename KLaOS reflete no Frontdesk | Alta | Integração |
| TC-643 | Deletar KLaOS remove bot Frontdesk | Alta | Integração |

> **Contexto pro QA**: TC-641 testa o fix do bug de 2026-04-21. Antes, quando KLaOS trocava `frontdesk_chatwoot_bot_id` mas não o `access_token`, as respostas do Klaus Ross saíam como se fossem do Klaus (sender_id errado). QA deve confirmar que a mensagem postada pelo bot aparece atribuída ao bot correto no Frontdesk.

---

## 6. Anexos

### Anexo A — Template dos agentes pré-built
_(lista detalhada dos prompts padrão de Klaus, Iris, Lara, Cassini — pedir pro product)_

### Anexo B — Sign-off
| Papel | Nome | Data | Assinatura |
|---|---|---|---|
| QA Lead | Davi Felix | | |
| Product | Matheus Macedo | | |
| AI Lead | | | |
