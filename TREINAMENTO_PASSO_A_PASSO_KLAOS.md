# TREINAMENTO PASSO A PASSO
## KLaOS + Frontdesk: Implementacao Completa
### Guia Pratico para Onboarding de Clientes

---

# SOBRE ESTE GUIA

Este guia parte do principio que a conta Frontdesk **ja esta provisionada**. Ele cobre desde o acesso inicial ate uma operacao de cobranca completa funcionando, conectando todas as pontas entre KLaOS, Frontdesk, CRM e Collections.

**Publico:** Membro da equipe KLaOS aplicando a plataforma no cliente
**Pre-requisitos:** Conta Frontdesk ja provisionada, credenciais de acesso, dados do TENEX do cliente

---

# ROTEIRO COMPLETO

```
FASE 1 - ACESSO
  1.1 Login no KLaOS
  1.2 Ativar Engines
  1.3 Primeiro acesso ao Frontdesk via SSO

FASE 2 - GESTAO DE USUARIOS
  2.1 Convidar membros no KLaOS
  2.2 Provisionar membros no Frontdesk
  2.3 Gerenciar funcoes e permissoes
  2.4 Acesso dos membros ao Frontdesk via SSO

FASE 3 - CONFIGURACAO DO FRONTDESK
  3.1 Criar equipes
  3.2 Criar labels (etiquetas)
  3.3 Criar canal WhatsApp
  3.4 Verificar templates
  3.5 Criar respostas rapidas

FASE 4 - CRM
  4.1 Cadastrar empresa
  4.2 Configurar pipeline
  4.3 Criar contatos

FASE 5 - COBRANCA (COLLECTIONS)
  5.1 Conectar TENEX
  5.2 Sincronizar e validar devedores
  5.3 Criar campanha de cobranca
  5.4 Matricular devedores
  5.5 Ativar e monitorar

FASE 6 - AI AGENT
  6.1 Criar agente de IA
  6.2 Conectar ao Frontdesk (AI Bridge)
  6.3 Testar

FASE 7 - OPERACAO DIARIA
  7.1 Rotina do atendente
  7.2 Rotina do gestor
```

---

# FASE 1 - ACESSO

## 1.1 Login no KLaOS

1. Abra o navegador e acesse a URL do KLaOS
2. Na tela de login, preencha:
   - **Email** (campo com icone de envelope)
   - **Senha** (campo com icone de cadeado - clique no olho para mostrar)
3. Marque **"Lembrar de mim"** se desejar
4. Clique em **Entrar**
5. Aguarde o carregamento (mensagens: "Entrando..." → "Carregando workspace..." → "Quase la...")
6. Voce chegara ao **Dashboard**

O Dashboard mostra:
- **Engines Ativas** - quantos modulos estao ligados
- **Documentos na Base** - base de conhecimento da IA
- **Sessoes com Klaus** - conversas com o assistente
- Acoes rapidas: Falar com Klaus, Adicionar Conhecimento, Explorar Engines

## 1.2 Ativar Engines

Engines sao modulos que voce liga conforme a necessidade. Para o fluxo completo:

1. No menu lateral, clique em **Engines** (icone de caixas)
2. Na secao **"Plugaveis"**, ative os toggles das seguintes engines:

| Engine | O que habilita | Toggle |
|---|---|---|
| **Frontdesk** | Central de atendimento, conversas, canais WhatsApp | LIGAR |
| **CRM** | Contatos, empresas, pipeline Kanban, tarefas | LIGAR |
| **Collections** | Campanhas de cobranca, devedores, regua automatica | LIGAR |
| **AI Agents** | Agentes de IA, respostas automaticas, handoff | LIGAR |

3. Clique no **toggle** de cada engine (cinza = desligada, azul = ligada)
4. Se aparecer aviso amarelo "Requer [engine]", ative a dependencia primeiro
5. Apos ativar, os menus aparecem no menu lateral:
   - **CRM** (Contatos, Empresas, Negocios)
   - **Funil > Cobranca**
   - **Atendimento > Frontdesk** e **Atendimento > Agents**

**Dica:** Clique na seta ao lado de cada engine para expandir e ver suas funcionalidades.

## 1.3 Primeiro Acesso ao Frontdesk via SSO

1. No menu lateral, clique em **Atendimento > Frontdesk**
2. Voce vera o Frontdesk Portal com status **Ativa** (verde)
3. Clique no botao **Abrir Frontdesk** (canto superior direito)
4. Uma nova aba abre no navegador - voce e logado automaticamente via SSO
5. Nao precisa digitar senha - o KLaOS gera um link seguro temporario (expira em 5 minutos)

**Voce agora esta no Frontdesk.** O menu lateral mostra:
- Caixa de Entrada, Conversas, Equipes, Labels
- Contatos, Empresas
- Relatorios
- Configuracoes

**Importante:** Toda vez que precisar acessar o Frontdesk, use o botao "Abrir Frontdesk" no KLaOS. Isso garante o login automatico via SSO.

---

# FASE 2 - GESTAO DE USUARIOS

Quando um novo membro da equipe precisa acessar a plataforma, siga este fluxo:

## 2.1 Convidar Membro no KLaOS

1. No KLaOS, acesse **Settings** (icone de engrenagem no menu lateral)
2. Clique na aba **Equipe** (Team)
3. Clique em **Convidar Membro**
4. No modal de convite, preencha:
   - **Email:** email do novo membro
   - **Funcao:**
     - **Admin** - acesso total (gestores)
     - **User** - acesso padrao (atendentes)
     - **Viewer** - somente leitura (supervisores)
5. Clique em **Enviar Convite**
6. O membro recebe um email com link de convite (expira em 7 dias)
7. Ao clicar no link, o membro cria sua conta e entra no workspace

**O que acontece:** O membro agora tem acesso ao KLaOS, mas **ainda nao tem acesso ao Frontdesk**. E preciso provisiona-lo (proximo passo).

## 2.2 Provisionar Membro no Frontdesk

Apos o membro aceitar o convite e entrar no KLaOS, provisione-o no Frontdesk:

1. No KLaOS, acesse **Atendimento > Frontdesk**
2. Clique na aba **Configuracoes** (Settings)
3. Voce vera a lista de **Usuarios do Frontdesk** com:

| Coluna | Descricao |
|---|---|
| Nome/Email | Identificacao do membro |
| Status | pending, active, invited, disabled, failed |
| Funcao | Administrator ou Agent |
| Acoes | Alterar funcao, Habilitar/Desabilitar, Sincronizar |

4. Novos membros aparecem com status **pending** ou nao aparecem ainda
5. Para provisionar membros pendentes, o sistema sincroniza automaticamente. Se necessario, clique em **Sincronizar** para forcar

**Mapeamento de funcoes KLaOS → Frontdesk:**

| Funcao no KLaOS | Funcao no Frontdesk | Permissoes |
|---|---|---|
| Owner / Admin | **Administrator** | Acesso total: configuracoes, equipes, relatorios, canais |
| User | **Agent** | Atender conversas, ver contatos, usar templates |
| Viewer | **Agent** | Mesmo que agent (acesso limitado) |

## 2.3 Alterar Funcao de um Membro

1. Na lista de Usuarios do Frontdesk (Configuracoes do Frontdesk Portal)
2. Encontre o membro na lista
3. No dropdown de **Funcao**, altere entre:
   - **Administrator** - acesso total ao Frontdesk
   - **Agent** - acesso para atender conversas
4. A alteracao e aplicada imediatamente

## 2.4 Acesso dos Membros ao Frontdesk via SSO

Cada membro acessa o Frontdesk pelo mesmo caminho:

1. Fazer login no KLaOS com suas credenciais
2. Clicar em **Atendimento > Frontdesk**
3. Clicar em **Abrir Frontdesk**
4. Nova aba abre logada automaticamente

**Nenhum membro precisa de senha separada para o Frontdesk.** O acesso e sempre via SSO pelo KLaOS.

---

# FASE 3 - CONFIGURACAO DO FRONTDESK

A partir daqui, trabalharemos dentro do Frontdesk (aba aberta via SSO).

## 3.1 Criar Equipes

Equipes organizam os atendentes por funcao e permitem distribuir conversas.

**No Frontdesk:**

1. Acesse **Configuracoes** (engrenagem no menu lateral) > **Equipes**
2. Clique em **Criar Equipe**
3. Preencha:
   - **Nome da Equipe:** (ex: FILA CONTRATOS)
   - **Descricao:** (ex: Cancelamentos, escalacoes D+21, ameacas legais)
   - **Atribuicao automatica:** Deixe marcado
4. Clique em **Criar**
5. Adicione os membros: busque pelo nome e clique para incluir
6. Clique em **Adicionar Agentes**

**Equipes recomendadas para cobranca:**

| Equipe | Funcao | Quem incluir |
|---|---|---|
| **FILA CONTRATOS** | Cancelamentos, D+21, escalacoes criticas | Gustavo (ou gestor) |
| **FILA BOLETOS** | Emissao de boletos, cartao recusado | Marta (ou financeiro) |
| **ATENDIMENTO GERAL** | Duvidas gerais, suporte | Todos os atendentes |

**Verificacao:** As equipes aparecem no menu lateral do Frontdesk na secao "Equipes". Clique em uma equipe para ver apenas suas conversas.

## 3.2 Criar Labels (Etiquetas)

Labels organizam as conversas por estagio e permitem filtrar rapidamente.

**No Frontdesk:**

1. Acesse **Configuracoes > Labels**
2. Clique em **Adicionar Label**
3. Para cada label:
   - Digite o **Nome** (exatamente como na tabela, minusculo)
   - Escolha a **Cor** no seletor
   - Marque **"Mostrar no menu lateral"**
   - Clique em **Criar**

**Crie na seguinte ordem:**

| # | Nome da Label | Cor Sugerida | Quando e Usada |
|---|---|---|---|
| 1 | pendente | Verde claro | Boleto emitido, inicio do fluxo |
| 2 | cobranca-0d | Amarelo | Dia do vencimento |
| 3 | cobranca-5d | Vermelho | 5 dias de atraso |
| 4 | cobranca-10d | Roxo | 10 dias de atraso |
| 5 | cobranca-15d | Laranja | 15 dias de atraso |
| 6 | transbordo-humano | Azul | Transferido para humano |
| 7 | pagamento-realizado | Verde escuro | Pagamento confirmado (final) |
| 8 | cobranca-promessa | Cinza claro | Cliente prometeu data |
| 9 | cobranca-negociacao | Cinza | Cliente negociando prazo |
| 10 | cancelamento-pendente | Vermelho escuro | Quer cancelar, esta inadimplente |

**Verificacao:** As labels aparecem no menu lateral do Frontdesk. Clique em uma label para ver todas as conversas com aquela etiqueta.

## 3.3 Criar Canal WhatsApp

O canal WhatsApp e por onde as mensagens de cobranca sao enviadas e recebidas.

**No Frontdesk:**

1. Acesse **Configuracoes > Canais de Entrada** (Inboxes)
2. Clique em **Adicionar Canal de Entrada**
3. Selecione **WhatsApp**
4. Selecione **WhatsApp Cloud** (oficial da Meta)
5. Preencha os campos com os dados fornecidos:

| Campo | Descricao | Exemplo |
|---|---|---|
| **Nome do Canal** | Nome amigavel | KLaOS Cobranca |
| **Numero de Telefone** | Formato E.164 | +5531972867733 |
| **Phone Number ID** | ID da Meta | 1088056767715946 |
| **Business Account ID** | WABA ID | 735467396201142 |
| **API Key** | Token de acesso | (token fornecido) |

6. Clique em **Criar Canal**
7. Na proxima tela, adicione os **agentes** que usarao este canal
8. Confirme a criacao

**Verificacao:** O canal aparece em Configuracoes > Canais de Entrada com status ativo. Envie uma mensagem de teste para o numero para confirmar que funciona.

## 3.4 Verificar Templates WhatsApp

Os templates sao mensagens pre-aprovadas pela Meta usadas pelo sistema de cobranca.

**No Frontdesk:**

1. Acesse **Configuracoes > Conexoes WhatsApp**
2. Selecione a conexao Meta Cloud
3. Clique na aba **Templates**
4. Clique em **Sincronizar** para buscar os templates da Meta
5. Confirme que todos aparecem com status **APPROVED** (badge verde):

| Template | Uso | Variaveis |
|---|---|---|
| `fatura_lembrete_5dias` | Lembrete D-5 | nome, valor, vencimento, PIX, codigo barras |
| `fatura_emissao` | Fatura emitida D0 | nome, valor, vencimento, PIX, codigo barras |
| `cobranca_vencimento_hoje` | Vence hoje | nome, valor, vencimento, PIX, codigo barras |
| `cobranca_atraso_5dias` | D+5 atraso | nome, valor, vencimento, PIX, codigo barras |
| `boleto_atraso_10dias` | D+10 atraso | nome, valor, vencimento, PIX, codigo barras |
| `fatura_atraso_15dias` | D+15 execucao | nome, valor, vencimento, PIX, codigo barras |
| `fatura_atraso_21dias` | D+21 transbordo | nome |
| `aviso_pagamento_ok` | Pagamento OK | valor |

**O que o cliente recebe em cada template (exceto D+21 e pagamento):**
- Saudacao com nome
- Informacao da divida (valor e vencimento)
- **Codigo PIX** (copia e cola para pagar no app do banco)
- **Codigo de barras** do boleto (linha digitavel para copiar)
- **Botao "Pagar via PIX"** - abre pagina de pagamento
- **Botao "Ver Boleto (PDF)"** - abre o boleto em PDF

## 3.5 Criar Respostas Rapidas

Atalhos para mensagens frequentes. No chat, digite `/codigo` para inserir.

**No Frontdesk:**

1. Acesse **Configuracoes > Respostas Rapidas**
2. Clique em **Adicionar** e crie:

| Codigo | Mensagem |
|---|---|
| pago | Obrigado pelo pagamento! Mantenha sempre seus beneficios em dia. |
| comprovante | Por favor, encaminhe o comprovante de pagamento para que possamos confirmar. |
| contato | Para mais informacoes: (31) 98248-8131 ou adm@atendmedbh.com.br |
| prazo | Quantos dias voce vai precisar: 3, 5 ou 7 dias? |
| cancelar | Vou te transferir para o setor de contratos. Aguarde. |
| pix | Para pagar via PIX ou acessar a segunda via do boleto, clique no link que enviamos na conversa. |

**Uso:** Na conversa, digite `/pago` e a mensagem completa e inserida automaticamente.

---

# FASE 4 - CRM

O CRM gerencia contatos, empresas e oportunidades comerciais.

## 4.1 Cadastrar a Empresa do Cliente

1. No KLaOS, menu lateral > **CRM > Empresas**
2. Clique em **+ Nova Empresa**
3. Preencha:
   - **Nome:** Mais Saude 24 Horas
   - **Setor:** Saude
   - **Email:** adm@atendmedbh.com.br
   - **Telefone:** (31) 98248-8131
4. Clique em **Salvar**

## 4.2 Configurar Pipeline de Vendas

O pipeline organiza etapas em colunas visuais (Kanban):

1. Menu lateral > **CRM > Negocios**
2. Ative a **visao Kanban** (icone de colunas)
3. Configure os estagios conforme o processo do cliente
4. Exemplo para cobranca: Inadimplente → Em Negociacao → Acordo → Pago → Juridico

## 4.3 Criar Contatos

1. Menu lateral > **CRM > Contatos**
2. Clique em **+ Novo Contato**
3. Preencha: Nome, Email, Telefone, Empresa vinculada
4. Para importacao em massa: use Exportar/Importar CSV

**Nota:** Devedores do TENEX sao sincronizados automaticamente no modulo de Cobranca. O CRM e complementar para gestao comercial.

---

# FASE 5 - COBRANCA (COLLECTIONS)

## 5.1 Conectar o TENEX (ERP)

1. No KLaOS, menu lateral > **Funil > Cobranca**
2. Se o TENEX nao estiver configurado, voce vera um alerta amarelo
3. Clique no botao **Tenex** (canto superior direito)
4. No modal, preencha:
   - **URL da API:** endereco do TENEX do cliente
   - **Chave da API:** token de autenticacao
   - **ID da Empresa:** (opcional)
5. Clique em **Salvar**
6. A sincronizacao inicia automaticamente

## 5.2 Sincronizar e Validar Devedores

1. Clique na aba **Devedores**
2. Aguarde a sincronizacao (pode levar minutos dependendo da quantidade)
3. Verifique a tabela:

| O que checar | Onde ver | Resultado esperado |
|---|---|---|
| Devedores aparecem | Tabela de devedores | Nomes, telefones, valores |
| Telefones validos | Coluna Telefone | Formato +55XX... |
| Dados de pagamento | Expandir devedor > titulos | PIX, linha digitavel, PDF preenchidos |
| Valores corretos | Coluna Divida | Condizem com o TENEX |

4. **Filtros uteis:**
   - **Busca:** Nome, CPF ou telefone
   - **Status:** Em Aberto, Negociando, Pago, Baixado, Juridico
   - **Plano:** Com ou sem contrato ativo
5. **Forcar atualizacao:** Clique em **Sincronizar**

**Importante:** Se os titulos nao tiverem PIX, linha digitavel ou PDF, os templates de cobranca enviarao esses campos vazios. Valide com o TENEX do cliente.

## 5.3 Criar Campanha de Cobranca

### Iniciar

1. Clique em **+ Nova Campanha**
2. Escolha o template **"Regua de Cobranca WABA"** (recomendado - ja vem com 6 passos)
   - Ou comece do zero com "Campanha em branco"

### Informacoes Basicas

3. Preencha:
   - **Nome:** Ex: "Cobranca Mais Saude - Abril 2026"
   - **Descricao:** Ex: "Regua completa para devedores com plano ativo"
   - **Matricula automatica:** Marque para incluir novos devedores automaticamente

### Segmentacao

4. Defina os filtros:
   - **Atraso Minimo:** 1 (somente devedores com atraso)
   - **Atraso Maximo:** 90 (ou vazio para sem limite)
   - **Valor Minimo / Maximo:** Conforme necessidade
   - **Contrato ativo:** Marque se aplicavel

### Canal e Horarios

5. Configure:
   - **Canal:** Selecione o canal WhatsApp criado (com selo WABA verde)
   - **Hora inicio:** 11
   - **Hora fim:** 20
   - **Dias:** Apenas Segunda a Sexta (desmarcar Sabado e Domingo)
   - **Equipe de Transbordo:** FILA CONTRATOS
   - **Equipe de Boletos:** FILA BOLETOS

### Cadencia (Regua de 7 Passos)

6. Configure cada passo:

---

**PASSO 1 - Lembrete Preventivo (5 dias antes do vencimento)**

| Campo | Valor |
|---|---|
| Template WABA | `fatura_lembrete_5dias` |
| Quando enviar | Relativo ao vencimento |
| Dias | -5 |
| Label | pendente |
| Handoff | Nao |

**O que o cliente recebe:** Mensagem lembrando que a fatura vence em 5 dias, com codigo PIX, codigo de barras e botoes de pagamento.

---

**PASSO 2 - Fatura Emitida (dia da matricula)**

| Campo | Valor |
|---|---|
| Template WABA | `fatura_emissao` |
| Quando enviar | D+ da matricula |
| Dias | 0 |
| Label | pendente |
| Handoff | Nao |

**O que o cliente recebe:** Notificacao de que a fatura foi emitida, com todos os dados de pagamento.

---

**PASSO 3 - Dia do Vencimento**

| Campo | Valor |
|---|---|
| Template WABA | `cobranca_vencimento_hoje` |
| Quando enviar | Relativo ao vencimento |
| Dias | 0 |
| Label | cobranca-0d |
| Handoff | Nao |

**O que o cliente recebe:** Lembrete de que a fatura vence hoje, com dados de pagamento.

---

**PASSO 4 - 5 Dias de Atraso**

| Campo | Valor |
|---|---|
| Template WABA | `cobranca_atraso_5dias` |
| Quando enviar | Relativo ao vencimento |
| Dias | 5 |
| Label | cobranca-5d |
| Handoff | Nao |

**O que o cliente recebe:** Aviso de que o boleto esta vencido, mencionando risco de protesto.

---

**PASSO 5 - 10 Dias de Atraso**

| Campo | Valor |
|---|---|
| Template WABA | `boleto_atraso_10dias` |
| Quando enviar | Relativo ao vencimento |
| Dias | 10 |
| Label | cobranca-10d |
| Handoff | Nao |

**O que o cliente recebe:** Aviso mais firme sobre o titulo em protesto.

---

**PASSO 6 - 15 Dias de Atraso**

| Campo | Valor |
|---|---|
| Template WABA | `fatura_atraso_15dias` |
| Quando enviar | Relativo ao vencimento |
| Dias | 15 |
| Label | cobranca-15d |
| Handoff | Nao |

**O que o cliente recebe:** Aviso de execucao iminente, protesto, Serasa e SPC.

---

**PASSO 7 - 21 Dias de Atraso (Transbordo)**

| Campo | Valor |
|---|---|
| Template WABA | `fatura_atraso_21dias` |
| Quando enviar | Relativo ao vencimento |
| Dias | 21 |
| Label | transbordo-humano |
| Handoff | **SIM** |

**O que o cliente recebe:** Mensagem final informando que o titulo foi encaminhado ao cartorio/SPC/Serasa, com orientacao para entrar em contato.

**O que acontece no sistema:** A conversa e transferida automaticamente para a FILA CONTRATOS. O bot para de responder. Um atendente humano assume.

---

### Revisao e Criacao

7. Revise todas as configuracoes
8. Clique em **Criar Campanha** (salva como Rascunho)

## 5.4 Matricular Devedores

### Teste Interno (Recomendado)

Antes de ativar para devedores reais, teste com a equipe:

1. Abra a campanha criada
2. Aba **Adicionar Devedores**
3. Busque pelos nomes dos membros da equipe (que foram cadastrados como devedores de teste)
4. Selecione e clique em **Matricular**
5. Ative a campanha e verifique se as mensagens chegam corretamente

### Matricula Real

1. Na aba **Adicionar Devedores**, use os filtros para encontrar os devedores
2. Selecione os devedores desejados (checkbox)
3. Clique em **Matricular X devedor(es)**
4. Os devedores aparecem na aba **Matriculados**

## 5.5 Ativar e Monitorar

### Ativacao

1. Clique no botao verde **Ativar**
2. Revise o preview
3. Confirme

### Monitoramento

Acompanhe na pagina da campanha:

**Cards superiores:**
- Matriculados | Enviados | Respostas | Pagamentos

**Aba Matriculados - colunas:**

| Coluna | O que mostra |
|---|---|
| Devedor | Nome e telefone |
| Divida | Valor na matricula |
| Passo Atual | "3 / 7" (passo atual de total) |
| Status | Ativo, Pausado, Pago, Handoff, Removido |
| Entrega | Enviado, Entregue, Lido, Falha (icones) |
| Proximo Disparo | Data/hora da proxima mensagem |

**Clique em um devedor** para ver o timeline completo:
- Matriculado em [data]
- Mensagem enviada: [template] em [data]
- Entregue em [data]
- Lida em [data]
- Resposta recebida: "[texto]"
- Pagamento detectado em [data]
- Transferido para humano em [data]

### Condicoes de Parada Automatica

| Evento | O que acontece |
|---|---|
| Pagamento detectado no TENEX | Fluxo encerra, label "pagamento-realizado" |
| Cliente diz "ja paguei" | Pausa 24h, verifica no TENEX |
| Atinge D+21 | Transfere para FILA CONTRATOS, bot para |
| Cliente pede cancelamento | Transfere para equipe humana |

---

# FASE 6 - AI AGENT

## 6.1 Criar Agente de IA

1. No KLaOS, menu lateral > **Atendimento > Agents**
2. Clique em **Criar Agente**
3. Siga o assistente:

**Etapa 1 - Template:** Escolha um template base ou comece em branco

**Etapa 2 - Identidade:**
- **Nome:** Agente Cobranca [Nome do Cliente]
- **Descricao:** Agente de cobranca automatica
- **Avatar:** Logo da empresa (opcional)

**Etapa 3 - Comportamento:**
- No campo **System Prompt**, insira as instrucoes:

```
Voce e um agente de cobranca educado e profissional.

REGRAS:
- Nunca ameace o cliente
- Nunca prometa desconto sem autorizacao
- Se o cliente disse que ja pagou: agradeca e informe que sera verificado
- Se o cliente pedir cancelamento e estiver inadimplente: informe que precisa pagar primeiro
- Se o cliente mencionar PROCON, advogado ou justica: transfira para humano imediatamente
- Se o cliente pedir prazo: ofereca opcoes de 3, 5 ou 7 dias
- Se o cliente pedir segunda via ou PIX: oriente a clicar no link enviado na conversa
- Se o cliente pedir para falar com humano: transfira educadamente

INFORMACOES DE CONTATO:
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

- **Modelo:** Mantenha o padrao
- **Temperatura:** 0.7

**Etapa 4 - Conhecimento:** Selecione documentos relevantes (politicas de cobranca, FAQ)

**Etapa 5 - Revisao:** Confira e clique em **Criar Agente**

## 6.2 Conectar ao Frontdesk (AI Bridge)

1. No KLaOS, acesse **Atendimento > Frontdesk**
2. Clique na aba **AI Bridge**
3. Clique em **Conectar Agente**
4. No modal:
   - **Selecionar agente:** Escolha o agente de cobranca criado
   - **Selecionar inbox:** Escolha o canal WhatsApp (KLaOS Cobranca)
5. Clique em **Conectar Agente**

**Resultado:** O agente agora responde automaticamente as mensagens recebidas neste canal.

## 6.3 Testar o Agente

Envie mensagens de teste para o numero WhatsApp e valide:

| Teste | Mensagem | Resposta Esperada |
|---|---|---|
| Pagamento | "ja paguei" | Agradece e informa que sera verificado |
| Cancelamento | "quero cancelar" | Verifica inadimplencia ou transfere |
| Segunda via | "me manda a segunda via" | Orienta a usar o link enviado |
| Ameaca legal | "vou chamar meu advogado" | Transfere para humano |
| Prazo | "preciso de mais prazo" | Oferece opcoes de 3, 5 ou 7 dias |
| Generico | "obrigado" | Responde educadamente |

---

# FASE 7 - OPERACAO DIARIA

## 7.1 Rotina do Atendente

**Inicio do dia:**

1. Login no KLaOS > Abrir Frontdesk (SSO)
2. Verificar **Caixa de Entrada** - conversas nao atribuidas
3. Filtrar por label **transbordo-humano** - conversas que precisam de atencao
4. Filtrar por equipe (FILA CONTRATOS / FILA BOLETOS)

**Atendendo uma conversa:**

1. Clique na conversa na lista
2. Leia o historico (mensagens do bot + respostas do cliente)
3. No painel direito, verifique: labels, equipe, contato
4. Responda:
   - Digite a mensagem ou use `/codigo` (resposta rapida)
   - Para enviar template: clique no icone Template > busque > preencha > envie
5. Gerencie:
   - **Atribuir** a agente ou equipe (painel direito)
   - **Adicionar label** manualmente se necessario
   - **Resolver** quando finalizado
   - **Adiar** para revisar depois

**Acoes em lote:**
- Selecione varias conversas (checkbox) para atribuir, rotular ou resolver

## 7.2 Rotina do Gestor

**Monitoramento diario:**

1. No KLaOS > **Funil > Cobranca** > Abrir campanha
2. Verificar:
   - Novas respostas
   - Pagamentos detectados
   - Falhas de entrega
   - Devedores no passo de transbordo

3. No Frontdesk > **Relatorios:**

| Relatorio | O que mostra |
|---|---|
| Visao Geral | Volume de conversas, tempo de resposta |
| Agentes | Performance individual |
| Labels | Conversas por estagio (cobranca-5d, etc.) |
| Equipes | Performance das filas |
| CSAT | Satisfacao do cliente |

**Acoes de gestao:**
- Pausar/retomar campanhas conforme necessidade
- Adicionar ou remover devedores
- Ajustar horarios de envio
- Revisar e ajustar instrucoes do AI Agent

---

# CHECKLIST FINAL DE IMPLEMENTACAO

## Fase 1 - Acesso
- [ ] Login no KLaOS OK
- [ ] Engine Frontdesk ativada
- [ ] Engine CRM ativada
- [ ] Engine Collections ativada
- [ ] Engine AI Agents ativada

## Fase 2 - Usuarios
- [ ] Membros convidados no KLaOS
- [ ] Membros provisionados no Frontdesk
- [ ] Funcoes atribuidas corretamente
- [ ] SSO funcionando para todos

## Fase 3 - Frontdesk
- [ ] Equipe FILA CONTRATOS criada com membros
- [ ] Equipe FILA BOLETOS criada com membros
- [ ] 10 labels criadas com cores corretas
- [ ] Canal WhatsApp criado e ativo
- [ ] 8 templates sincronizados e APPROVED
- [ ] Respostas rapidas criadas

## Fase 4 - CRM
- [ ] Empresa do cliente cadastrada
- [ ] Pipeline configurado

## Fase 5 - Cobranca
- [ ] TENEX conectado
- [ ] Devedores sincronizados e validados
- [ ] Campanha criada com 7 passos
- [ ] Horario: 11h-20h, seg-sex
- [ ] Teste interno realizado
- [ ] Campanha ativada com devedores reais

## Fase 6 - AI Agent
- [ ] Agente criado com instrucoes
- [ ] Conectado ao canal WhatsApp (AI Bridge)
- [ ] Testes de resposta validados

## Fase 7 - Operacao
- [ ] Equipe treinada no Frontdesk
- [ ] Rotina diaria definida
- [ ] Responsaveis por fila definidos
- [ ] Primeiro ciclo de monitoramento realizado

---

**Documento criado por:** KLaOS Team
**Versao:** 2.0
**Data:** Abril 2026
