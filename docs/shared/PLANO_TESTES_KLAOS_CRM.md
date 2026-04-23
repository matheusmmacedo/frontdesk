# Plano de Testes — KLaOS CRM

| Campo | Valor |
|---|---|
| Versão | 1.0 |
| Data | 2026-04-22 |
| Responsável QA | Davi Felix |
| Autor do plano | Matheus Macedo |
| Produto | KLaOS CRM (módulo do KLaOS Platform) |
| Ambiente principal | Dev (`app-dev.klaos.ai`) + Prod (`app.klaos.ai`) |
| Repositório | `matheusmmacedo/klaos` — branch `dev` |
| Workspace de referência | Mais Saúde 24h |

---

## 1. Escopo

### 1.1 Incluído
- Módulo CRM do KLaOS: pipelines, deals, leads, contatos, empresas, tarefas, email, campos custom, tags, scoring, agendamento, permissões, notificações, analytics.
- UI de admin (configuração) e UI de usuário operacional (SDR/Closer/Gestor).
- Integração com Frontdesk via CRM Bridge (push de deal data pra conversas).

### 1.2 Fora de escopo
- Frontdesk (plano dedicado).
- AI Agents (plano dedicado).
- Lógica LLM e tool calls (plano AI Agents).
- Jornadas end-to-end cruzando 3 engines (plano de Integração).

### 1.3 Estado atual (spot-check)
- **CRM: ~85% implementado**. Algumas features secundárias em parcial. Marcadas ao longo do doc com 🟡.

---

## 2. Perspectivas de teste

Davi testa CRM cobrindo **4 perspectivas**:

| Perspectiva | Uso típico | Features principais |
|---|---|---|
| **SDR / pré-vendedor** | Trabalha leads entrando, qualifica, passa pra closer | Inbox de leads, scoring, conversão em deal, agendamento |
| **Closer / vendedor** | Fecha deals que SDR passou, gerencia pipeline | Kanban, detalhes do deal, tarefas, email, follow-up |
| **Gestor / admin do workspace** | Configura pipelines, permissões, relatórios | Pipeline setup, custom fields, tags, permissions, analytics |
| **Super Admin KLaOS** | Backoffice, suporte, auditoria | Acesso cross-workspace, logs, investigação |

### 2.1 Credenciais e acessos
Mesma lógica do plano Frontdesk: Davi usa **emails próprios dele ainda não cadastrados no KLaOS** pra simular SDR/closer/admin novos conforme TCs.

| Papel | Como obter |
|---|---|
| Super Admin | Matheus fornece |
| Admin do workspace Mais Saúde | `matheus@matheus.pro.br` ou conta de teste KLaOS com role admin |
| SDR de teste | Criar user no workspace com role "SDR" (ou equivalente) |
| Closer de teste | Idem mas role "Closer" |

### 2.2 Dados seed
- Pelo menos 1 pipeline com 4-5 stages (ex: Novo → Qualificado → Proposta → Fechado)
- 5+ leads em estados variados
- 5+ deals em stages diferentes
- 3+ contatos com atributos completos
- 1 workflow de scoring ativo

### 2.3 Ferramentas
- Browser Chrome/Edge + DevTools básico
- Gravação de tela pra bugs
- Email de teste (pra receber convites, reset)
- Acesso Google Calendar (pra testar integração de agendamento)

### 2.4 Fora do escopo do Davi
Consultas SQL ao Supabase, inspeção de código, leitura de logs. Se um bug exigir isso, QA abre ticket com evidências visuais e escala pra dev.

---

## 3. Formato dos Test Cases e prioridades

(Mesmo formato do plano Frontdesk — ver §3 daquele doc. Prioridades: Crítica / Alta / Média / Baixa.)

---

## 4. Critérios de saída
- 100% TCs Críticos com Pass
- ≥95% TCs Alta executados, ≥90% Pass
- ≥80% TCs Média executados
- Sign-off QA + Product

---

## 5. Features

### 5.1 Feature: Criação e gestão de Pipelines

#### 5.1.1 User Story
> Como **admin do workspace**, quero **criar pipelines com stages customizados (ex: GTM 90D, Cobrança, Consultoria)**, para **espelhar meu processo comercial real e organizar os deals em etapas**.

#### 5.1.2 Critérios de Aceitação

- **AC-1.1**: `CRM → Configurações → Pipelines → Novo` permite nome, descrição, stages (adicionar múltiplos), cor por stage.
- **AC-1.2**: Stages são ordenáveis via drag-drop.
- **AC-1.3**: Stages podem ser deletados se estiverem vazios; se tiver deals, sistema avisa e pede migração.
- **AC-1.4**: Editar pipeline em uso não quebra deals existentes.
- **AC-1.5**: Pode haver múltiplos pipelines simultâneos no mesmo workspace.
- **AC-1.6**: Pipeline default é escolhível.

#### 5.1.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-301 | Criar pipeline com 4 stages | Crítica | UI |
| TC-302 | Reordenar stages via drag-drop | Alta | UI |
| TC-303 | Deletar stage vazio | Alta | UI |
| TC-304 | Deletar stage com deals exige migração | Alta | UI |
| TC-305 | Editar nome/cor de stage reflete em todos deals | Média | UI |
| TC-306 | Múltiplos pipelines coexistem | Média | UI |
| TC-307 | Definir pipeline default | Baixa | UI |

##### TC-301 — Criar pipeline com 4 stages

**Prioridade**: Crítica | **Tipo**: UI

**Passos**:
1. Login como admin Mais Saúde
2. `CRM → Configurações → Pipelines → Novo Pipeline`
3. Nome: "QA Teste Pipeline"
4. Adicionar stages: "Novo lead" (azul), "Contato feito" (amarelo), "Proposta" (laranja), "Fechado" (verde)
5. Salvar

**Resultado esperado**: pipeline aparece na lista; acessível no Kanban do CRM; 4 colunas visíveis com as cores certas; dá pra criar deal que vai pro primeiro stage.

---

### 5.2 Feature: Kanban de Deals (drag-drop)

#### 5.2.1 User Story
> Como **closer**, quero **ver meus deals em visualização kanban e arrastar entre stages**, para **ter panorama visual do pipeline e avançar deals rapidamente**.

#### 5.2.2 Critérios de Aceitação

- **AC-2.1**: Menu `CRM → Deals` abre Kanban com stages do pipeline ativo.
- **AC-2.2**: Cada card mostra: nome do deal, valor, contato, dono, data de fechamento prevista.
- **AC-2.3**: Drag-drop de card entre colunas grava o novo stage imediatamente.
- **AC-2.4**: Filtros: por dono, por valor, por data, por tags.
- **AC-2.5**: Seletor de pipeline no topo.
- **AC-2.6**: Contador de deals e valor total por coluna.

#### 5.2.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-310 | Drag-drop move deal entre stages | Crítica | UI |
| TC-311 | Filtro por dono mostra só os meus | Alta | UI |
| TC-312 | Valor total da coluna soma corretamente | Alta | UI |
| TC-313 | Seletor troca pipeline, kanban re-renderiza | Alta | UI |
| TC-314 | Card mostra informações essenciais | Média | UI |
| TC-315 | Kanban vazio mostra mensagem amigável | Baixa | UI |

---

### 5.3 Feature: Detalhes do Deal

#### 5.3.1 User Story
> Como **closer**, quero **abrir um deal e ver/editar todos os detalhes (valor, próximos passos, tarefas, email, contato, empresa, histórico)**, para **ter contexto completo numa tela só**.

#### 5.3.2 Critérios de Aceitação

- **AC-3.1**: Clicar num card abre tela de detalhes (ou sidebar).
- **AC-3.2**: Campos editáveis inline: valor, data esperada, stage, owner, tags.
- **AC-3.3**: Associação com contato e empresa com busca rápida.
- **AC-3.4**: Timeline de atividades (quem fez o quê, quando): mudanças de stage, emails enviados, tarefas criadas.
- **AC-3.5**: Adicionar tarefa/nota/email direto do deal.
- **AC-3.6**: Campos customizados definidos pelo admin aparecem aqui.

#### 5.3.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-320 | Abrir deal e ver todas as abas | Crítica | UI |
| TC-321 | Editar valor inline — persiste | Alta | UI |
| TC-322 | Adicionar contato associado | Alta | UI |
| TC-323 | Timeline mostra mudança de stage | Alta | UI |
| TC-324 | Adicionar tarefa vinculada | Alta | UI |
| TC-325 | Campos customizados renderizam e salvam | Alta | UI |
| TC-326 | Histórico não some após reload | Média | UI |

---

### 5.4 Feature: Inbox de Leads

#### 5.4.1 User Story
> Como **SDR**, quero **uma inbox de leads que entraram (formulário do site, WA, import, etc.) pra qualificar e converter em deal**, para **não perder oportunidade e ter fluxo organizado**.

#### 5.4.2 Critérios de Aceitação

- **AC-4.1**: Menu `CRM → Leads` mostra lista com status: Novo, Qualificado, Desqualificado, Convertido.
- **AC-4.2**: Score do lead visível (0-100 ou classificação frio/quente).
- **AC-4.3**: Abrir lead mostra origem, dados de contato, mensagens iniciais (se veio de conversa Frontdesk).
- **AC-4.4**: Ação "Qualificar" → cria deal associado + muda status.
- **AC-4.5**: Ação "Desqualificar" → registra motivo + marca status.
- **AC-4.6**: Filtros por origem, score, data.

#### 5.4.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-330 | Inbox de leads carrega com lista | Alta | UI |
| TC-331 | Qualificar lead cria deal | Crítica | Integração |
| TC-332 | Desqualificar com motivo registra | Alta | UI |
| TC-333 | Filtrar por score > 70 | Média | UI |
| TC-334 | Lead vindo do Frontdesk tem conversa linkada | Alta | Integração |

---

### 5.5 Feature: Gestão de Contatos

#### 5.5.1 User Story
> Como **usuário CRM**, quero **gerenciar contatos (criar, editar, mergear, importar)**, para **ter base única de pessoas com as quais nos relacionamos**.

#### 5.5.2 Critérios de Aceitação

- **AC-5.1**: `CRM → Contatos` mostra lista paginada com busca.
- **AC-5.2**: "Novo contato" — nome, email, telefone, empresa, tags, campos custom.
- **AC-5.3**: Merge de 2 contatos duplicados combina atributos sem perder dados.
- **AC-5.4**: Import CSV com mapeamento de colunas.
- **AC-5.5**: Perfil do contato mostra deals associados, conversas do Frontdesk, atividades.

#### 5.5.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-340 | Criar contato com campos completos | Alta | UI |
| TC-341 | Merge de duplicatas | Média | UI |
| TC-342 | Import CSV de 100 contatos | Alta | Integração |
| TC-343 | Perfil mostra deals + conversas Frontdesk | Crítica | Integração |

---

### 5.6 Feature: Empresas (Companies)

#### 5.6.1 User Story
> Como **usuário CRM**, quero **cadastrar empresas e associar contatos/deals a elas**, para **ter visão B2B e agregar histórico por organização**.

#### 5.6.2 Critérios de Aceitação

- **AC-6.1**: `CRM → Empresas` — CRUD com CNPJ, razão social, contatos associados.
- **AC-6.2**: 🟡 CNPJ lookup automático (consulta Receita Federal) — validar se tá funcionando.
- **AC-6.3**: Associar contato e deal a empresa.
- **AC-6.4**: Timeline de interações por empresa.

#### 5.6.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-350 | Criar empresa manualmente | Alta | UI |
| TC-351 | Lookup por CNPJ preenche dados | Média | Integração |
| TC-352 | Associar contato a empresa | Alta | UI |
| TC-353 | Deal aparece na timeline da empresa | Alta | UI |

---

### 5.7 Feature: Tarefas (Tasks)

#### 5.7.1 User Story
> Como **SDR/closer**, quero **criar tarefas com prazo e prioridade vinculadas a deal/lead/contato**, para **não esquecer de follow-up**.

#### 5.7.2 Critérios de Aceitação

- **AC-7.1**: Criar tarefa com título, descrição, prazo, prioridade, atribuído a, vinculada a deal/lead/contato.
- **AC-7.2**: Lista de tarefas (minhas, do time, atrasadas, futuras).
- **AC-7.3**: Marcar como concluída.
- **AC-7.4**: Notificação de tarefa próxima do prazo.

#### 5.7.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-360 | Criar tarefa vinculada a deal | Alta | UI |
| TC-361 | Lista "minhas tarefas atrasadas" | Alta | UI |
| TC-362 | Marcar como concluída | Alta | UI |
| TC-363 | Notificação quando prazo se aproxima | Média | Integração |

---

### 5.8 Feature: Integração de Email

#### 5.8.1 User Story
> Como **closer**, quero **conectar minha caixa Gmail/Outlook ao KLaOS pra enviar e receber emails direto do deal**, para **centralizar comunicação sem alt-tab constante**.

#### 5.8.2 Critérios de Aceitação

- **AC-8.1**: `Configurações → Email → Conectar Gmail` (OAuth).
- **AC-8.2**: Após conectar, emails recebidos associados a contatos/deals aparecem no timeline.
- **AC-8.3**: Compor email direto do deal (pré-preenche destinatário com contato).
- **AC-8.4**: 🟡 Threading de respostas no mesmo deal — validar se agrupa.
- **AC-8.5**: Disconnect / re-auth funciona.

#### 5.8.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-370 | Conectar Gmail via OAuth | Alta | Integração |
| TC-371 | Email recebido aparece no timeline do deal | Alta | Integração |
| TC-372 | Compor e enviar direto do deal | Alta | UI |
| TC-373 | Threading de respostas | Média | Integração |
| TC-374 | Disconnect limpa sem residual | Média | UI |

---

### 5.9 Feature: Campos Customizados

#### 5.9.1 User Story
> Como **admin**, quero **definir campos extras em Deal/Contact/Company (ex: "Fonte do lead", "CPF")**, para **capturar metadados específicos do meu negócio**.

#### 5.9.2 Critérios de Aceitação

- **AC-9.1**: CRUD de custom fields com tipos: texto, número, data, select, checkbox, link.
- **AC-9.2**: Campos renderizam nas telas de detalhe do objeto.
- **AC-9.3**: Editar nome do campo preserva valores existentes.
- **AC-9.4**: Deletar campo com valores em uso: avisa e migra/remove.

#### 5.9.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-380 | Criar campo "CPF" tipo texto no contato | Alta | UI |
| TC-381 | Campo aparece no detalhe do contato | Alta | UI |
| TC-382 | Campo select com 3 options | Alta | UI |
| TC-383 | Deletar campo em uso — confirmação | Média | UI |

---

### 5.10 Feature: Tags

#### 5.10.1 User Story
> Como **usuário CRM**, quero **taguear deals/contatos com labels coloridos**, para **filtrar e categorizar por contexto (ex: "prioridade-alta", "cliente-premium")**.

#### 5.10.2 Critérios de Aceitação

- **AC-10.1**: CRUD de tags com nome + cor.
- **AC-10.2**: Aplicar múltiplas tags num deal.
- **AC-10.3**: Autocomplete ao digitar.
- **AC-10.4**: Filtrar Kanban/lista por tag.

#### 5.10.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-390 | Criar tag "prioridade-alta" cor vermelha | Alta | UI |
| TC-391 | Aplicar em deal + autocomplete | Alta | UI |
| TC-392 | Filtrar Kanban por tag | Alta | UI |
| TC-393 | Rastreamento de uso (quantos deals usam) | Baixa | UI |

---

### 5.11 Feature: Lead Scoring

#### 5.11.1 User Story
> Como **admin**, quero **configurar regras de pontuação pra leads (ex: +20 se vem de site, +30 se email corporativo, etc.)**, para **priorizar atendimento**.

#### 5.11.2 Critérios de Aceitação

- **AC-11.1**: `CRM → Configurações → Scoring` permite adicionar regras com condições e pesos.
- **AC-11.2**: Score do lead é recalculado automaticamente quando dado relevante muda.
- **AC-11.3**: Thresholds classificam: frio (<30), morno (30-70), quente (>70).
- **AC-11.4**: 🟡 ML/score dinâmico — ainda não implementado (base manual).

#### 5.11.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-400 | Criar regra "+20 se origem=site" | Alta | UI |
| TC-401 | Lead novo bate regra e score aumenta | Alta | Funcional |
| TC-402 | Mudança de atributo recalcula score | Alta | Funcional |
| TC-403 | Classificação frio/morno/quente correta | Média | UI |

---

### 5.12 Feature: Agendamento (Closer + Google Calendar)

#### 5.12.1 User Story
> Como **SDR**, quero **agendar reunião do lead com um closer usando link de agendamento**, para **automatizar marcação e bloquear agenda do closer**.

#### 5.12.2 Critérios de Aceitação

- **AC-12.1**: Gerar link de agendamento do closer com horários disponíveis.
- **AC-12.2**: Cliente escolhe horário → reunião criada no Google Calendar do closer.
- **AC-12.3**: Deal recebe atributos `scheduled_at` e `closer_assigned`.
- **AC-12.4**: Dispara push pro Frontdesk via CRM Bridge (se conversa linkada existe).
- **AC-12.5**: Cancelamento reflete em ambos lados.

#### 5.12.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-410 | Gerar link de agendamento | Alta | UI |
| TC-411 | Agendar cria evento no Google Calendar | Crítica | Integração |
| TC-412 | Deal recebe scheduled_at + closer_assigned | Crítica | Integração |
| TC-413 | Frontdesk recebe dados via CRM Bridge | Alta | Integração |
| TC-414 | Cancelar remove do calendar | Alta | Integração |

---

### 5.13 Feature: Permissões

#### 5.13.1 User Story
> Como **admin**, quero **controlar quem vê/edita o quê (dono vs. time vs. admin)**, para **garantir privacidade e segurança das informações**.

#### 5.13.2 Critérios de Aceitação

- **AC-13.1**: Roles: admin, manager, closer, SDR (ou equivalentes no KLaOS).
- **AC-13.2**: Dono de deal vê sempre; outros veem se políticas permitirem.
- **AC-13.3**: Admin vê tudo do workspace.
- **AC-13.4**: SDR sem role de closer não consegue fechar deal.

#### 5.13.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-420 | Role closer não vê deals de outro closer | Crítica | Segurança |
| TC-421 | Admin vê todos | Alta | Segurança |
| TC-422 | SDR tenta fechar deal → bloqueado | Alta | Segurança |
| TC-423 | Mudar dono atualiza permissões | Média | Funcional |

---

### 5.14 Feature: Notificações

#### 5.14.1 User Story
> Como **usuário CRM**, quero **ser notificado (in-app, email) de eventos importantes (deal atualizado, tarefa próxima, lead novo)**, para **não perder coisa crítica**.

#### 5.14.2 Critérios de Aceitação

- **AC-14.1**: Sininho in-app com contador.
- **AC-14.2**: Cada usuário configura quais eventos notificar.
- **AC-14.3**: Email resumo diário (opcional).
- **AC-14.4**: Click na notificação leva pro objeto referenciado.

#### 5.14.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-430 | Sininho contador incrementa com nova notif | Alta | UI |
| TC-431 | Click leva pro deal/lead | Alta | UI |
| TC-432 | Desativar tipo de notif — não chega mais | Média | Funcional |

---

### 5.15 Feature: Analytics / Relatórios

#### 5.15.1 User Story
> Como **gestor**, quero **dashboard com métricas do pipeline (conversão por stage, tempo médio, valor total, taxa de ganho/perda)**, para **acompanhar performance comercial**.

#### 5.15.2 Critérios de Aceitação

- **AC-15.1**: `CRM → Analytics` mostra: funil de conversão, tempo médio por stage, valor total, win rate.
- **AC-15.2**: Filtros de período, pipeline, dono, time.
- **AC-15.3**: 🟡 Export CSV — validar se funciona.

#### 5.15.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-440 | Funil mostra conversão entre stages | Alta | UI |
| TC-441 | Filtro de período muda dados | Alta | UI |
| TC-442 | Win rate por closer | Média | UI |
| TC-443 | Export CSV | Baixa | UI |

---

## 6. Anexos

### Anexo A — Matriz de permissões por role
_(a preencher com mapa completo quando roles forem finalizadas)_

### Anexo B — Sign-off
| Papel | Nome | Data | Assinatura |
|---|---|---|---|
| QA Lead | Davi Felix | | |
| Product | Matheus Macedo | | |
| Eng Lead | | | |
