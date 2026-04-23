# Plano de Testes — KLaOS Frontdesk

| Campo | Valor |
|---|---|
| Versão | 1.0 |
| Data | 2026-04-21 |
| Responsável QA | _(preencher)_ |
| Autor do plano | Matheus Macedo |
| Produto | KLaOS Frontdesk (fork customizado do Chatwoot v4.11.2) |
| Ambiente principal | Dev (`app-desk-dev.klaos.ai`) + Prod (`app-desk.klaos.ai`) |
| Repositório | `matheusmmacedo/frontdesk` — branch `klaos-dev` |
| Workspace de referência | Mais Saúde 24h (account_id=10 em prod, account_id=10 em dev) |

---

## 1. Escopo

### 1.1 Incluído
Este plano cobre **todas as funcionalidades do Frontdesk** que estão implementadas e acessíveis via UI ou API, incluindo:

- Funcionalidades nativas do Chatwoot ativadas na instalação (licença enterprise, plano 10.000).
- Customizações KLaOS no diretório `custom/` do repositório (WhatsApp Connections, AI Bridge, CRM Bridge, filtro "Ativas", enriquecimento de webhook, guard do agent_bot, envio de áudio via Meta Media API).
- Integrações externas onde o Frontdesk é o ponto de interação (widget web, Evolution API, WABA, webhooks de saída).

### 1.2 Fora de escopo
- **Lógica interna do agente KLaOS** (prompts, intenções, tool calls) — coberta no plano *AI Agents*.
- **Provisionamento de agentes no KLaOS** (criação de `agent_instances`) — coberto no plano *KLaOS CRM*.
- **Jornadas cruzadas ponta-a-ponta** (ex: handoff bot → humano) — cobertas no plano *Integração*.
- Features marcadas como Enterprise exclusivas mas não ativadas (custom roles avançadas, CSAT com pagamento).
- Testes de carga (fora do plano funcional).

### 1.3 Navegadores suportados
Chrome, Edge, Firefox (versões atuais). Safari sob demanda.

### 1.4 Resolução mínima de UI
1280x720 (desktop). Mobile não é prioridade do Frontdesk (é dashboard de agente).

---

## 2. Pré-requisitos de execução

### 2.1 Perspectivas de teste

Davi testa o Frontdesk cobrindo **duas perspectivas distintas**:

**(a) Perspectiva do usuário cliente KLaOS** — quem usa o Frontdesk no dia-a-dia:
- **Admin do workspace** (ex: gestor da Mais Saúde) — configura inboxes, times, macros, etiquetas, automações, convida agentes
- **Agente operacional** (ex: Daniel da equipe cobrança) — atende conversas, envia mensagens, atribui, resolve, filtra a lista

**(b) Perspectiva de funcionário KLaOS (backoffice)** — quem opera os bastidores:
- **Super Admin** (acesso a `/super_admin/`) — gerencia todos os accounts/usuarios, configura platform apps, vê installation configs
- **Suporte KLaOS** — investiga problemas reportados, verifica visibilmente o estado de um workspace

### 2.2 Credenciais e acessos

| Papel | Usuário | Observação |
|---|---|---|
| QA executor | **Davi Felix** | Já tem acesso ao Frontdesk como agente. **Não usar a conta dele pra testar fluxos de provisionamento/permissão** — usar contas de teste |
| Super Admin | `matheus.macedo@gmail.com` | Dev e Prod. Acesso à UI de Super Admin |
| Admin do workspace (Mais Saúde) | `matheus@matheus.pro.br` | Usar pra configurar inboxes/macros/etc. nos TCs de admin |
| Conta de teste "agente novo" | Criar no KLaOS com **um email válido do Davi que ainda não esteja cadastrado no KLaOS** | Usar email que ele tenha acesso à caixa de entrada (pra receber convite/reset de senha). Ao fim de cada rodada, deletar a conta no KLaOS |
| Conta de teste "admin novo" | Idem, com email diferente + role admin no KLaOS | |
| Conta de teste "sem acesso" | Email diferente, cadastrado mas SEM atribuir a nenhum workspace | Pra testar cenário de user sem workspace autorizado |
| Contato final de teste | WhatsApp pessoal do Davi + formulário de teste do widget | Simula cliente do cliente (ex: paciente da Mais Saúde) |

> **Dica**: Davi pode manter uma lista própria de emails de teste disponíveis (não cadastrados no KLaOS) e rotacionar entre eles. Depois de deletar a conta no KLaOS ao fim do teste, o email fica liberado de novo pra próxima rodada.

### 2.2 Ambiente de referência: Mais Saúde 24h

Configuração de referência pra simular cenário real:

- **Workspace**: Mais Saúde 24h (account_id=10)
- **Inboxes ativas**:
  - `Website - Principal` (id=22, WebWidget embed no site institucional)
  - `Whatsapp - Cobrança` (id=23, WABA Cloud via Meta)
  - `Whatsapp - Consultas e Exames` (id=25, WABA Cloud)
  - `Whatsapp - Vendas` (id=24, WABA Cloud)
  - `KLaOS Cobranca` (id=30, canal dedicado do módulo KLaOS)
- **Team**: `cobrança` (id=2) com 5 agentes
- **Agentes**: Daniel Limeira, Matheus, Ingrid, Mike, Sergio
- **Bot**: Lara (`lara`, id=15) vinculada às 3 inboxes de Website/WA Cobrança/KLaOS Cobrança
- **Labels em uso**: cancelado, cobranca-0d, cobranca-7d, cobranca-15d, cobranca-promessa, pagamento-realizado, mais-saude, etc. (ver Anexo A)

### 2.3 Dados seed
Antes de iniciar a suite, garantir que o workspace de teste tem:
- [ ] Pelo menos 1 contato de teste com dados completos (nome, email, telefone, atributos custom)
- [ ] 1 conversa em cada status (open, pending, snoozed, resolved)
- [ ] 1 template WhatsApp aprovado + 1 em review + 1 rejeitado
- [ ] 1 macro simples (ex: "Saudação" que envia texto + adiciona label)
- [ ] 1 canned response
- [ ] 1 equipe com pelo menos 2 agentes

### 2.4 Ferramentas do QA

Davi é QA de plataforma. Testa **pela UI** — não acessa banco nem código. Caixa de ferramentas:

- **Browser Chrome/Edge** (principal) + Firefox/Safari (compatibilidade)
- **DevTools básico** — só pra confirmar visualmente que cookies de sessão foram setados, que mensagens de erro aparecem amigáveis (não 500/stack trace), e que requests não entram em loop infinito na aba Network
- **Gravação de tela** (Loom ou similar) pra documentar bugs
- **WhatsApp pessoal** — pra enviar mensagens de teste via WABA/Evolution e validar recebimento no Frontdesk
- **Conta de email de teste** — pra receber convites, resetar senha, confirmar conta
- Acesso às UIs (login próprio):
  - `app-desk-dev.klaos.ai` — Frontdesk dev
  - `app-desk.klaos.ai` — Frontdesk prod
  - `app-desk-dev.klaos.ai/super_admin/` — UI de Super Admin dev
  - `app-dev.klaos.ai` — KLaOS dev (pra criar user de teste)

**Fora do escopo do Davi**: consultas SQL, logs de Railway, inspeção de código. Se um bug exigir isso, ele abre um ticket com evidências visuais (screenshots/gravação) e passa pra dev.

---

## 3. Como executar e registrar

### 3.1 Estrutura de cada feature

Cada seção **§3.X** do documento segue este formato:

```
3.X Feature: <nome>
    3.X.1 User Story
    3.X.2 Critérios de Aceitação (AC-X.Y)
    3.X.3 Test Cases (TC-XXX)
```

### 3.2 Formato do Test Case

Campos de cada TC:

| Campo | O que preencher |
|---|---|
| **ID** | `TC-XXX` sequencial global no documento |
| **Título** | Curto, descritivo do cenário |
| **Prioridade** | Crítica / Alta / Média / Baixa |
| **Tipo** | Funcional / UI / Integração / Regressão |
| **Passos** | Numerados, um por linha, reprodutíveis |
| **Resultado esperado** | O que deve acontecer após o último passo |
| **Resultado obtido** | Preencher após execução |
| **Status** | Pass / Fail / Blocked / N/A |
| **Bug aberto** | Link do ticket se Fail |
| **Automatizável?** | Sim / Não (ajuda planejar suite automatizada depois) |

### 3.3 Prioridades

- **Crítica**: quebra impede o Frontdesk de funcionar (não consegue logar, não recebe mensagens, não envia resposta). Falha bloqueia release.
- **Alta**: feature central com alto uso falha (ex: template WA não envia, filtro não aplica). Deve ser corrigido no mesmo sprint.
- **Média**: feature secundária ou workaround disponível.
- **Baixa**: cosmético, raro, edge case que não impacta operação.

---

## 4. Critérios de saída (exit criteria)

O plano é considerado **concluído** quando:

- [ ] 100% dos TCs de prioridade Crítica executados e com status Pass
- [ ] ≥ 95% dos TCs de prioridade Alta executados, ≥ 90% com status Pass
- [ ] ≥ 80% dos TCs de prioridade Média executados
- [ ] Todos os bugs Críticos abertos tem resolução ou workaround documentado
- [ ] QA emitiu sign-off formal no documento (Anexo B — rodapé)

---

## 5. Features

> **Nota**: As seções abaixo marcadas com `[PREVIEW]` são 2 exemplos completos pra validação do formato.
> O restante será preenchido após a confirmação do modelo pelo cliente.

---

### 5.1 Feature: Onboarding de agente — KLaOS → Frontdesk `[PREVIEW]`

> **Contexto pro QA**: essa é a jornada mais crítica do Frontdesk porque TODOS os agentes chegam aqui através dela. O Frontdesk **não tem cadastro próprio de usuário** no dia-a-dia — a criação acontece no KLaOS e é empurrada via Platform API. Se esse fluxo quebra, time inteiro fica sem acesso. Por isso Davi precisa dominar não só a UI do Frontdesk mas o ciclo completo: criação → propagação → acesso → visibilidade correta.

#### 5.1.1 User Story
> Como **admin do KLaOS**, quero **criar um usuário no KLaOS (ex: novo agente Mais Saúde) e que ele automaticamente receba acesso ao Frontdesk com o role e workspace corretos**, para **não duplicar cadastros, não precisar onboardear em 2 ferramentas e garantir que todo agente só enxerga os workspaces autorizados**.

#### 5.1.2 Critérios de Aceitação

**Provisionamento (recebimento no Frontdesk)**
- **AC-1.1**: Ao criar usuário em KLaOS com `status=active`, Frontdesk recebe POST na Platform API (`/platform/api/v1/users`) e cria o registro em `users` (Postgres Chatwoot).
- **AC-1.2**: Um registro em `account_users` é criado ligando o novo user ao account correto com o role correto (admin/agent).
- **AC-1.3**: O `users.id` retornado é persistido no KLaOS em `frontdesk_users.chatwoot_user_id` (via resposta da API).
- **AC-1.4**: Reprovisionar o mesmo user (idempotência) não cria duplicados — update em campos mutáveis (nome, role) e preserva ID.
- **AC-1.5**: Deletar user no KLaOS com `status=inactive` remove acesso no Frontdesk (revoga access_token + marca account_user como revogado OU remove a linha — validar comportamento).

**Acesso após provisionamento**
- **AC-1.6**: Após provisionamento, o usuário consegue logar via SSO KLaOS e chegar em `/app/accounts/<id>/dashboard` sem passos manuais.
- **AC-1.7**: Visibilidade na UI: user aparece em `Configurações → Agentes` do workspace com nome, email e role corretos.
- **AC-1.8**: Role = admin enxerga Configurações. Role = agent NÃO vê Configurações.
- **AC-1.9**: User criado em workspace X **não** vê conversas/inboxes do workspace Y (isolamento multi-tenant).
- **AC-1.10**: Reenvio de convite (se aplicável) funciona sem duplicar user.

**Casos de borda**
- **AC-1.11**: Usuário criado fora da Platform API (ex: manual no Super Admin) — não é rejeitado mas fica órfão (sem `frontdesk_users`). Tem que ser detectável e limpável.
- **AC-1.12**: Se Frontdesk retornar 500/timeout durante provisionamento, KLaOS retry sem criar duplicata.
- **AC-1.13**: Email com caracteres especiais / acento normalizado corretamente (ex: `ingridbergami@gmail.com`).

#### 5.1.3 Test Cases

| ID | Título | Prioridade | Tipo | Automatizável? |
|---|---|---|---|---|
| TC-001 | Fluxo completo: criar user no KLaOS → aparece no Frontdesk → consegue logar | **Crítica** | Integração | Sim |
| TC-002 | User criado com role=admin vê Configurações | Crítica | UI | Sim |
| TC-003 | User criado com role=agent NÃO vê Configurações | Crítica | UI | Sim |
| TC-004 | Isolamento multi-tenant: user de workspace A não vê dados de B | Crítica | Segurança | Sim |
| TC-005 | Reprovisionamento idempotente (criar 2x não duplica) | Alta | Integração | Sim |
| TC-006 | Deletar user em KLaOS remove acesso no Frontdesk | Alta | Integração | Sim |
| TC-007 | `chatwoot_user_id` persistido de volta no KLaOS | Alta | Integração | Não (DB) |
| TC-008 | Logout no Frontdesk invalida sessão | Alta | Funcional | Sim |
| TC-009 | Sessão expirada (cookie apagado) força re-login | Alta | Funcional | Sim |
| TC-010 | Múltiplos workspaces — seletor aparece | Média | UI | Não |
| TC-011 | User criado manual no Super Admin (órfão) — detectar | Média | Funcional | Sim |
| TC-012 | Retry de provisionamento após timeout — sem duplicata | Média | Resiliência | Não (simular) |

---

##### TC-001 — Fluxo completo: criar agente no KLaOS → aparece no Frontdesk → consegue logar

**Prioridade**: Crítica | **Tipo**: Integração | **Automatizável?**: Sim

> Esse é o TC "bíblia" do provisionamento. Se esse passa, 80% do Frontdesk tá funcionando na visão do usuário cliente. Davi deve executar manualmente várias vezes pra desenvolver intuição.

**Pré-condição**:
- Davi logado como admin do KLaOS dev (`app-dev.klaos.ai`)
- Outra aba logada como Matheus (admin da Mais Saúde) no Frontdesk dev (`app-desk-dev.klaos.ai`)
- **Um email do próprio Davi que ainda não esteja cadastrado no KLaOS** (pra ele receber o convite)
- Caixa de email desse endereço aberta em outra aba (pra pegar o convite quando chegar)

**Passos**:

1. **[KLaOS] Criar agente** — na UI do KLaOS dev, ir em `Workspaces → Mais Saúde 24h → Membros → Adicionar membro`. Preencher:
   - Nome: `QA Agente Teste` (pode incluir número da rodada, ex: "QA Agente 01")
   - Email: o email do Davi definido na pré-condição
   - Role: `Agente`
   - Status: `Ativo`
   - Salvar e aguardar confirmação visual ("Membro adicionado com sucesso" ou equivalente)

2. **[KLaOS] Conferir** — na lista de membros, confirmar visualmente que o novo agente aparece com status "Ativo" e o role correto.

3. **[Frontdesk — perspectiva admin do cliente]** — na aba do Matheus (admin Mais Saúde), ir em `Configurações → Agentes`. Usar a busca pra localizar pelo email. O agente deve aparecer:
   - Com o nome certo
   - Com o email certo
   - Com role "Agente" (não Administrador)
   - Sem erro na tela
   - Em até 30 segundos após o passo 1 (se demorar mais, anotar)

4. **[Frontdesk — perspectiva backoffice/Super Admin]** — logado como Super Admin, acessar `app-desk-dev.klaos.ai/super_admin/users`. Buscar pelo email. O user deve aparecer na lista global com o account "Mais Saúde 24h" vinculado.

5. **[Email de convite] — validar recebimento**:
   - Na aba do email do Davi, aguardar até 2 minutos o email de convite do KLaOS (remetente tipo "KLaOS" ou `noreply@klaos.ai`)
   - **Se não chegar em 2 minutos**: bug Alto — provisionamento criou o user mas não dispara convite. Anotar e sinalizar.
   - Validar visualmente no email: remetente correto, assunto legível, conteúdo sem `{{variáveis}}` quebradas, botão de ação visível
   - Clicar no botão/link do email → deve abrir o KLaOS numa nova aba na tela de definição de senha (primeiro acesso)
   - Definir senha forte (anotar em lugar seguro pra os próximos passos)
   - Após salvar, KLaOS deve redirecionar pro Frontdesk ou mostrar tela de sucesso

6. **[Login do novo agente] — simular primeiro acesso**:
   - Em janela anônima (Ctrl+Shift+N), acessar `app-desk-dev.klaos.ai`
   - Deve redirecionar pro login do KLaOS
   - Entrar com o **alias do email** + senha definida no passo 5
   - Deve retornar ao Frontdesk, landing em `/app/accounts/10/dashboard`

7. **[Dashboard do novo agente] — validar UX**:
   - Nome do novo agente aparece no canto inferior esquerdo (menu do perfil)
   - Lista de conversas da Mais Saúde carrega (mesmo que vazia pra ele)
   - Menu lateral mostra: Caixa de Entrada, Conversas, Contatos, Relatórios — mas **NÃO** Configurações (role agent não vê)
   - Consegue abrir uma conversa existente e ver o conteúdo
   - Ícone de status (online/offline) funciona ao clicar no avatar

8. **[Limpeza]** — depois de validar, voltar ao KLaOS e deletar o agente de teste (ver TC-006).

**Resultado esperado**:
- Em cada passo a UI responde sem erro visível (sem tela em branco, sem mensagens técnicas cruas, sem 404/500)
- O agente de teste aparece no Frontdesk (passos 3 e 4) em menos de 30s após criação no KLaOS
- Login e acesso funcionam sem passos manuais extras além do definido

**Resultado obtido**: _(Davi preenche)_ | **Status**: _(preencher)_ | **Bug**: _(se Fail)_

> **Contexto pro QA**: se no passo 3 o novo agente NÃO aparecer na lista de `Agentes` do workspace, tem bug grave no provisionamento. Em 2026-03-30 teve incidente assim com a conta do Gustavo — foi criado por caminho errado e apareceu pro admin como "usuário sem permissão". Precisou intervenção manual de dev. Se esse sintoma aparecer, documenta em vídeo/screenshot e abre ticket Crítico.

---

##### TC-002 — User com role=admin vê Configurações

**Prioridade**: Crítica | **Tipo**: UI | **Automatizável?**: Sim

**Pré-condição**: ter user provisionado via TC-001 mas com role=admin em vez de agent.

**Passos**:
1. Login como user admin novo
2. Observar menu lateral

**Resultado esperado**: Item "Configurações" visível no menu; clicável; dá acesso a Agentes, Equipes, Inboxes, etc.

---

##### TC-003 — User com role=agent NÃO vê Configurações

**Prioridade**: Crítica | **Tipo**: UI | **Automatizável?**: Sim

**Passos**:
1. Login como user agent (TC-001)
2. Observar menu lateral
3. Tentar acessar direto `/app/accounts/10/settings/agents` na URL

**Resultado esperado**:
- Item "Configurações" **não** aparece no menu
- Acesso direto via URL redireciona ou mostra 403/404 amigável

---

##### TC-004 — Isolamento multi-tenant

**Prioridade**: Crítica | **Tipo**: Segurança | **Automatizável?**: Sim

> CVE em potencial. Se quebra, vaza dados entre clientes. Nunca pular.

**Pré-condição**: user de teste está só no workspace Mais Saúde (account 10), não em GMB (account 11).

**Passos**:
1. Login com user de teste
2. No DevTools → Network, observar request pra `/api/v1/accounts/10/conversations` — deve retornar 200
3. Mudar manualmente o URL pra `/app/accounts/11/dashboard` (workspace GMB que ele não é membro)
4. Tentar chamar `/api/v1/accounts/11/conversations` via DevTools Console com os mesmos headers

**Resultado esperado**:
- Passo 3: redireciona ou mostra erro de acesso
- Passo 4: retorna 401 ou 403
- **NUNCA retorna dados de outro account**

---

##### TC-005 — Reprovisionamento idempotente

**Prioridade**: Alta | **Tipo**: Integração | **Automatizável?**: Sim

**Passos**:
1. Executar TC-001 até passo 5 (user provisionado e ID persistido)
2. No KLaOS, editar o user (mudar o nome pra "QA Agente Teste v2")
3. Aguardar propagação
4. No Frontdesk Postgres:
   ```sql
   SELECT id, name FROM users WHERE email = '<email>';
   ```

**Resultado esperado**:
- `id` é o MESMO de antes (não criou novo)
- `name` atualizado pra "QA Agente Teste v2"
- Apenas 1 linha em `users` pro email

---

##### TC-006 — Deletar user em KLaOS remove acesso

**Prioridade**: Alta | **Tipo**: Integração | **Automatizável?**: Sim

**Passos**:
1. Com user provisionado (TC-001), deletar no KLaOS (ou marcar `status=inactive`)
2. Rodar no Frontdesk Postgres:
   ```sql
   SELECT * FROM users WHERE email = '<email>';
   SELECT * FROM account_users WHERE user_id = <id>;
   SELECT * FROM access_tokens WHERE owner_type = 'User' AND owner_id = <id>;
   ```
3. Em janela anônima, tentar logar com esse user
4. Se já estava logado em outra janela, tentar fazer qualquer request

**Resultado esperado**:
- `access_tokens` removidos (ou revogados) — requests retornam 401
- `account_users` removida OU user não aparece em "Agentes" do workspace
- Login é rejeitado ou redireciona de volta ao KLaOS

> **Atenção**: incidente de 2026-04-21 — user id=12 (Gustavo) ficou órfão porque foi criado fora da Platform App. Tivemos que deletar manualmente via SQL (`DELETE FROM users WHERE id=12` + cascades). Esse TC valida que o delete normal não sofre desse bug.

---

##### TC-007 — `chatwoot_user_id` persistido de volta no KLaOS

**Prioridade**: Alta | **Tipo**: Integração | **Automatizável?**: Não (requer DB)

**Passos**:
1. Criar user no KLaOS (TC-001 passo 1-2)
2. Imediatamente ir no Supabase KLaOS dev
3. Query: `SELECT id, email, chatwoot_user_id, status FROM frontdesk_users WHERE email = '<email>';`

**Resultado esperado**:
- 1 linha retornada
- `chatwoot_user_id` preenchido (bate com `users.id` no Frontdesk)
- `status = 'active'` (ou o enum correspondente)

---

##### TC-008 — Logout no Frontdesk invalida sessão

**Prioridade**: Alta | **Tipo**: Funcional | **Automatizável?**: Sim

**Passos**:
1. Logado no Frontdesk
2. Clicar no avatar (canto inferior esquerdo) → "Sair"
3. Confirmar redirect
4. Tentar navegar direto pra `/app/accounts/10/dashboard`

**Resultado esperado**: Redirect pra login; cookie `cw_d_session_info` removido.

---

##### TC-009 — Sessão expirada força re-login

**Prioridade**: Alta | **Tipo**: Funcional | **Automatizável?**: Sim

**Passos**:
1. Logado normal
2. DevTools → Application → Cookies → apagar `cw_d_session_info`
3. Recarregar

**Resultado esperado**: Redirect pra login do KLaOS. Não cai em tela em branco nem 401 cru.

---

##### TC-010 — Múltiplos workspaces — seletor aparece

**Prioridade**: Média | **Tipo**: UI | **Automatizável?**: Não (visual)

**Pré-condição**: User é membro de Mais Saúde + GMB (provisionar em ambos).

**Passos**:
1. Login
2. Observar topo do menu lateral

**Resultado esperado**: Seletor dropdown com ambos workspaces. Clicar alterna contexto (URL muda de `/accounts/10/` pra `/accounts/11/`).

---

##### TC-011 — User órfão (criado fora da Platform App) — detectar

**Prioridade**: Média | **Tipo**: Funcional | **Automatizável?**: Sim

**Passos**:
1. Via Super Admin, criar user direto (bypass do provisionamento KLaOS)
2. No KLaOS, verificar se `frontdesk_users` tem registro pra esse email

**Resultado esperado**:
- `frontdesk_users` NÃO tem esse user (órfão)
- Script de auditoria (se existir) detecta a discrepância

---

##### TC-012 — Retry sem duplicata após timeout

**Prioridade**: Média | **Tipo**: Resiliência | **Automatizável?**: Não (requer simulação de falha)

**Passos**: (precisa coordenação com eng)
1. Causar timeout na chamada KLaOS → Frontdesk (ex: forçar lentidão)
2. KLaOS faz retry
3. Verificar no Frontdesk: 1 user criado, não 2

**Resultado esperado**: Idempotência preservada mesmo com retries.

---

### 5.2 Feature: Lista de Conversas — Filtro "Ativas" `[PREVIEW]`

#### 5.2.1 User Story
> Como **agente da Mais Saúde**, quero **ver por padrão todas as conversas que precisam de atenção (open, pending, snoozed) ocultando resolvidas**, para **não perder conversas em que o bot Lara não conseguiu fechar e que estão paradas aguardando intervenção humana**.

#### 5.2.2 Critérios de Aceitação

- **AC-2.1**: Ao abrir a lista de conversas pela primeira vez, filtro padrão = "Ativas".
- **AC-2.2**: A opção "Ativas" aparece como primeira no dropdown Status, seguida de Abertas, Pendentes, Adiadas, Resolvidas, Todas.
- **AC-2.3**: Com filtro "Ativas", lista mostra conversas com status `open`, `pending` ou `snoozed`. Conversas `resolved` **não** aparecem.
- **AC-2.4**: Contadores das tabs (Minhas / Não atribuídas / Todos) refletem apenas conversas ativas, não incluindo resolvidas.
- **AC-2.5**: Escolha de outro filtro (ex: "Resolvidas") persiste na sessão do usuário (salvo em `uiSettings.conversations_filter_by.status`).
- **AC-2.6**: A escolha persistida é mantida entre sessões (sobrevive logout/login).
- **AC-2.7**: Na tradução pt_BR, o label mostrado é "Ativas". Em en, "Active".
- **AC-2.8**: Sem loops infinitos de requisições à API após aplicar o filtro.

#### 5.2.3 Test Cases

| ID | Título | Prioridade | Tipo | Automatizável? |
|---|---|---|---|---|
| TC-007 | Primeiro acesso → filtro default = Ativas | Crítica | UI | Sim |
| TC-008 | Opção "Ativas" presente no dropdown como primeira | Alta | UI | Sim |
| TC-009 | Lista com "Ativas" exclui resolvidas | Crítica | Funcional | Sim |
| TC-010 | Contadores de tab refletem só ativas | Alta | Funcional | Sim |
| TC-011 | Seleção de outro filtro persiste em reload | Alta | Funcional | Sim |
| TC-012 | Escolha sobrevive logout/login | Alta | Integração | Sim |
| TC-013 | Mudança de idioma mostra label correto | Baixa | UI | Sim |
| TC-014 | Alternância rápida entre filtros sem loop | Crítica | Performance | Sim |
| TC-015 | Filtro "Ativas" aplicado quando inbox específica selecionada | Média | Funcional | Sim |

##### TC-007 — Primeiro acesso → filtro default = Ativas

**Prioridade**: Crítica | **Tipo**: UI | **Automatizável?**: Sim

**Pré-condição**: Usuário novo OU usuário com `ui_settings.conversations_filter_by` vazio (resetar via console: `store.dispatch('updateUISettings', { uiSettings: {} })`).

**Passos**:
1. Navegar a `/app/accounts/10/dashboard`
2. Observar o header da lista de conversas
3. Abrir dropdown de Status (ícone setas ↕)

**Resultado esperado**:
- Badge "Ativas" visível ao lado do título "Conversas"
- No dropdown, Status = "Ativas" selecionado
- Request à API: `GET /api/v1/accounts/10/conversations?status=active&assignee_type=me&...`

---

##### TC-009 — Lista com "Ativas" exclui resolvidas

**Prioridade**: Crítica | **Tipo**: Funcional | **Automatizável?**: Sim

**Pré-condição**: Ter no workspace pelo menos:
- 2 conversas status=open
- 2 conversas status=pending
- 1 conversa status=snoozed
- 2 conversas status=resolved

**Passos**:
1. Selecionar filtro "Ativas"
2. Clicar na tab "Todos"
3. Contar itens visíveis

**Resultado esperado**:
- Aparecem 5 conversas (2 open + 2 pending + 1 snoozed)
- Nenhuma das 2 resolvidas aparece
- Contador "Todos" mostra `5`

---

##### TC-014 — Alternância rápida entre filtros sem loop

**Prioridade**: Crítica | **Tipo**: Performance | **Automatizável?**: Sim

**Motivação**: Bug identificado no dia 2026-04-21 causava loop infinito de chamadas API quando filtro não batia status conhecido.

**Passos**:
1. DevTools → Network → limpar
2. Aplicar filtro "Ativas"
3. Aguardar 30 segundos sem interagir
4. Verificar Network

**Resultado esperado**:
- Máximo 2-3 requests ao endpoint `/conversations?...`
- Nenhum padrão de polling contínuo à mesma URL
- CPU do browser sem pico sustentado

---

### 5.3 Feature: Criação de Inbox — Website (Web Widget)

#### 5.3.1 User Story
> Como **admin do workspace**, quero **criar uma inbox do tipo Website no Frontdesk**, para **ter um chat ao vivo no site do cliente (ex: site da Mais Saúde) recebendo as mensagens no mesmo painel dos outros canais**.

#### 5.3.2 Critérios de Aceitação

- **AC-3.1**: Em `Configurações → Inboxes → Adicionar inbox`, existe opção "Website".
- **AC-3.2**: Formulário de criação pede: nome da inbox, URL do site, nome do canal (exibido pro visitante), cor do widget, saudação.
- **AC-3.3**: Após criar, sistema mostra o **snippet JavaScript** pra embedar no site com o `websiteToken` correto.
- **AC-3.4**: Na próxima tela, é possível atribuir agentes à inbox (quem recebe as conversas).
- **AC-3.5**: Inbox criada aparece na lista de canais do menu lateral (Caixa "Conversas → Canais → <nome>").
- **AC-3.6**: Editar a inbox permite alterar cor, saudação, horário de atendimento, pré-chat form.
- **AC-3.7**: É possível deletar a inbox (com confirmação); após delete, conversas antigas ficam órfãs mas não somem.

#### 5.3.3 Test Cases

| ID | Título | Prioridade | Tipo | Automatizável? |
|---|---|---|---|---|
| TC-020 | Criar inbox Website preenchendo wizard | Crítica | UI | Sim |
| TC-021 | Snippet JS fornecido é válido e aparece corretamente | Alta | UI | Parcial |
| TC-022 | Atribuir agentes durante criação | Alta | UI | Sim |
| TC-023 | Editar nome, cor e saudação | Alta | UI | Sim |
| TC-024 | Configurar pré-chat form (nome, email, telefone obrigatórios) | Média | UI | Sim |
| TC-025 | Configurar horário de atendimento | Média | UI | Sim |
| TC-026 | Deletar inbox com conversas existentes | Média | UI | Sim |
| TC-027 | Criar inbox sem preencher campos obrigatórios mostra erro amigável | Alta | UI | Sim |

##### TC-020 — Criar inbox Website preenchendo wizard

**Prioridade**: Crítica | **Tipo**: UI

**Passos**:
1. Login como admin da Mais Saúde
2. `Configurações → Inboxes → Adicionar inbox`
3. Escolher "Website"
4. Preencher:
   - Nome da inbox: `QA Website Teste`
   - URL do site: `https://qa.example.com`
   - Nome do canal: `Atendimento Mais Saúde`
   - Cor: selecionar verde
   - Saudação: "Olá! Como podemos ajudar?"
5. Clicar "Criar inbox"
6. Na próxima tela, selecionar Davi como agente
7. Finalizar

**Resultado esperado**: inbox aparece em `Conversas → Canais` com nome "QA Website Teste"; snippet JS é exibido na tela de configuração.

##### TC-021 — Snippet JS fornecido é válido

**Prioridade**: Alta | **Tipo**: UI/Integração

**Passos**:
1. Na tela de config da inbox, localizar o snippet JS
2. Copiar o snippet
3. Colar em uma página HTML de teste local (ou em `widget-test.html` do projeto)
4. Abrir a página no browser

**Resultado esperado**: widget flutuante aparece no canto inferior, cor e saudação corretas; ao abrir, conecta com a inbox.

##### TC-022 — Atribuir agentes durante criação

**Prioridade**: Alta | **Tipo**: UI

**Passos**:
1. Continuar do passo 5 do TC-020
2. Selecionar múltiplos agentes (Davi + Matheus + Daniel)
3. Finalizar

**Resultado esperado**: em `Configurações → Inboxes → <nome> → Colaboradores` os 3 agentes aparecem listados.

##### TC-027 — Validação de campos obrigatórios

**Prioridade**: Alta | **Tipo**: UI

**Passos**:
1. Abrir wizard de criação
2. Clicar "Criar inbox" com campos vazios

**Resultado esperado**: erros de validação amigáveis em cada campo obrigatório (não mensagem técnica); botão não dispara request.

---

### 5.4 Feature: Inbox WhatsApp Cloud API (WABA) — custom KLaOS

> **Contexto**: a Mais Saúde usa WhatsApp oficial via Meta Cloud API. Essa feature é customizada no diretório `custom/` — o fluxo difere da integração padrão do Chatwoot. Conecta via `Configurações → WhatsApp Connections`.

#### 5.4.1 User Story
> Como **admin do workspace**, quero **conectar uma linha de WhatsApp Cloud (WABA) da Meta e vincular um número dela a uma inbox**, para **atender os clientes via WhatsApp oficial com templates aprovados e todas as validações do fluxo Meta**.

#### 5.4.2 Critérios de Aceitação

- **AC-4.1**: Menu `Configurações → WhatsApp Connections → Nova conexão` existe e é acessível ao admin.
- **AC-4.2**: Formulário aceita tipo "Meta Cloud API" e pede: System User Token, WABA ID, Business Portfolio ID.
- **AC-4.3**: Após salvar credenciais válidas, sistema sincroniza e lista os **números de telefone disponíveis** naquela WABA.
- **AC-4.4**: É possível vincular um número disponível a uma inbox nova (cria inbox automaticamente).
- **AC-4.5**: É possível desvincular um número (remove inbox ou marca como desvinculado).
- **AC-4.6**: Se token expirado/inválido, sistema mostra erro claro (ex: "Token Meta expirado. Reconecte").
- **AC-4.7**: Lista de templates aprovados na Meta aparece em `Configurações → WhatsApp Connections → Templates` dessa conexão.
- **AC-4.8**: Criar/editar template via UI → submete à Meta → status "Em Análise" → atualiza pra "Aprovado" ou "Rejeitado" quando a Meta decide.
- **AC-4.9**: Erros da Meta são traduzidos (ex: `error_user_msg` aparece na UI, não o JSON cru).

#### 5.4.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-030 | Criar conexão WABA com credenciais válidas | Crítica | Integração |
| TC-031 | Credenciais inválidas retornam erro claro | Crítica | UI |
| TC-032 | Listar números disponíveis | Alta | Integração |
| TC-033 | Vincular número a inbox nova | Crítica | Integração |
| TC-034 | Desvincular número remove/inativa inbox | Alta | Integração |
| TC-035 | Listar templates da WABA sincronizados | Alta | UI |
| TC-036 | Criar template novo com header de texto, body com variáveis, botões | Alta | UI |
| TC-037 | Template rejeitado pela Meta mostra motivo | Alta | UI |
| TC-038 | Upload de imagem/vídeo/doc pra header de template | Média | UI |
| TC-039 | Conexão expirada mostra notificação de reconexão | Média | UI |

##### TC-030 — Criar conexão WABA com credenciais válidas

**Prioridade**: Crítica

**Pré-condição**: ter credenciais Meta válidas (System User Token + WABA ID + Business Portfolio ID). Usar as credenciais da Atend Med BH em dev pra não mexer em prod.

**Passos**:
1. `Configurações → WhatsApp Connections → Nova conexão`
2. Tipo: "Meta Cloud API"
3. Preencher token, WABA ID, Business Portfolio ID
4. Salvar

**Resultado esperado**: tela muda pra lista de números disponíveis (fetch da Meta bem sucedido). Nenhum erro visível.

##### TC-033 — Vincular número a inbox nova

**Prioridade**: Crítica

**Passos**:
1. Na conexão criada (TC-030), localizar um número de telefone "disponível" na lista
2. Clicar "Vincular a inbox"
3. Preencher nome da nova inbox (ex: "QA WA Teste")
4. Atribuir agentes
5. Salvar

**Resultado esperado**: inbox aparece no menu lateral; status do número muda pra "Vinculado"; envio e recebimento de mensagem funciona (validar via teste manual mandando WA pro número).

##### TC-036 — Criar template novo com header/body/botões

**Prioridade**: Alta

**Passos**:
1. `Configurações → WhatsApp Connections → <conexão> → Templates → Novo template`
2. Preencher:
   - Nome: `qa_test_template_01` (apenas lowercase e underscore)
   - Categoria: Marketing
   - Idioma: pt_BR
   - Header: tipo Texto, "Boas vindas"
   - Body: "Olá {{1}}, sua consulta foi confirmada para {{2}}."
   - Footer: "Mais Saúde 24h"
   - Botões: 2 botões de URL (cada um com texto + URL)
3. Salvar → Submeter à Meta

**Resultado esperado**: template aparece na lista com status "Em Análise"; em até 24h (ou minutos em dev, depende da Meta) status muda para Aprovado ou Rejeitado; UI reflete mudança via refresh ou sync manual.

##### TC-037 — Template rejeitado mostra motivo

**Prioridade**: Alta

**Passos**:
1. Criar template com conteúdo proposital inválido pra rejeição (ex: apenas letras caixa alta ou promoção agressiva "GANHE $$$$")
2. Submeter
3. Aguardar rejeição
4. Ver o template na lista

**Resultado esperado**: status "Rejeitado" com **motivo humano** visível (traduzido, não JSON da Meta). Ex: "A Meta rejeitou: mensagem promocional agressiva viola políticas".

> **Contexto**: em 2026-04 o feedback ficou genérico ("Invalid parameter") porque o backend não extraía `error_user_msg` da resposta da Meta. Foi corrigido em `custom/app/services/whatsapp_connections/meta/template_crud_service.rb`. Esse TC valida a correção.

---

### 5.5 Feature: Inbox WhatsApp Evolution (não oficial) — custom KLaOS

> **Contexto**: Evolution é API não-oficial que usa WhatsApp Web via QR code. Usado em casos onde cliente não tem (ou não quer) WABA oficial. A KLaOS mantém um pool centralizado de instâncias Evolution compartilhadas.

#### 5.5.1 User Story
> Como **admin do workspace**, quero **conectar um número de WhatsApp pessoal via QR code Evolution**, para **atender via WhatsApp mesmo sem ter conta oficial Meta (caso de clientes pequenos)**.

#### 5.5.2 Critérios de Aceitação

- **AC-5.1**: Em `Configurações → WhatsApp Connections → Nova conexão`, existe opção "Evolution".
- **AC-5.2**: Ao criar, sistema gera QR code visível na tela pra scanear com WhatsApp.
- **AC-5.3**: QR code tem expiração visível (30s) e regenera automaticamente.
- **AC-5.4**: Após scan, status muda pra "Conectado" sem reload manual (polling).
- **AC-5.5**: Número conectado é listado, é possível vincular a inbox nova.
- **AC-5.6**: É possível desvincular (unlink) o número — remove inbox e libera o slot.
- **AC-5.7**: Erros no Evolution (instância caída, número banido) mostram mensagem clara na UI, não stack trace.
- **AC-5.8**: Envio e recebimento de mensagens (texto, mídia, áudio) funciona como numa inbox WABA.

#### 5.5.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-040 | Gerar QR e conectar número via scan | Crítica | UI/Integração |
| TC-041 | QR expira e regenera sem intervenção | Alta | UI |
| TC-042 | Scan bem sucedido vincula número automaticamente | Alta | Integração |
| TC-043 | Desvincular número remove inbox | Alta | Integração |
| TC-044 | Receber mensagem de texto na Evolution inbox | Crítica | Integração |
| TC-045 | Enviar mensagem texto da Evolution inbox | Crítica | Integração |
| TC-046 | Enviar áudio pela Evolution | Alta | Integração |
| TC-047 | Evolution offline/instância caída mostra erro na UI | Alta | UI |

---

### 5.6 Feature: Envio de mensagem — texto

#### 5.6.1 User Story
> Como **agente**, quero **enviar mensagem de texto pro cliente numa conversa ativa**, para **responder dúvidas e dar continuidade ao atendimento**.

#### 5.6.2 Critérios de Aceitação

- **AC-6.1**: Dentro de uma conversa aberta, caixa de resposta no rodapé aceita texto de até X caracteres (limite do Chatwoot / canal).
- **AC-6.2**: Enter envia a mensagem (ou Ctrl+Enter, dependendo da preferência UI configurável).
- **AC-6.3**: Mensagem enviada aparece imediatamente na thread com marca "enviando" → "enviado" → "entregue" → "lido" (se canal suportar).
- **AC-6.4**: Mensagem fica gravada mesmo após refresh — sobrevive reconexão.
- **AC-6.5**: Se canal for WABA fora da janela de 24h, sistema bloqueia envio direto e sugere template.
- **AC-6.6**: Rich text (negrito, itálico, link, listas) funciona e renderiza correto no canal de destino.
- **AC-6.7**: Quoted reply (responder mensagem específica) funciona — a citação aparece na mensagem enviada.

#### 5.6.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-050 | Enviar mensagem de texto simples WABA | Crítica | Integração |
| TC-051 | Enviar mensagem no WebWidget | Crítica | Integração |
| TC-052 | Enviar na Evolution | Alta | Integração |
| TC-053 | Mensagem fora de janela 24h no WABA bloqueia | Crítica | UI |
| TC-054 | Quoted reply aparece corretamente | Alta | UI |
| TC-055 | Formatação rich text (negrito, link, lista) | Média | UI |
| TC-056 | Texto longo perto do limite (1024 chars WA) | Média | UI |
| TC-057 | Enter envia / Shift+Enter quebra linha | Alta | UI |
| TC-058 | Mensagem com emoji e acentos | Média | UI |
| TC-059 | Envio falha (server down) mostra erro e permite retry | Alta | Resiliência |

---

### 5.7 Feature: Envio de mensagem — mídia (imagem, áudio, documento, vídeo)

#### 5.7.1 User Story
> Como **agente**, quero **enviar imagens, áudios, PDFs e vídeos pro cliente**, para **comunicar visualmente (ex: foto do boleto, comprovante, áudio explicativo)**.

#### 5.7.2 Critérios de Aceitação

- **AC-7.1**: Caixa de resposta tem botão de anexo com opções (arquivo, imagem, áudio).
- **AC-7.2**: Drag-and-drop de arquivo na conversa abre preview antes de enviar.
- **AC-7.3**: Cada tipo tem limite de tamanho respeitado (imagem 5MB, vídeo 16MB, doc 100MB, áudio 16MB).
- **AC-7.4**: Envio acima do limite mostra erro antes de tentar (não espera rejeição do Meta).
- **AC-7.5**: Preview funciona: imagem mostra thumbnail, vídeo mostra player inline, PDF mostra ícone + nome, áudio mostra player.
- **AC-7.6**: Gravação de áudio direto no Frontdesk funciona (se feature habilitada). **Importante**: em 2026-04 corrigimos bug onde áudio Opus era rejeitado pela Meta (erro 131053). Hoje áudio é enviado via Meta Media API com MIME correto. QA valida que o áudio gravado chega no WhatsApp do cliente.
- **AC-7.7**: Em WABA, fora da janela de 24h, mídia é bloqueada igual texto.

#### 5.7.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-060 | Enviar imagem JPG via drag-drop | Crítica | UI |
| TC-061 | Enviar imagem PNG com alpha | Alta | UI |
| TC-062 | Enviar PDF de boleto | Crítica | UI |
| TC-063 | Gravar áudio e enviar (valida fix 131053) | **Crítica** | Integração |
| TC-064 | Enviar vídeo curto (<16MB) | Alta | Integração |
| TC-065 | Imagem acima do limite mostra erro antes de enviar | Alta | UI |
| TC-066 | Imagem + texto juntos | Alta | UI |
| TC-067 | Documento com nome com espaço/acento | Média | UI |
| TC-068 | Áudio no Evolution (unofficial WhatsApp) | Alta | Integração |

##### TC-063 — Gravar áudio e enviar (valida fix 131053)

**Prioridade**: Crítica

> **Contexto**: em 2026-04 cliente mandava áudio via WhatsApp web (Lara), bot respondia com áudio mas o Meta rejeitava com erro 131053 (MIME type audio/opus não aceito via URL). Foi corrigido em `custom/` reescrevendo pra usar Meta Media API upload direto. Esse TC é o teste de regressão.

**Passos**:
1. Abrir uma conversa ativa WABA
2. Clicar no ícone de microfone na caixa de resposta
3. Autorizar acesso ao microfone (primeira vez)
4. Falar 5 segundos
5. Parar gravação
6. Enviar

**Resultado esperado**:
- Áudio aparece na thread do Frontdesk como enviado (status ✓)
- Áudio é efetivamente recebido no WhatsApp do cliente (validar no celular do QA)
- Sem erro 131053 nem qualquer stack trace
- Áudio é playable (não corrompido)

---

### 5.8 Feature: Templates WhatsApp — criar, submeter, enviar

Ver §5.4.3 (TC-035 a TC-039) que cobrem o ciclo de criação/submissão. Aqui focamos em **usar** template numa conversa.

#### 5.8.1 User Story
> Como **agente**, quero **enviar um template aprovado pra abrir ou reabrir uma conversa WhatsApp**, para **contatar proativamente o cliente (ex: cobrança 0d, lembrete de consulta) ou reabrir janela fora das 24h**.

#### 5.8.2 Critérios de Aceitação

- **AC-8.1**: Em conversa WABA, botão "Enviar template" acessível na caixa de resposta.
- **AC-8.2**: Modal abre com lista de templates **aprovados** da WABA da inbox (rejeitados e em análise não aparecem ou aparecem bloqueados).
- **AC-8.3**: Selecionar template mostra preview com campos `{{1}}`, `{{2}}` editáveis.
- **AC-8.4**: Template com header de imagem/vídeo/doc: upload de mídia antes de enviar é obrigatório.
- **AC-8.5**: Botões do template (CTA de URL, reply) aparecem corretamente na conversa após envio.
- **AC-8.6**: Template enviado aparece na thread com conteúdo final (variáveis substituídas).
- **AC-8.7**: Se cliente responde um template, abre janela de 24h e mensagens livres fluem.

#### 5.8.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-070 | Enviar template aprovado com 2 variáveis | Crítica | Integração |
| TC-071 | Template sem variáveis | Alta | UI |
| TC-072 | Template com header de imagem | Alta | UI |
| TC-073 | Template com botões CTA (URL) | Alta | UI |
| TC-074 | Lista exibe só aprovados | Alta | UI |
| TC-075 | Reabrir janela 24h via template | Crítica | Integração |
| TC-076 | Template com variável vazia mostra validação | Alta | UI |

---

### 5.9 Feature: Atribuição de conversa (agente, time, remoção)

#### 5.9.1 User Story
> Como **agente** (ou **admin**), quero **atribuir uma conversa a mim mesmo, a outro agente ou a um time**, para **sinalizar quem é responsável e permitir filtragem "minhas conversas"**.

#### 5.9.2 Critérios de Aceitação

- **AC-9.1**: Dentro da conversa, sidebar direita tem seletor "Agente" com lista dos agentes da inbox + opção "Atribuir a mim".
- **AC-9.2**: Mudar agente grava imediatamente e mostra toast "Atribuído a X".
- **AC-9.3**: Conversa atribuída aparece na tab "Minhas" do agente atribuído.
- **AC-9.4**: Seletor "Time" funciona — conversa fica associada ao time, mas ainda precisa agente individual.
- **AC-9.5**: "Remover atribuição" volta a conversa pra tab "Não atribuídas".
- **AC-9.6**: Agente só pode ser atribuído se for colaborador da inbox (outros ficam fora do dropdown).
- **AC-9.7**: Notificação dispara pro novo agente ao ser atribuído (sininho + email se config).

#### 5.9.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-080 | Atribuir a mim aparece em "Minhas" | Crítica | UI |
| TC-081 | Atribuir a outro agente — agente recebe notificação | Crítica | Integração |
| TC-082 | Atribuir time "cobrança" | Alta | UI |
| TC-083 | Remover atribuição volta pra "Não atribuídas" | Alta | UI |
| TC-084 | Dropdown só mostra colaboradores da inbox | Alta | UI |
| TC-085 | Atribuição em conversa pending também funciona | Média | UI |

---

### 5.10 Feature: Status da conversa (open, pending, resolved, snoozed)

#### 5.10.1 User Story
> Como **agente**, quero **marcar conversas como resolvidas, adiar retorno (snooze), ou deixar em aberto**, para **organizar o fluxo de trabalho e garantir que nada caia no esquecimento**.

#### 5.10.2 Critérios de Aceitação

- **AC-10.1**: Toolbar da conversa tem botão "Resolver" sempre visível.
- **AC-10.2**: Resolver muda status pra `resolved` e a conversa some da tab "Ativas" (conforme §5.2 AC-2.3).
- **AC-10.3**: Conversa resolvida pode ser reaberta manualmente (botão "Reabrir").
- **AC-10.4**: Nova mensagem do cliente em conversa resolvida reabre automaticamente (volta pra `open`).
- **AC-10.5**: Botão "Adiar (snooze)" oferece: 1h, amanhã, próxima semana, data customizada.
- **AC-10.6**: Conversa adiada volta sozinha pra `open` na data/horário escolhido.
- **AC-10.7**: Status `pending` é entrada automática em inboxes com bot ativo — agente pode mudar manualmente pra `open`.

#### 5.10.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-090 | Resolver conversa — some de Ativas | Crítica | UI |
| TC-091 | Reabrir manual volta pra Ativas | Alta | UI |
| TC-092 | Nova mensagem em resolvida reabre automaticamente | Crítica | Integração |
| TC-093 | Snooze por 1h — conversa reativa após 1h | Alta | Funcional |
| TC-094 | Snooze data customizada futura | Média | UI |
| TC-095 | Pending → Open manual (simular handoff) | Alta | UI |
| TC-096 | Ao resolver, opcional: comentário/resolução note | Baixa | UI |

> **Contexto pro QA**: em 2026-04, notou-se que a Mais Saúde tem 15 conversas em `pending` sem assignee há semanas — são conversas onde o bot Lara atendeu mas não transbordou. O problema é no KLaOS (falta lógica de handoff), mas no Frontdesk o QA deve confirmar que a UI permite ao agente **manualmente** fazer o handoff (pending → open + atribuir a si mesmo ou time) sem erros.

---

### 5.11 Feature: Private Notes (notas internas)

#### 5.11.1 User Story
> Como **agente**, quero **adicionar notas internas numa conversa visíveis só pro time, não pro cliente**, para **coordenar com colegas, deixar contexto, ou marcar informações sem poluir o chat com o cliente**.

#### 5.11.2 Critérios de Aceitação

- AC-11.1: Na caixa de resposta, toggle "Resposta / Nota" alterna entre mensagem pública e privada.
- AC-11.2: Nota privada tem fundo amarelo/laranja claramente diferente de mensagem pública.
- AC-11.3: Notas não aparecem no WhatsApp/site do cliente (verificar via teste real).
- AC-11.4: `@mencionar agente` em nota dispara notificação pro mencionado.
- AC-11.5: Notas são visíveis pra TODOS os agentes colaboradores da inbox (não só o autor).

#### 5.11.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-100 | Toggle mensagem/nota altera caixa visualmente | Alta | UI |
| TC-101 | Nota NÃO é entregue ao cliente | Crítica | Integração |
| TC-102 | @mention em nota notifica o mencionado | Alta | Integração |
| TC-103 | Nota aparece na thread com destaque | Média | UI |

---

### 5.12 Feature: Etiquetas (Labels)

#### 5.12.1 User Story
> Como **admin** ou **agente**, quero **aplicar etiquetas em conversas (ex: `cobranca-7d`, `pagamento-realizado`)**, para **categorizar, filtrar e gerar relatórios por contexto**.

#### 5.12.2 Critérios de Aceitação

- AC-12.1: Em `Configurações → Etiquetas`, CRUD completo de labels (criar, editar nome/cor/descrição, deletar).
- AC-12.2: Aplicar/remover etiqueta na conversa via sidebar; múltiplas etiquetas por conversa permitido.
- AC-12.3: Filtrar lista de conversas por etiqueta pelo menu lateral funciona.
- AC-12.4: Etiqueta deletada é removida das conversas onde estava aplicada (sem erro).

#### 5.12.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-110 | Criar etiqueta "qa-teste" cor azul | Alta | UI |
| TC-111 | Aplicar 3 etiquetas simultâneas numa conversa | Alta | UI |
| TC-112 | Filtrar conversas por etiqueta via menu | Alta | UI |
| TC-113 | Editar cor e nome da etiqueta reflete em todas conversas | Média | UI |
| TC-114 | Deletar etiqueta em uso não quebra conversas | Média | UI |

---

### 5.13 Feature: Macros

#### 5.13.1 User Story
> Como **admin**, quero **criar sequências de ações automatizadas (macros)**, para **agentes executarem fluxos repetitivos com 1 clique (ex: "Saudação padrão" aplica label + envia mensagem + atribui time)**.

#### 5.13.2 Critérios de Aceitação

- AC-13.1: `Configurações → Macros → Nova macro` permite encadear ações: Enviar mensagem, Atribuir agente/time, Adicionar/remover etiqueta, Mudar status, Adicionar nota privada, Atualizar atributo custom.
- AC-13.2: Macro pode ser Pessoal (só do criador) ou Pública (time toda).
- AC-13.3: Executar macro manualmente na conversa via botão na sidebar.
- AC-13.4: Feedback visual ao executar (toast "Macro X executada"). Se uma ação falhar, as outras continuam ou param? (documentar comportamento)
- AC-13.5: Editar macro em uso não quebra conversas anteriores (execução passada não é re-executada).

#### 5.13.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-120 | Criar macro com 3 ações (msg + label + atribuir) | Alta | UI |
| TC-121 | Executar macro pública — ações aplicadas | Crítica | UI |
| TC-122 | Macro pessoal não aparece pra outros agentes | Alta | UI |
| TC-123 | Editar macro não afeta execuções passadas | Média | UI |
| TC-124 | Macro com falha parcial — feedback adequado | Média | UI |

---

### 5.14 Feature: Respostas Prontas (Canned Responses)

#### 5.14.1 User Story
> Como **agente**, quero **salvar respostas frequentes e usar via atalho**, para **responder mais rápido sem digitar tudo toda vez**.

#### 5.14.2 Critérios de Aceitação

- AC-14.1: `Configurações → Respostas Prontas → Nova` aceita título, conteúdo, código curto (shortcode).
- AC-14.2: Na caixa de resposta, digitar `/<shortcode>` autocompleta a resposta pronta.
- AC-14.3: Variáveis como `{{contact.name}}` são substituídas ao inserir.
- AC-14.4: Respostas prontas podem ser pessoais (só agente) ou compartilhadas.

#### 5.14.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-130 | Criar resposta pronta "saudacao" | Alta | UI |
| TC-131 | Autocompletar via `/saudacao` funciona | Alta | UI |
| TC-132 | Variáveis de contato são substituídas | Alta | UI |
| TC-133 | Compartilhada aparece pra todos agentes | Média | UI |

---

### 5.15 Feature: Atributos Customizados (Custom Attributes)

#### 5.15.1 User Story
> Como **admin**, quero **definir campos extras em Conversation e Contact (ex: `plano_saude`, `numero_carteirinha`)**, para **armazenar metadados do cliente e usar em filtros/relatórios**.

#### 5.15.2 Critérios de Aceitação

- AC-15.1: `Configurações → Atributos customizados → Novo` permite escolher: nome, tipo (texto/número/data/select/checkbox/link/lista), escopo (conversation/contact), obrigatório?
- AC-15.2: Atributos aparecem na sidebar das conversas / detalhes de contato, editáveis inline.
- AC-15.3: Atributos tipo "select" têm options configurável.
- AC-15.4: **CRM Bridge** (custom KLaOS) cria automaticamente 10 atributos em workspaces com webhook KLaOS (`crm_deal_id`, `crm_deal_name`, `crm_deal_value`, `crm_deal_stage`, `crm_lead_score`, `crm_pipeline`, `crm_deal_owner`, `crm_deal_url`, `scheduled_at`, `scheduling_link`, `closer_assigned`).

#### 5.15.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-140 | Criar atributo "plano_saude" select com 3 options | Alta | UI |
| TC-141 | Editar valor de atributo na sidebar da conversa | Alta | UI |
| TC-142 | Atributos CRM Bridge são criados automaticamente | Alta | Integração |
| TC-143 | Deletar atributo em uso remove valores existentes | Média | UI |

---

### 5.16 Feature: Automação (Automation Rules)

#### 5.16.1 User Story
> Como **admin**, quero **criar regras que disparam ações automaticamente (ex: "se label=cobranca-7d então atribuir ao time cobrança")**, para **reduzir trabalho manual repetitivo**.

#### 5.16.2 Critérios de Aceitação

- AC-16.1: `Configurações → Automação → Nova regra` permite: evento trigger (Conversa criada / Mensagem criada / Conversa atualizada), condições (múltiplas com AND/OR), ações.
- AC-16.2: Regra pode estar ativa/pausada.
- AC-16.3: Teste de uma regra é possível (seleciona conversa teste, vê se a regra dispararia).
- AC-16.4: Regra com ação sobre template WA exige template aprovado.
- AC-16.5: Histórico de execuções é visível (opcional, dependendo da versão).

#### 5.16.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-150 | Criar regra "nova conversa WA → atribuir time cobrança" | Alta | Funcional |
| TC-151 | Regra dispara ao criar conversa que bate condição | Alta | Integração |
| TC-152 | Regra pausada não dispara | Alta | Funcional |
| TC-153 | Regra com ação inválida (template inexistente) mostra erro | Média | UI |

---

### 5.17 Feature: Gestão de Contatos (CRUD + import)

#### 5.17.1 User Story
> Como **admin**, quero **gerenciar a base de contatos do workspace (criar, editar, deletar, importar em lote)**, para **manter dados atualizados e iniciar contato ativo com clientes**.

#### 5.17.2 Critérios de Aceitação

- AC-17.1: Menu `Contatos` mostra lista paginada com busca por nome/email/telefone.
- AC-17.2: "Novo contato" aceita nome, email, telefone, foto, company, atributos custom.
- AC-17.3: Merge de contatos duplicados funciona (combina conversas, atributos).
- AC-17.4: Import CSV com mapeamento de colunas funciona; valida formato; reporta erros por linha.
- AC-17.5: Export CSV/JSON funciona.
- AC-17.6: Perfil do contato mostra histórico de conversas e atributos.

#### 5.17.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-160 | Criar contato com todos os campos | Alta | UI |
| TC-161 | Editar contato existente | Alta | UI |
| TC-162 | Merge 2 contatos duplicados | Média | UI |
| TC-163 | Import CSV 100 contatos | Alta | Integração |
| TC-164 | Import CSV com erros reporta linha específica | Média | UI |
| TC-165 | Export CSV completo | Média | UI |
| TC-166 | Busca por telefone parcial funciona | Alta | UI |

---

### 5.18 Feature: Gestão de Agentes

#### 5.18.1 User Story
> Como **admin do workspace**, quero **convidar, editar role e remover agentes**, para **gerenciar quem tem acesso e com qual permissão**.

> **Nota**: provisionamento principal via KLaOS — ver §5.1. Essa feature cobre a UI do Frontdesk pra gestão direta (fallback quando KLaOS está fora).

#### 5.18.2 Critérios de Aceitação

- AC-18.1: `Configurações → Agentes` lista todos, com role, status (online/offline), última atividade.
- AC-18.2: "Adicionar Agente" via convite por email (Frontdesk manda o convite).
- AC-18.3: Editar role de agente (agent ↔ admin) pelo dropdown.
- AC-18.4: Remover agente — confirmação + remove de `account_users`.
- AC-18.5: Agente removido não consegue mais logar naquele workspace.

#### 5.18.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-170 | Convidar agente via email | Alta | Integração |
| TC-171 | Mudar role agent → admin | Alta | UI |
| TC-172 | Remover agente — não consegue logar | Alta | Integração |
| TC-173 | Convite pra email já existente alerta duplicado | Média | UI |

---

### 5.19 Feature: Times (Teams)

#### 5.19.1 User Story
> Como **admin**, quero **criar times (ex: "cobrança", "consultas") e associar agentes**, para **direcionar conversas em grupo e relatórios por team**.

#### 5.19.2 Critérios de Aceitação

- AC-19.1: `Configurações → Times → Novo` aceita nome, descrição, política de atribuição (manual / round-robin).
- AC-19.2: Adicionar/remover agente do time via UI.
- AC-19.3: Conversa atribuída a time aparece na "Caixa do Time" no menu lateral.
- AC-19.4: Deletar time — conversas desvinculadas mas não deletadas.

#### 5.19.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-180 | Criar time "qa-teste" | Alta | UI |
| TC-181 | Adicionar 3 agentes ao time | Alta | UI |
| TC-182 | Atribuir conversa ao time — aparece na caixa dele | Alta | UI |
| TC-183 | Deletar time não apaga conversas | Média | UI |

---

### 5.20 Feature: Relatórios

#### 5.20.1 User Story
> Como **admin**, quero **visualizar métricas de atendimento (volume, tempo de resposta, CSAT, agentes, inboxes)**, para **acompanhar performance da operação e identificar gargalos**.

#### 5.20.2 Critérios de Aceitação

- AC-20.1: Menu "Relatórios" mostra abas: Visão geral, Agentes, Inboxes, Etiquetas, Times, CSAT.
- AC-20.2: Filtros de data (últimos 7/30/90 dias, customizado).
- AC-20.3: Gráficos renderizam sem erro — zero dados mostra "sem dados" ao invés de gráfico vazio.
- AC-20.4: Export CSV de cada relatório funciona.
- AC-20.5: Métricas batem com realidade (spot-check manual vs. o que QA sabe que existe no workspace).

#### 5.20.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-190 | Visão geral carrega com dados dos últimos 7 dias | Alta | UI |
| TC-191 | Filtro customizado de data aplica | Alta | UI |
| TC-192 | Relatório de Agente mostra métricas individuais | Alta | UI |
| TC-193 | Export CSV da visão geral abre corretamente | Média | UI |
| TC-194 | Relatório sem dados mostra mensagem, não gráfico vazio | Média | UI |
| TC-195 | CSAT — survey sendo enviado e agregado | Baixa | Integração |

---

### 5.21 Feature: Campanhas

#### 5.21.1 User Story
> Como **admin**, quero **criar campanhas proativas (WhatsApp, SMS, Live Chat)**, para **engajar clientes em massa (ex: lembrete de pagamento pra todos cobranca-7d)**.

#### 5.21.2 Critérios de Aceitação

- AC-21.1: `Campanhas → Nova` oferece tipo: One-off (pontual) ou Ongoing (recorrente).
- AC-21.2: Destino: inbox específica, segmento de contatos, lista de labels.
- AC-21.3: Para WA/SMS, template aprovado obrigatório.
- AC-21.4: Agendamento de envio (data/hora).
- AC-21.5: Dashboard da campanha mostra enviado/entregue/respondido.

#### 5.21.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-200 | Criar campanha WA one-off com template aprovado | Alta | Integração |
| TC-201 | Segmento por label "cobranca-7d" | Alta | UI |
| TC-202 | Agendar envio futuro | Alta | Funcional |
| TC-203 | Dashboard reporta taxa de entrega | Média | UI |

---

### 5.22 Feature: Central de Ajuda (Help Center)

#### 5.22.1 User Story
> Como **admin**, quero **publicar base de conhecimento (artigos, FAQs) com portal público**, para **reduzir dúvidas repetitivas e dar autoatendimento aos clientes**.

#### 5.22.2 Critérios de Aceitação

- AC-22.1: Criar portal com nome, slug, idioma, domínio customizado.
- AC-22.2: Categorias em árvore; artigos com rich editor (título, conteúdo, tags).
- AC-22.3: Portal publicado fica acessível na URL pública.
- AC-22.4: Busca no portal funciona.
- AC-22.5: Artigos têm status draft/published/archived.

#### 5.22.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-210 | Criar portal + categoria + artigo | Média | UI |
| TC-211 | Publicar artigo torna visível na URL pública | Média | Integração |
| TC-212 | Busca encontra artigo | Média | UI |
| TC-213 | Artigo em rascunho não aparece | Baixa | UI |

---

### 5.23 Feature: Widget embedding (script de instalação)

> Complementa §5.3. Aqui foca na instalação e configuração do lado do site do cliente.

#### 5.23.1 User Story
> Como **admin do site (ex: TI da Mais Saúde)**, quero **instalar o widget no site com 1 linha de JS**, para **os visitantes terem chat ao vivo sem precisar de app/login**.

#### 5.23.2 Critérios de Aceitação

- AC-23.1: Snippet JS funciona em páginas HTML estáticas e em SPAs (React, Vue).
- AC-23.2: Identificação de usuário logado via `window.$chatwoot.setUser({ identifier, name, email, ... })` funciona.
- AC-23.3: Idioma do widget detectado do browser ou configurável via `window.chatwootSettings.locale`.
- AC-23.4: Pré-chat form exibe campos configurados antes de permitir conversa.
- AC-23.5: Widget sobrevive navegação entre páginas (não perde histórico).

#### 5.23.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-220 | Instalar em página HTML simples | Crítica | UI |
| TC-221 | Setar user identificado → mensagens amarradas ao contato | Alta | Integração |
| TC-222 | Detectar idioma do browser (pt_BR) | Média | UI |
| TC-223 | Pré-chat form obrigatório bloqueia sem preencher | Alta | UI |
| TC-224 | Widget persiste navegação SPA | Alta | UI |

---

### 5.24 Feature: CRM Bridge (push de dados do deal) — custom KLaOS

> Custom KLaOS: `custom/app/controllers/api/v1/accounts/crm_bridge_controller.rb`. Permite que o KLaOS (ou qualquer external system autorizado) atualize atributos de CRM direto numa conversa/contato do Frontdesk.

#### 5.24.1 User Story
> Como **sistema KLaOS CRM**, quero **enviar dados do deal pra uma conversa específica do Frontdesk (valor, stage, owner, agendamento)**, para **o agente humano ver contexto comercial direto na sidebar sem alt-tab**.

#### 5.24.2 Critérios de Aceitação

- AC-24.1: Endpoint `PUT /api/v1/accounts/:account_id/conversations/:conv_id/deal` aceita payload com campos CRM.
- AC-24.2: Atributos são gravados como custom_attributes da conversa (visíveis na sidebar do Frontdesk).
- AC-24.3: Endpoint idempotente — chamada repetida atualiza em vez de duplicar.
- AC-24.4: `DELETE /deal` limpa os atributos.
- AC-24.5: `POST /contacts/:contact_id/deal` atualiza contact-level também.
- AC-24.6: Autenticação obrigatória (access_token admin); request sem auth retorna 401.

#### 5.24.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-230 | Push deal: aparece na sidebar da conversa | Alta | Integração |
| TC-231 | Atualizar deal existente substitui valores | Alta | Integração |
| TC-232 | Delete deal limpa sidebar | Alta | Integração |
| TC-233 | Chamada sem auth retorna 401 | Alta | Segurança |

> **Nota pra Davi**: esse endpoint é chamado pelo KLaOS, não pela UI. O QA pode validar **o efeito final** (dados aparecem na sidebar da conversa) olhando uma conversa que o KLaOS agente tenha enriquecido. Ou usar Postman pra simular a chamada (o QA lead pode ajudar com as credenciais).

---

### 5.25 Feature: AI Bridge — provisionamento de agent_bot (custom KLaOS)

> Custom KLaOS. Ao criar um agent_instance no KLaOS, o sistema chama a Platform API do Frontdesk pra criar o `agent_bot` correspondente. O bot aparece disponível pro admin escolher em inbox.

#### 5.25.1 User Story
> Como **admin KLaOS**, quero **criar um agente de IA no KLaOS e ele automaticamente aparecer disponível no Frontdesk pra ser vinculado a uma inbox**, para **não gerenciar manualmente tokens, webhooks e sincronização**.

#### 5.25.2 Critérios de Aceitação

- AC-25.1: Agente criado no KLaOS com `status=active` aparece em `Configurações → Inbox → <qualquer> → AI Bridge` no Frontdesk em até 30s.
- AC-25.2: Nome do bot segue convenção `<display_name> | <slug>` (ex: `Klaus | klaus-gmt90d`) quando há múltiplos bots no mesmo workspace.
- AC-25.3: Admin do workspace pode vincular o bot a uma inbox via dropdown.
- AC-25.4: Bot vinculado recebe webhooks (validar via mandar mensagem teste na inbox e ver o bot responder).
- AC-25.5: Deletar agent_instance no KLaOS → bot removido da lista do Frontdesk.
- AC-25.6: Nomes idênticos no mesmo workspace não causam ambiguidade (KLaOS garante unicidade via suffix).

#### 5.25.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-240 | Criar agente KLaOS → aparece disponível no Frontdesk | Crítica | Integração |
| TC-241 | Vincular bot a inbox → bot responde msg do cliente | Crítica | Integração |
| TC-242 | Deletar agente KLaOS → bot removido | Alta | Integração |
| TC-243 | Múltiplos bots mesmo nome não ambíguos | Média | UI |

---

### 5.26 Feature: Enriquecimento de Webhook Payload — custom KLaOS

> Custom KLaOS: `custom/config/initializers/webhook_payload_enrichment.rb`. Adiciona `channel_type`, `channel_name`, `provider` aos payloads de webhook outgoing do Frontdesk pra o KLaOS saber qual canal processar.

#### 5.26.1 User Story
> Como **sistema KLaOS**, quero **receber o tipo de canal (Channel::Whatsapp, Channel::WebWidget, etc.) no payload de webhook**, para **rotear corretamente sem precisar de query extra**.

#### 5.26.2 Critérios de Aceitação

- AC-26.1: Qualquer webhook outgoing do Frontdesk (message_created, conversation_created, etc.) contém campos `channel_type`, `channel_name`, `provider` no payload.
- AC-26.2: Valor de `channel_type` é o nome da classe Rails (ex: `Channel::Whatsapp`).
- AC-26.3: Valor de `provider` reflete o provedor real (ex: `meta_cloud` ou `evolution` pra WhatsApp).

#### 5.26.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-250 | Webhook de WhatsApp WABA tem `provider=meta_cloud` | Alta | Integração |
| TC-251 | Webhook de Evolution tem `provider=evolution` | Alta | Integração |
| TC-252 | Webhook de Widget tem `channel_type=Channel::WebWidget` | Média | Integração |

> **Validação do QA**: Davi pode validar visualmente usando um serviço de captura de webhook tipo [webhook.site](https://webhook.site). Configura o webhook outgoing de um workspace de teste pra apontar pra URL do webhook.site, dispara ações no Frontdesk, e lê os payloads capturados.

---

### 5.27 Feature: Super Admin (backoffice KLaOS)

> Perspectiva **funcionário KLaOS**. Acesso em `/super_admin/`.

#### 5.27.1 User Story
> Como **funcionário KLaOS com acesso super admin**, quero **gerenciar accounts, users, platform apps e installation configs**, para **suportar clientes, auditar, e configurar o ambiente global**.

#### 5.27.2 Critérios de Aceitação

- AC-27.1: Super Admin login requer senha separada (ou 2FA).
- AC-27.2: Menu tem: Users, Accounts, Platform Apps, Installation Configs, Access Tokens.
- AC-27.3: Usuários podem ser buscados por email; perfil mostra todos accounts associados.
- AC-27.4: Accounts podem ser criados, editados, suspensos, deletados.
- AC-27.5: Platform Apps: criar/revogar tokens de integração (usado pra KLaOS → Frontdesk).
- AC-27.6: Installation Configs: editar chaves como `DEPLOYMENT_ENV`, `INSTALLATION_PRICING_PLAN`.
- AC-27.7: Deletar user em cascade remove dados relacionados sem quebrar sistema.

#### 5.27.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-260 | Login Super Admin | Crítica | Segurança |
| TC-261 | Buscar user por email | Alta | UI |
| TC-262 | Criar account de teste | Alta | UI |
| TC-263 | Suspender account — users não conseguem logar | Alta | Integração |
| TC-264 | Criar Platform App + gerar token | Crítica | Segurança |
| TC-265 | Revogar Platform App token — API para funcionar | Crítica | Segurança |
| TC-266 | Editar Installation Config `INSTALLATION_PRICING_PLAN` | Média | UI |
| TC-267 | Deletar user via Super Admin sem quebrar conversas dele | Alta | UI |

---

### 5.28 Feature: Configurações da conta (workspace)

#### 5.28.1 User Story
> Como **admin do workspace**, quero **configurar detalhes gerais da conta (timezone, logo, nome, features)**, para **personalizar o Frontdesk pra realidade da minha operação**.

#### 5.28.2 Critérios de Aceitação

- AC-28.1: `Configurações → Geral` permite editar: nome, logo, cor primária, timezone, idioma default.
- AC-28.2: Mudança de timezone reflete em horários mostrados na UI.
- AC-28.3: Logo personalizado aparece no menu lateral (não o default Chatwoot).
- AC-28.4: Notificações: admin pode configurar quais eventos disparam email/push.
- AC-28.5: Appearance: tema claro/escuro aplica imediatamente.

#### 5.28.3 Test Cases

| ID | Título | Prioridade | Tipo |
|---|---|---|---|
| TC-270 | Editar nome do workspace reflete em todas as telas | Média | UI |
| TC-271 | Upload de logo — aparece no menu | Média | UI |
| TC-272 | Mudar timezone de SP pra NY — horários ajustam | Alta | UI |
| TC-273 | Tema escuro aplica sem reload | Baixa | UI |
| TC-274 | Desativar notificação de conversa_creation | Média | Funcional |

---

## 6. Anexos

### Anexo A — Labels da Mais Saúde (referência)
_(a preencher com lista completa das 19 labels observadas em prod)_

### Anexo B — Sign-off
| Papel | Nome | Data | Assinatura |
|---|---|---|---|
| QA Lead | | | |
| Product | Matheus Macedo | | |
| Eng Lead | | | |

### Anexo C — Bugs conhecidos em release
_(mantida durante execução)_

### Anexo D — Riscos
_(mantida durante execução)_
