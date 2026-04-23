# TREINAMENTO COMPLETO - Plataforma KLaOS + Frontdesk
## Guia Passo a Passo para Onboarding de Clientes
### Versao 1.0 - Abril 2026

---

# INDICE

1. [Introducao a Plataforma](#1-introducao-a-plataforma)
2. [Acesso e Login](#2-acesso-e-login)
3. [KLaOS - Visao Geral e Navegacao](#3-klaos---visao-geral-e-navegacao)
4. [Frontdesk - Visao Geral e Navegacao](#4-frontdesk---visao-geral-e-navegacao)
5. [Configuracao Inicial do Frontdesk](#5-configuracao-inicial-do-frontdesk)
6. [Modulo CRM do KLaOS](#6-modulo-crm-do-klaos)
7. [Modulo de Cobranca (Collections)](#7-modulo-de-cobranca-collections)
8. [Integracao KLaOS + Frontdesk](#8-integracao-klaos--frontdesk)
9. [AI Agents - Agentes de IA](#9-ai-agents---agentes-de-ia)
10. [Operacao Diaria no Frontdesk](#10-operacao-diaria-no-frontdesk)
11. [Relatorios e Metricas](#11-relatorios-e-metricas)
12. [Troubleshooting e FAQ](#12-troubleshooting-e-faq)

---

# 1. INTRODUCAO A PLATAFORMA

## O que e o KLaOS?

KLaOS e uma plataforma de inteligencia artificial para gestao de negocios que integra:

- **CRM** - Gestao de contatos, empresas e negocios
- **Cobranca Automatica (Collections)** - Recuperacao de credito via WhatsApp com IA
- **Frontdesk** - Plataforma de atendimento omnicanal (WhatsApp, Email, Chat)
- **AI Agents** - Agentes de IA para atendimento automatico
- **LinkedIn Prospecting** - Prospeccao automatizada no LinkedIn
- **Business Intelligence** - Dashboards e analises
- **Knowledge Base** - Base de conhecimento para IA

## Arquitetura Geral

```
KLaOS (Orquestrador)
  |
  |-- CRM (Contatos, Empresas, Negocios)
  |-- Collections (Cobranca Automatica)
  |     |-- Campanhas de cobranca
  |     |-- Regua de mensagens automaticas
  |     |-- Deteccao de pagamento
  |     |-- Transbordo para humano
  |     |
  |     |-- Envia mensagens via -->  FRONTDESK
  |
  |-- Frontdesk (Atendimento)
  |     |-- Conversas WhatsApp / Email / Chat
  |     |-- Equipes e Agentes
  |     |-- Labels e organizacao
  |     |-- Templates WhatsApp
  |
  |-- AI Agents (IA para atendimento)
  |     |-- Respostas automaticas
  |     |-- Handoff para humano
  |
  |-- Integracao TENEX (ERP)
        |-- Sync de devedores
        |-- Dados de boletos e PIX
        |-- Confirmacao de pagamentos
```

---

# 2. ACESSO E LOGIN

## 2.1 Acessando o KLaOS

1. Abra o navegador e acesse a URL do KLaOS fornecida pelo administrador
2. Na tela de login, insira seu **email** e **senha**
3. Clique em **Entrar**
4. Voce sera redirecionado para o Dashboard principal

## 2.2 Acessando o Frontdesk

O Frontdesk e acessado de duas formas:

### Opcao A: Via KLaOS (SSO - Recomendado)
1. No KLaOS, acesse o menu lateral **Atendimento > Frontdesk**
2. Clique no botao **Abrir Frontdesk**
3. Voce sera autenticado automaticamente via SSO (Single Sign-On)
4. O Frontdesk abrira em nova aba ja logado

### Opcao B: Acesso Direto
1. Acesse a URL do Frontdesk fornecida pelo administrador
2. Insira email e senha
3. Se habilitado, complete a verificacao em duas etapas (MFA)

## 2.3 Primeiro Acesso

No primeiro acesso, voce encontrara:
- **KLaOS**: Dashboard com cards de status dos modulos
- **Frontdesk**: Painel de conversas vazio (aguardando configuracao de canais)

---

# 3. KLAOS - VISAO GERAL E NAVEGACAO

## 3.1 Menu Lateral (Sidebar)

O menu lateral do KLaOS e dividido nas seguintes secoes:

| Icone | Menu | Descricao |
|---|---|---|
| Casa | **Home** | Dashboard principal com status dos modulos |
| Chat | **Copilot / Klaus Chat** | Assistente de IA para perguntas |
| Cerebro | **Inteligencia** | Knowledge Base e Business Intelligence |
| Pessoas | **CRM** | Contatos, Empresas, Negocios, Tarefas |
| Funil | **Funil** | LinkedIn Prospecting e Cobranca |
| Headset | **Atendimento** | Frontdesk e AI Agents |
| Engrenagem | **Engines** | Configuracoes avancadas de IA |
| Config | **Settings** | Configuracoes do workspace |

## 3.2 Dashboard (Home)

Ao acessar o KLaOS, o Dashboard mostra:

- **Engines Ativos** - Quantos motores de IA estao habilitados
- **Documentos** - Total de documentos na base de conhecimento
- **Sessoes com Klaus** - Total de conversas com o assistente IA

**Acoes Rapidas:**
- **Falar com Klaus** - Abre o chat com IA
- **Adicionar Conhecimento** - Upload de documentos
- **Explorar Engines** - Configurar motores de IA

---

# 4. FRONTDESK - VISAO GERAL E NAVEGACAO

## 4.1 Interface Principal

O Frontdesk e dividido em:

- **Sidebar esquerda** - Navegacao principal
- **Painel central** - Lista de conversas
- **Painel direito** - Detalhes da conversa selecionada

## 4.2 Menu Lateral do Frontdesk

| Secao | Funcionalidade |
|---|---|
| **Caixa de Entrada** | Conversas nao atribuidas e novas |
| **Conversas** | Todas as conversas, mencionadas, nao atendidas |
| **Pastas** | Filtros personalizados salvos |
| **Equipes** | Conversas por equipe |
| **Canais** | Conversas por canal (WhatsApp, Email, etc.) |
| **Labels** | Conversas por etiqueta/tag |
| **Captain** | Modulo de IA do Frontdesk |
| **Contatos** | Gestao de contatos |
| **Empresas** | Gestao de empresas |
| **Relatorios** | Analytics e metricas |
| **Campanhas** | Campanhas de mensagens |
| **Configuracoes** | Configuracao do sistema |

---

# 5. CONFIGURACAO INICIAL DO FRONTDESK

## 5.1 Criando Equipes

As equipes organizam os agentes por funcao. Para o fluxo de cobranca, crie:

### Passo a Passo:

1. Acesse **Configuracoes > Equipes**
2. Clique em **Criar Equipe**
3. Preencha:
   - **Nome**: Ex: "FILA CONTRATOS"
   - **Descricao**: Ex: "Equipe para cancelamentos e escalacoes"
4. Clique em **Criar**
5. Adicione os membros da equipe
6. Repita para criar **"FILA BOLETOS"**

**Equipes recomendadas para cobranca:**

| Equipe | Funcao | Responsavel |
|---|---|---|
| FILA CONTRATOS | Cancelamentos, escalacoes D+21, ameacas legais | Gustavo |
| FILA BOLETOS | Emissao de boletos para substituir cartao | Marta |

## 5.2 Criando Labels (Etiquetas)

Labels sao etiquetas coloridas aplicadas as conversas para organizacao e rastreamento.

### Passo a Passo:

1. Acesse **Configuracoes > Labels**
2. Clique em **Adicionar Label**
3. Para cada label, preencha:
   - **Nome da Label**
   - **Descricao** (opcional)
   - **Cor**
4. Clique em **Criar**

**Labels recomendadas para cobranca:**

| Label | Cor | Quando Usar |
|---|---|---|
| `pendente` | Verde | Boleto emitido, inicio do fluxo |
| `cobranca-0d` | Amarelo | Dia do vencimento |
| `cobranca-5d` | Rosa/Vermelho | D+5 apos vencimento |
| `cobranca-10d` | Roxo | D+10 apos vencimento |
| `cobranca-15d` | Laranja | D+15 apos vencimento |
| `transbordo-humano` | Azul | D+21 ou transferencia para humano |
| `pagamento-realizado` | Verde escuro | Pagamento confirmado |
| `cobranca-promessa` | Cinza | Cliente prometeu pagar em data X |
| `cobranca-negociacao` | Cinza | Cliente negociando prazo |
| `cancelamento-pendente` | Vermelho | Cliente quer cancelar (inadimplente) |

## 5.3 Configurando Canais (Inboxes)

### Criando um Canal WhatsApp

1. Acesse **Configuracoes > Canais de Entrada** (Inboxes)
2. Clique em **Adicionar Canal**
3. Selecione **WhatsApp**
4. Escolha o provedor:
   - **WhatsApp Business API (Meta Cloud)** - Recomendado para producao
   - **Evolution** - Para conexoes nao oficiais
5. Preencha as credenciais fornecidas pelo administrador
6. Nomeie o canal (Ex: "KLaOS Cobranca")
7. Atribua agentes ao canal
8. Clique em **Criar Canal**

### Verificando Conexao WhatsApp

Apos criar o canal:
1. Acesse **Configuracoes > Conexoes WhatsApp**
2. Verifique se a conexao aparece como **Ativa**
3. Confira o numero de telefone conectado
4. Teste enviando uma mensagem para o numero

## 5.4 Configurando Agentes

1. Acesse **Configuracoes > Agentes**
2. Clique em **Adicionar Agente**
3. Preencha:
   - **Email** do colaborador
   - **Funcao**: Administrador ou Agente
4. O colaborador recebera um convite por email
5. Atribua o agente aos canais e equipes corretos

## 5.5 Criando Respostas Rapidas (Canned Responses)

Respostas pre-escritas para agilizar o atendimento:

1. Acesse **Configuracoes > Respostas Rapidas**
2. Clique em **Adicionar Resposta**
3. Preencha:
   - **Codigo**: Ex: "pago" (usado com / no chat)
   - **Conteudo**: "Obrigado pelo pagamento! Mantenha sempre seus beneficios em dia."
4. No chat, digite `/pago` para inserir a resposta rapidamente

---

# 6. MODULO CRM DO KLAOS

## 6.1 Visao Geral

O CRM do KLaOS permite gerenciar:
- **Contatos** - Pessoas fisicas
- **Empresas** - Organizacoes
- **Negocios** - Pipeline de vendas (Kanban)
- **Tarefas** - Acompanhamento de atividades

## 6.2 Contatos

### Acessando:
1. Menu lateral > **CRM > Contatos**

### Funcionalidades:
- **Buscar** contatos por nome, email, telefone
- **Criar** novo contato com informacoes completas
- **Editar** dados do contato
- **Exportar** lista em CSV
- **Tags** para organizacao

### Informacoes do Contato:
- Nome, Email, Telefone
- Cargo e Empresa vinculada
- Estagio no ciclo de vida (Lead, Cliente, etc.)
- Lead Score
- Campos personalizados

## 6.3 Empresas

### Acessando:
1. Menu lateral > **CRM > Empresas**

### Funcionalidades:
- Cadastro de empresas
- Vinculacao de contatos a empresas
- Historico de negocios por empresa

## 6.4 Negocios (Pipeline Kanban)

### Acessando:
1. Menu lateral > **CRM > Negocios**

### Visao Kanban:
- Colunas representam estagios do pipeline (Ex: Prospeccao, Qualificacao, Proposta, Negociacao, Ganho, Perdido)
- Cards representam negocios individuais
- **Arrastar e soltar** cards entre colunas para atualizar estagio

### Criando um Negocio:
1. Clique em **+ Criar Negociacao**
2. Preencha: Nome, Empresa, Contato, Valor, Estagio
3. Atribua a um responsavel
4. Adicione tags

### Filtros:
- Por responsavel
- Por estagio
- Por origem
- Busca por nome

## 6.5 Tarefas

### Acessando:
1. Menu lateral > **CRM > Tarefas**

### Funcionalidades:
- Criar tarefas vinculadas a negocios/contatos/empresas
- Definir prazos e prioridades
- Atribuir a membros da equipe
- Status: A Fazer, Em Progresso, Concluido

---

# 7. MODULO DE COBRANCA (COLLECTIONS)

## 7.1 Visao Geral

O modulo de Cobranca automatiza o processo de recuperacao de credito enviando mensagens WhatsApp em sequencia (regua de cobranca), com:

- **Integracao TENEX** para sincronizar devedores
- **Templates WhatsApp aprovados pela Meta** com dados de pagamento
- **AI Agent** para respostas automaticas
- **Transbordo** automatico para humano quando necessario
- **Deteccao de pagamento** para encerrar o fluxo

## 7.2 Configurando o TENEX (ERP)

### Passo a Passo:

1. Acesse **Funil > Cobranca**
2. Clique no botao **Tenex** (canto superior direito)
3. Preencha:
   - **URL da API**: Endereco do servidor TENEX
   - **Chave da API**: Token de autenticacao
   - **ID da Empresa** (opcional)
4. Clique em **Salvar**
5. O sistema iniciara a sincronizacao automatica

### O que e Sincronizado:

| Dado | Descricao |
|---|---|
| **Devedores** | Nome, CPF/CNPJ, telefone, email |
| **Dividas** | Valor total, dias de atraso, status |
| **Titulos** | Numero, valor, vencimento, multa, juros |
| **Dados de Pagamento** | Codigo PIX, linha digitavel (codigo de barras), URL do boleto PDF |

## 7.3 Visualizando Devedores

### Acessando:
1. **Funil > Cobranca > Aba "Devedores"**

### Informacoes na Tabela:

| Coluna | Descricao |
|---|---|
| **Nome** | Nome do devedor e CPF/CNPJ |
| **Telefone** | Numero de contato |
| **Divida** | Valor total em aberto (vermelho) |
| **Atraso** | Dias de atraso |
| **Status** | Em Aberto / Negociando / Pago / Baixado / Juridico |
| **Parcelas** | Quantidade de titulos |

### Detalhes do Devedor:
Clique na linha do devedor para expandir e ver:
- Lista de titulos individuais
- Valor original vs valor atualizado
- Juros e multa
- Data de vencimento de cada titulo
- Status de cada titulo

### Filtros Disponiveis:
- **Busca** por nome, CPF/CNPJ ou telefone
- **Status** (Em Aberto, Negociando, Pago, etc.)
- **Plano** (com ou sem contrato ativo)
- **Botao Sincronizar** para forcar atualizacao do TENEX

## 7.4 Criando uma Campanha de Cobranca

### Passo a Passo Detalhado:

#### Etapa 1: Iniciar Criacao
1. Acesse **Funil > Cobranca > Aba "Campanhas"**
2. Clique em **Nova Campanha**
3. Escolha um template pre-configurado ou comece do zero

#### Etapa 2: Informacoes da Campanha
1. **Nome da Campanha** (obrigatorio): Ex: "Cobranca Mais Saude - Abril 2026"
2. **Descricao** (opcional): Objetivo e detalhes da campanha
3. **Auto-matricula**: Marque se quiser que novos devedores sejam incluidos automaticamente

#### Etapa 3: Segmentacao (Filtros de Devedores)
Defina quais devedores serao elegíveis:

| Campo | Descricao | Exemplo |
|---|---|---|
| **Atraso Minimo** | Minimo de dias de atraso | 1 dia |
| **Atraso Maximo** | Maximo de dias de atraso | 90 dias |
| **Valor Minimo** | Divida minima em R$ | R$ 29,90 |
| **Valor Maximo** | Divida maxima em R$ | R$ 500,00 |
| **Contrato Ativo** | Apenas devedores com contrato | Sim/Nao |

#### Etapa 4: Canal e Horarios
1. **Selecione o Canal**: Escolha o canal WhatsApp do Frontdesk
   - Canais WABA mostram selo verde "WABA"
   - Canais nao oficiais mostram icone de celular
2. **Horario de Envio**:
   - Hora inicio: **11** (recomendado)
   - Hora fim: **20**
3. **Dias da Semana**: Marque apenas **Segunda a Sexta**
4. **Equipe de Transbordo**: Selecione "FILA CONTRATOS"
5. **Equipe de Boletos**: Selecione "FILA BOLETOS"

#### Etapa 5: Cadencia (Regua de Mensagens)

Configure a sequencia de mensagens que serao enviadas:

**Para cada passo da cadencia, configure:**

| Campo | Descricao |
|---|---|
| **Template WABA** | Selecione o template aprovado pela Meta |
| **Quando Enviar** | "Relativo ao vencimento" ou "D+ da matricula" |
| **Dias** | Offset em dias (0 = mesmo dia, 5 = 5 dias apos) |
| **Label** | Etiqueta aplicada no Frontdesk |
| **Handoff** | Marque se este passo transfere para humano |

**Regua padrao recomendada (7 passos):**

| Passo | Quando | Template | Label | Handoff |
|---|---|---|---|---|
| 1 | D-5 (5 dias antes) | `fatura_lembrete_5dias` | pendente | Nao |
| 2 | D0 (matricula) | `fatura_emissao` | pendente | Nao |
| 3 | D0 (vencimento) | `cobranca_vencimento_hoje` | cobranca-0d | Nao |
| 4 | D+5 | `cobranca_atraso_5dias` | cobranca-5d | Nao |
| 5 | D+10 | `boleto_atraso_10dias` | cobranca-10d | Nao |
| 6 | D+15 | `fatura_atraso_15dias` | cobranca-15d | Nao |
| 7 | D+21 | `fatura_atraso_21dias` | transbordo-humano | **Sim** |

**Para adicionar um passo:**
1. Clique em **+ Adicionar Passo**
2. Selecione o template WABA
3. Configure o gatilho (tipo e dias)
4. Selecione a label
5. Marque handoff se necessario

#### Etapa 6: Revisao
1. Revise todas as configuracoes
2. Clique em **Criar Campanha** (salva como rascunho)

## 7.5 Matriculando Devedores

### Matricula Manual:
1. Abra a campanha criada
2. Acesse a aba **Adicionar Devedores**
3. Busque e selecione os devedores desejados (checkbox)
4. Clique em **Matricular X devedor(es)**
5. Os devedores aparecerao na aba **Matriculados**

### Matricula Automatica:
- Se marcou "Auto-matricula" na criacao, novos devedores que atendam aos filtros serao incluidos automaticamente na proxima sincronizacao do TENEX

## 7.6 Ativando a Campanha

1. Na pagina da campanha, clique em **Ativar**
2. Revise o preview com os primeiros passos
3. Confirme a ativacao
4. Status muda para **Ativa**
5. As mensagens comecam a ser enviadas conforme o agendamento

## 7.7 Monitorando a Campanha

### Cards de Estatisticas (topo):

| Metrica | Descricao |
|---|---|
| **Matriculados** | Total de devedores na campanha |
| **Enviados** | Total de mensagens enviadas |
| **Respostas** | Respostas recebidas |
| **Pagamentos** | Pagamentos detectados |

### Aba "Matriculados":

Tabela com todos os devedores matriculados:

| Coluna | Descricao |
|---|---|
| **Devedor** | Nome e telefone |
| **Divida** | Valor na matricula |
| **Passo Atual** | Ex: "3 / 7" (passo 3 de 7) |
| **Status** | Ativo / Pausado / Pago / Handoff / Removido |
| **Entrega** | Status da ultima mensagem (Enviado, Entregue, Lido, Falha) |
| **Proximo Disparo** | Data/hora da proxima mensagem |

### Historico de um Devedor:

Clique na linha do devedor para ver o timeline completo:
- Matriculado - Data de entrada
- Mensagem enviada - Qual template, quando
- Entregue - Confirmacao de entrega
- Lida - Confirmacao de leitura
- Resposta recebida - O que o cliente respondeu
- Pagamento detectado - Se pagou
- Transferido para humano - Se foi escalado

## 7.8 Templates WhatsApp (WABA)

### O que sao Templates WABA?

Templates sao mensagens pre-aprovadas pela Meta que podem ser enviadas fora da janela de 24 horas do WhatsApp. Cada template tem:

- **Corpo (Body)**: Texto da mensagem com variaveis
- **Variaveis**: Dados dinamicos (nome, valor, vencimento, PIX, codigo de barras)
- **Botoes**: Botoes clicaveis (links para pagamento)
- **Categoria**: UTILITY (transacional) ou MARKETING (promocional)

### Templates de Cobranca Disponiveis:

| Template | Momento | Variaveis |
|---|---|---|
| `fatura_lembrete_5dias` | D-5 | nome, valor, vencimento, PIX, codigo barras |
| `fatura_emissao` | D0 | nome, valor, vencimento, PIX, codigo barras |
| `cobranca_vencimento_hoje` | Dia V | nome, valor, vencimento, PIX, codigo barras |
| `cobranca_atraso_5dias` | D+5 | nome, valor, vencimento, PIX, codigo barras |
| `boleto_atraso_10dias` | D+10 | nome, valor, vencimento, PIX, codigo barras |
| `fatura_atraso_15dias` | D+15 | nome, valor, vencimento, PIX, codigo barras |
| `fatura_atraso_21dias` | D+21 | nome (transbordo humano) |
| `aviso_pagamento_ok` | Pagamento | valor |

### O que o Cliente Recebe:

Cada mensagem de cobranca inclui:
1. **Saudacao personalizada** com nome do cliente
2. **Informacoes da divida** (valor e vencimento)
3. **Codigo PIX** (copia e cola para pagar no app do banco)
4. **Codigo de barras do boleto** (linha digitavel para copiar)
5. **Botao "Pagar via PIX"** - Abre pagina de pagamento
6. **Botao "Ver Boleto (PDF)"** - Abre o boleto em PDF

### Pagina de Pagamento:

Quando o cliente clica no botao "Pagar via PIX", ele acessa uma pagina com:
- Nome da empresa e CNPJ
- Nome do devedor
- Valor e vencimento
- **QR Code PIX** para escanear
- **Codigo PIX** para copiar e colar
- **Codigo de barras** do boleto para copiar
- **Link para o PDF** do boleto

## 7.9 Condicoes de Parada

A campanha para automaticamente quando:

| Condicao | Acao |
|---|---|
| **Pagamento detectado no TENEX** | Encerra o fluxo, aplica label `pagamento-realizado` |
| **D+21 atingido** | Envia ultima mensagem, transfere para equipe humana |
| **Cliente responde "ja paguei"** | Pausa 24h, verifica no TENEX |
| **Cliente pede cancelamento** | Transfere para FILA CONTRATOS |

## 7.10 Pausando e Gerenciando Campanhas

- **Pausar**: Clique em "Pausar" na pagina da campanha. Nenhuma mensagem sera enviada.
- **Retomar**: Clique em "Ativar" para retomar de onde parou.
- **Remover Devedor**: Na aba Matriculados, clique no botao de remover ao lado do devedor.
- **Excluir Campanha**: Botao "Excluir" (vermelho) na pagina da campanha.

---

# 8. INTEGRACAO KLAOS + FRONTDESK

## 8.1 Como Funciona

O KLaOS e o Frontdesk trabalham juntos:

```
KLaOS (Cerebro)                    Frontdesk (Motor de Atendimento)
  |                                    |
  |-- Cria campanhas                   |-- Recebe mensagens WhatsApp
  |-- Define regua de cobranca         |-- Armazena conversas
  |-- Agenda disparos                  |-- Gerencia labels/equipes
  |-- Detecta pagamentos              |-- Permite resposta humana
  |-- Gerencia AI Agents               |-- Envia templates WhatsApp
  |                                    |
  |-- Envia mensagem via API -------->|-- Registra na conversa
  |-- Aplica labels via API --------->|-- Mostra no painel
  |-- Transfere via API ------------->|-- Notifica equipe
  |<-- Recebe webhook de resposta ----|-- Cliente respondeu
```

## 8.2 O que Aparece no Frontdesk

Quando o KLaOS envia uma mensagem de cobranca:

1. **Uma conversa e criada** no Frontdesk com o contato do devedor
2. **A mensagem aparece** no historico da conversa
3. **Labels sao aplicadas** conforme o passo da regua (pendente, cobranca-5d, etc.)
4. **Se o cliente responder**, a resposta aparece na conversa
5. **O AI Agent** pode responder automaticamente
6. **Se houver transbordo**, a conversa e atribuida a equipe humana

## 8.3 Fluxo Visual no Frontdesk

### Conversa de Cobranca Tipica:

```
[Bot] Template: fatura_emissao
  "Ola Maria! Sua fatura da MAIS SAUDE 24 HORAS foi emitida..."
  [Pagar via PIX] [Ver Boleto (PDF)]

  --- 5 dias depois ---

[Bot] Template: cobranca_vencimento_hoje
  "Ola Maria! Queremos te lembrar que a cobranca..."
  [Pagar via PIX] [Ver Boleto (PDF)]

  [Cliente] "ja paguei"

[Bot] "Obrigado! Recebemos a confirmacao. Aguarde ate o proximo
       dia util para a compensacao..."

  --- 24h de pausa ---
  --- Pagamento confirmado no TENEX ---

[Sistema] Conversa encerrada. Label: pagamento-realizado
```

## 8.4 Sincronizacao de Templates

Os templates WhatsApp sao sincronizados automaticamente:

1. Templates sao criados/editados na **Meta Business**
2. O **Frontdesk sincroniza** os templates a cada 3 horas
3. O **KLaOS le os templates** do Frontdesk
4. Os templates ficam disponiveis para **selecao nas campanhas**

Para forcar sincronizacao:
1. No Frontdesk, acesse **Configuracoes > Conexoes WhatsApp**
2. Selecione a conexao
3. Na aba **Templates**, clique em **Sincronizar**

---

# 9. AI AGENTS - AGENTES DE IA

## 9.1 O que sao AI Agents?

AI Agents sao assistentes de IA que respondem automaticamente as mensagens dos clientes no Frontdesk. No contexto de cobranca, o AI Agent:

- **Detecta intencoes** do cliente (pagou, quer cancelar, quer negociar)
- **Responde automaticamente** com mensagens adequadas
- **Pausa o fluxo** quando necessario (ex: cliente diz que ja pagou)
- **Transfere para humano** quando necessario (ex: ameaca legal)

## 9.2 Configurando AI Agent para Cobranca

### No KLaOS:
1. Acesse **Atendimento > Agents**
2. Crie ou selecione um agente
3. Configure o **system prompt** com instrucoes de cobranca
4. Vincule o agente ao canal WhatsApp do Frontdesk

### Vinculando ao Frontdesk:
1. Acesse **Atendimento > Frontdesk > Aba "AI Bridge"**
2. Clique em **Conectar Agent**
3. Selecione o agente de cobranca
4. Selecione o canal WhatsApp
5. O agente comeca a responder automaticamente

## 9.3 Comportamento do AI Agent na Cobranca

| Cenario | Acao do Agente |
|---|---|
| Cliente diz "ja paguei" | Responde agradecendo, pausa 24h, verifica TENEX |
| Cliente diz "vou pagar mais tarde" | Responde com orientacao, continua fluxo |
| Cliente quer cancelar (inadimplente) | Informa que precisa pagar antes |
| Cliente quer cancelar (adimplente) | Transfere para FILA CONTRATOS |
| Cliente pede segunda via | Orienta a usar o link enviado |
| Cliente ameaca PROCON/advogado | Transfere para FILA CONTRATOS |
| Cliente pede prazo | Oferece opcoes (3, 5 ou 7 dias) |

## 9.4 Modos de Resposta

A campanha pode ser configurada com diferentes modos:

| Modo | Descricao |
|---|---|
| **AI Agent** | Bot responde automaticamente, usa token do agente |
| **Equipe Humana** | Mensagens enviadas como admin, humanos respondem |
| **Nenhum** | Ninguem responde automaticamente |

---

# 10. OPERACAO DIARIA NO FRONTDESK

## 10.1 Visualizando Conversas

### Filtrar por Status:
- **Abertas**: Conversas ativas aguardando atencao
- **Pendentes**: Aguardando resposta do cliente
- **Resolvidas**: Conversas finalizadas
- **Adiadas (Snooze)**: Temporariamente ocultas

### Filtrar por Label:
Clique na label desejada no menu lateral:
- `cobranca-5d` - Ver todos os devedores com 5 dias de atraso
- `transbordo-humano` - Ver conversas que precisam de atencao humana
- `pagamento-realizado` - Ver pagamentos confirmados

### Filtrar por Equipe:
- Clique na equipe no menu lateral para ver apenas conversas atribuidas a ela

## 10.2 Respondendo a uma Conversa

1. Clique na conversa na lista
2. Leia o historico de mensagens
3. Na area de resposta (parte inferior):
   - **Digite** sua mensagem
   - **Ou** use `/codigo` para inserir resposta rapida
   - **Ou** clique no icone de Template para enviar template WhatsApp
4. Clique em **Enviar** (ou Ctrl+Enter)

### Enviando Template WhatsApp Manualmente:

1. Na area de resposta, clique no icone **Templates WhatsApp**
2. Busque o template desejado por nome
3. Selecione o template
4. Preencha as variaveis (nome, valor, etc.)
5. Visualize a mensagem formatada
6. Clique em **Enviar**

## 10.3 Gerenciando Conversas

### Atribuir a Agente:
1. No painel lateral direito da conversa
2. Clique em **Agente Atribuido**
3. Selecione o agente da lista

### Atribuir a Equipe:
1. No painel lateral direito
2. Clique em **Equipe Atribuida**
3. Selecione a equipe (FILA CONTRATOS, FILA BOLETOS, etc.)

### Adicionar Label:
1. No painel lateral direito
2. Na secao **Labels**
3. Clique para adicionar
4. Selecione ou busque a label

### Alterar Status:
- **Resolver**: Marcar conversa como resolvida
- **Adiar (Snooze)**: Ocultar temporariamente (reaberta quando cliente responder)
- **Reabrir**: Reabrir conversa resolvida

### Prioridade:
- Defina prioridade: Urgente, Alta, Media, Baixa
- Conversas urgentes aparecem destacadas

## 10.4 Informacoes do Contato

No painel lateral direito de cada conversa:
- **Nome e avatar** do contato
- **Telefone e email**
- **Historico** de conversas anteriores
- **Atributos personalizados**
- **Notas internas** (visiveis apenas para a equipe)

## 10.5 Acoes em Lote

Selecione multiplas conversas para:
- Atribuir a agente/equipe
- Adicionar/remover labels
- Alterar status
- Excluir

---

# 11. RELATORIOS E METRICAS

## 11.1 Relatorios do Frontdesk

Acesse **Relatorios** no menu lateral do Frontdesk:

### Tipos de Relatorio:

| Relatorio | O que Mostra |
|---|---|
| **Visao Geral** | Metricas gerais (conversas, tempo de resposta, CSAT) |
| **Conversas** | Volume e tendencias de conversas |
| **Agentes** | Performance individual de cada agente |
| **Labels** | Metricas por etiqueta |
| **Canais** | Performance por canal (WhatsApp, Email, etc.) |
| **Equipes** | Performance por equipe |
| **CSAT** | Satisfacao do cliente |
| **SLA** | Cumprimento de metas de atendimento |
| **Bot** | Metricas de interacao com IA |

### Filtros:
- **Periodo**: Selecione intervalo de datas
- **Exportar**: Baixe relatorios em CSV

## 11.2 Metricas de Cobranca no KLaOS

Na pagina da campanha de cobranca:

| Metrica | Descricao |
|---|---|
| **Total Matriculados** | Devedores na campanha |
| **Total Enviados** | Mensagens disparadas |
| **Total Entregues** | Mensagens recebidas |
| **Total Respostas** | Clientes que responderam |
| **Total Pagamentos** | Pagamentos detectados |
| **Valor Recuperado** | Soma dos pagamentos |

---

# 12. TROUBLESHOOTING E FAQ

## Problemas Comuns

### "Mensagem nao foi enviada"
- **Verifique**: O canal WhatsApp esta ativo no Frontdesk?
- **Verifique**: O template esta APROVADO na Meta?
- **Verifique**: O numero do devedor esta correto (formato +55...)?
- **Verifique**: A campanha esta ATIVA (nao pausada)?
- **Verifique**: O horario esta dentro da janela de envio configurada?

### "Template aparece como PENDING"
- Templates novos ou editados passam por revisao da Meta
- Tempo tipico: minutos a horas
- Templates com conteudo sensivel (protesto, SPC) podem demorar mais

### "Cliente nao recebeu a mensagem"
- Verifique status de entrega no historico do devedor na campanha
- Se "Falha": o numero pode estar incorreto ou bloqueado
- Se "Enviado" mas nao "Entregue": telefone do cliente pode estar desligado

### "Labels nao aparecem no Frontdesk"
- Labels precisam ser criadas primeiro no Frontdesk (Configuracoes > Labels)
- O KLaOS cria labels automaticamente se nao existirem
- Verifique se os nomes das labels na campanha estao corretos

### "AI Agent nao esta respondendo"
- Verifique se o agente esta vinculado ao canal correto (AI Bridge)
- Verifique se o modo de resposta da campanha e "AI Agent"
- Verifique se o agente esta configurado corretamente no KLaOS

### "Pagamento nao foi detectado"
- A deteccao depende do webhook do TENEX
- Verifique se a integracao TENEX esta ativa
- O TENEX precisa notificar o KLaOS quando o pagamento e confirmado
- Pode haver delay de ate 24h na compensacao bancaria

## Boas Praticas

1. **Sempre configure TENEX primeiro** antes de criar campanhas
2. **Use templates WABA** (aprovados pela Meta) para garantir entrega
3. **Configure horarios de envio** respeitando o horario comercial (seg-sex, 9h-18h)
4. **Ative "Parar ao Pagar"** para nao enviar mensagens apos pagamento
5. **Crie equipes separadas** para diferentes tipos de escalacao
6. **Monitore diariamente** os status de entrega e respostas
7. **Nunca envie mensagens fora do horario** - respeite o cliente
8. **Mantenha templates atualizados** com dados de pagamento corretos

---

# GLOSSARIO

| Termo | Definicao |
|---|---|
| **WABA** | WhatsApp Business API - conexao oficial com a Meta |
| **Template** | Mensagem pre-aprovada pela Meta para envio via WhatsApp |
| **Label** | Etiqueta/tag colorida para organizar conversas |
| **Handoff/Transbordo** | Transferencia de conversa do bot para humano |
| **Regua de Cobranca** | Sequencia automatica de mensagens de cobranca |
| **Cadencia** | Sequencia de passos com timing definido |
| **Matricula/Enrollment** | Inclusao de um devedor em uma campanha |
| **Dispatch** | Envio agendado de uma mensagem |
| **PIX** | Sistema de pagamento instantaneo brasileiro |
| **Linha Digitavel** | Codigo numerico do boleto (codigo de barras em texto) |
| **TENEX** | Sistema ERP para gestao de boletos e cobrancas |
| **SSO** | Single Sign-On - login unico entre sistemas |
| **AI Agent** | Agente de inteligencia artificial para respostas automaticas |
| **Captain** | Modulo de IA nativo do Frontdesk |
| **CRM** | Customer Relationship Management - gestao de relacionamento |

---

**Documento criado por**: KLaOS Team
**Versao**: 1.0
**Data**: Abril 2026
**Classificacao**: Interno - Treinamento
