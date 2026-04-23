# ROTEIRO DE TESTES - CRM Engine KLaOS + Frontdesk
## Validacao Completa de Funcionalidades
### Abril 2026

---

# COMO USAR ESTE DOCUMENTO

Cada teste segue o formato:
- **O que testar** - descricao da funcionalidade
- **Passo a passo** - acoes exatas na interface
- **Resultado esperado** - o que deve acontecer
- **Integracao Frontdesk** - se/como reflete no Frontdesk

Marque [OK] ou [FALHA] em cada teste.

---

# MODULO 1: PIPELINES E ESTAGIOS

## Teste 1.1 - Criar Pipeline Personalizado

**Passo a passo:**
1. KLaOS > CRM > Negocios
2. Clique no icone de **colunas** (Kanban)
3. Clique em **Gerenciar Pipelines** (ou icone de engrenagem)
4. Clique em **Criar Pipeline**
5. Preencha:
   - Nome: "Pipeline Cobranca"
   - Descricao: "Fluxo de recuperacao de credito"
   - Cor: Azul
6. Confirme

**Resultado esperado:**
- [ ] Pipeline criado aparece na lista
- [ ] Selecionavel no filtro de pipeline do Kanban

## Teste 1.2 - Criar Estagios no Pipeline

**Passo a passo:**
1. Dentro do pipeline "Pipeline Cobranca", clique em **Adicionar Estagio**
2. Crie os seguintes estagios na ordem:

| Estagio | Probabilidade | Cor | Won/Lost |
|---|---|---|---|
| Inadimplente | 10% | Vermelho | - |
| Contatado | 30% | Laranja | - |
| Em Negociacao | 50% | Amarelo | - |
| Acordo Fechado | 80% | Verde claro | - |
| Pago | 100% | Verde | Marcar como WON |
| Juridico | 5% | Roxo | Marcar como LOST |

3. Confirme cada estagio

**Resultado esperado:**
- [ ] 6 estagios criados na ordem correta
- [ ] Colunas aparecem no Kanban
- [ ] Cores corretas em cada coluna

## Teste 1.3 - Reordenar Estagios

**Passo a passo:**
1. No gerenciador de pipeline, arraste "Em Negociacao" para antes de "Contatado"
2. Solte
3. Desfaca: arraste de volta para a posicao original

**Resultado esperado:**
- [ ] Drag-and-drop funciona
- [ ] Ordem reflete no Kanban imediatamente

## Teste 1.4 - Editar Estagio

**Passo a passo:**
1. Clique no estagio "Contatado"
2. Altere a probabilidade para 40%
3. Altere a cor para azul
4. Salve

**Resultado esperado:**
- [ ] Probabilidade atualizada
- [ ] Cor atualizada no Kanban

## Teste 1.5 - Deletar Estagio (sem negocios)

**Passo a passo:**
1. Clique no estagio "Juridico" (que nao tem negocios)
2. Clique em Excluir
3. Confirme

**Resultado esperado:**
- [ ] Estagio removido
- [ ] Coluna desaparece do Kanban

---

# MODULO 2: EMPRESAS

## Teste 2.1 - Criar Empresa com CNPJ

**Passo a passo:**
1. KLaOS > CRM > Empresas
2. Clique em **+ Nova Empresa**
3. Preencha:
   - Nome: Mais Saude 24 Horas
   - CNPJ: 12.345.678/0001-90 (ou CNPJ real)
4. Clique no botao de **Consultar CNPJ** (se disponivel)
5. Salve

**Resultado esperado:**
- [ ] Empresa criada com sucesso
- [ ] Se CNPJ valido: dados preenchidos automaticamente via BrasilAPI (razao social, endereco, telefone)
- [ ] Se CNPJ invalido: mensagem de erro de validacao

## Teste 2.2 - Criar Empresa Completa

**Passo a passo:**
1. Crie outra empresa com todos os campos:
   - Nome: Clinica Exemplo LTDA
   - CNPJ: (valido)
   - Email: contato@clinicaexemplo.com.br
   - Telefone: (31) 3333-4444
   - Website: https://clinicaexemplo.com.br
   - Setor: Saude
   - Porte: Pequena
   - Endereco: Rua Teste, 123
   - Cidade: Belo Horizonte
   - Estado: MG
   - Descricao: Clinica de teste

**Resultado esperado:**
- [ ] Todos os campos salvos corretamente
- [ ] Empresa aparece na lista
- [ ] Busca por nome funciona
- [ ] Filtro por setor funciona
- [ ] Filtro por porte funciona

## Teste 2.3 - Editar Empresa

**Passo a passo:**
1. Clique na empresa "Clinica Exemplo"
2. Altere o telefone para (31) 5555-6666
3. Salve

**Resultado esperado:**
- [ ] Telefone atualizado
- [ ] Data de atualizacao muda

## Teste 2.4 - CNPJ Duplicado

**Passo a passo:**
1. Tente criar outra empresa com o mesmo CNPJ da "Mais Saude"

**Resultado esperado:**
- [ ] Erro: CNPJ ja cadastrado
- [ ] Empresa NAO e criada

## Teste 2.5 - Exportar Empresas

**Passo a passo:**
1. Na lista de empresas, clique em **Exportar**

**Resultado esperado:**
- [ ] Arquivo JSON/CSV baixado
- [ ] Contem todas as empresas com campos corretos

## Teste 2.6 - Deletar Empresa

**Passo a passo:**
1. Clique na empresa "Clinica Exemplo"
2. Clique em Excluir
3. Confirme

**Resultado esperado:**
- [ ] Empresa removida da lista (soft delete)
- [ ] Contatos vinculados perdem o vinculo (nao sao deletados)

---

# MODULO 3: CONTATOS

## Teste 3.1 - Criar Contato Vinculado a Empresa

**Passo a passo:**
1. KLaOS > CRM > Contatos
2. Clique em **+ Novo Contato**
3. Preencha:
   - Nome: Gustavo Oliveira
   - Email: gustavo@maissaude.com.br
   - Telefone: (31) 99891-2489
   - Cargo: Diretor Comercial
   - Empresa: Mais Saude 24 Horas (selecionar no dropdown)
   - Tags: cliente, vip
4. Salve

**Resultado esperado:**
- [ ] Contato criado com vinculo a empresa
- [ ] Aparece na lista de contatos
- [ ] Na pagina da empresa, aparece como contato vinculado

## Teste 3.2 - Criar Contato com Email Duplicado

**Passo a passo:**
1. Tente criar outro contato com email gustavo@maissaude.com.br

**Resultado esperado:**
- [ ] Erro: email ja cadastrado no workspace
- [ ] Contato NAO e criado

## Teste 3.3 - Busca de Contatos

**Passo a passo:**
1. Na lista de contatos:
   - Busque por "Gustavo"
   - Busque por "gustavo@maissaude"
   - Busque por "99891"

**Resultado esperado:**
- [ ] Busca por nome encontra o contato
- [ ] Busca por email encontra o contato
- [ ] Busca por telefone encontra o contato

## Teste 3.4 - Editar Contato

**Passo a passo:**
1. Abra o contato "Gustavo Oliveira"
2. Altere o cargo para "CEO"
3. Adicione tag "decisor"
4. Salve

**Resultado esperado:**
- [ ] Cargo atualizado
- [ ] Tag adicionada

## Teste 3.5 - Ver Negocios do Contato

**Passo a passo:**
1. Abra o contato "Gustavo Oliveira"
2. Verifique a aba/secao de Negocios

**Resultado esperado:**
- [ ] Lista de negocios vinculados (vazia por enquanto)
- [ ] Apos criar negocio vinculado (Teste 4.1), aparece aqui

## Teste 3.6 - Exportar Contatos

**Passo a passo:**
1. Na lista de contatos, clique em **Exportar**

**Resultado esperado:**
- [ ] Arquivo baixado com todos os contatos
- [ ] Inclui: nome, email, telefone, empresa, cargo, tags

## Teste 3.7 - Integracao Frontdesk: Contato Sincronizado

**Passo a passo:**
1. Apos criar/editar o contato no KLaOS
2. Abra o Frontdesk (via SSO)
3. Va em **Contatos** no Frontdesk
4. Busque por "Gustavo Oliveira"

**Resultado esperado:**
- [ ] Contato existe no Frontdesk com nome e email corretos
- [ ] Se nao existe: verificar se o sync esta ativo (pode ser fire-and-forget)

---

# MODULO 4: NEGOCIOS (DEALS)

## Teste 4.1 - Criar Negocio

**Passo a passo:**
1. KLaOS > CRM > Negocios
2. Clique em **+ Nova Negociacao**
3. Preencha:
   - Nome: "Contrato Mais Saude - Cobranca"
   - Valor: 50000
   - Pipeline: Pipeline Cobranca
   - Estagio: Inadimplente
   - Empresa: Mais Saude 24 Horas
   - Contato: Gustavo Oliveira
   - Data prevista de fechamento: (30 dias a frente)
   - Tags: cobranca, prioritario
   - Notas: "Cliente com divida acumulada de 3 meses"
4. Salve

**Resultado esperado:**
- [ ] Negocio criado no estagio "Inadimplente"
- [ ] Card aparece na coluna correta do Kanban
- [ ] Valor formatado como R$ 50.000,00
- [ ] Tags visiveis no card

## Teste 4.2 - Kanban: Mover Negocio (Drag and Drop)

**Passo a passo:**
1. No Kanban, arraste o card "Contrato Mais Saude" de "Inadimplente" para "Contatado"
2. Solte

**Resultado esperado:**
- [ ] Card movido para nova coluna
- [ ] Status permanece "open"
- [ ] Probabilidade atualiza para a do estagio (40%)

## Teste 4.3 - Kanban: Mover para Estagio WON

**Passo a passo:**
1. Arraste o card para o estagio "Pago" (marcado como won_stage)

**Resultado esperado:**
- [ ] Status muda automaticamente para **won**
- [ ] Timestamp `won_time` registrado
- [ ] Card mostra indicador de ganho (verde)

## Teste 4.4 - Kanban: Mover para Estagio LOST

**Passo a passo:**
1. Arraste o card de "Pago" para "Juridico" (se existir, ou crie outro deal e mova)

**Resultado esperado:**
- [ ] Status muda automaticamente para **lost**
- [ ] Timestamp `lost_time` registrado

## Teste 4.5 - Filtros do Kanban

**Passo a passo:**
Teste cada filtro separadamente:
1. **Pipeline:** Troque entre pipelines
2. **Proprietario:** Filtre por "Meus" vs "Todos"
3. **Status:** Filtre por Aberto / Ganho / Perdido
4. **Ordenacao:** Ordene por Valor / Data de criacao / Data de fechamento
5. **Busca:** Busque pelo nome do negocio

**Resultado esperado:**
- [ ] Filtro por pipeline mostra apenas negocios daquele pipeline
- [ ] Filtro por proprietario funciona
- [ ] Filtro por status funciona
- [ ] Ordenacao altera a ordem dos cards
- [ ] Busca encontra o negocio por nome

## Teste 4.6 - Visao Lista

**Passo a passo:**
1. Troque para visao Lista (icone de lista)
2. Verifique as colunas: Nome, Valor, Estagio, Status, Empresa, Contato

**Resultado esperado:**
- [ ] Tabela mostra todos os negocios
- [ ] Colunas ordenáveis
- [ ] Dados corretos

## Teste 4.7 - Adicionar Atividade ao Negocio

**Passo a passo:**
1. Abra o negocio "Contrato Mais Saude"
2. Na aba **Atividades**, clique em **Adicionar Atividade**
3. Selecione tipo: "Ligacao"
4. Titulo: "Ligacao de cobranca"
5. Descricao: "Cliente atendeu, prometeu pagar em 5 dias"
6. Salve

**Resultado esperado:**
- [ ] Atividade aparece no timeline
- [ ] Tipo "Ligacao" com icone correto
- [ ] Data/hora registrada
- [ ] Usuario criador registrado

## Teste 4.8 - Adicionar Nota ao Negocio

**Passo a passo:**
1. Na aba Atividades, adicione tipo: "Nota"
2. Titulo: "Observacao interna"
3. Descricao: "Cliente sensivel, nao pressionar"

**Resultado esperado:**
- [ ] Nota aparece no timeline junto com a atividade anterior
- [ ] Diferenciada visualmente da ligacao

## Teste 4.9 - Campos Customizados

**Passo a passo:**
1. No formulario de edicao do negocio, procure a secao de campos customizados
2. Adicione campo: "motivo_inadimplencia" = "Desemprego"
3. Salve

**Resultado esperado:**
- [ ] Campo salvo em custom_fields (JSONB)
- [ ] Campo visivel na proxima abertura do negocio

## Teste 4.10 - Exportar Negocios

**Passo a passo:**
1. Clique em **Exportar** na pagina de negocios

**Resultado esperado:**
- [ ] Arquivo baixado
- [ ] Contem: nome, valor, estagio, status, empresa, contato, probabilidade

---

# MODULO 5: TAREFAS

## Teste 5.1 - Criar Tarefa Vinculada a Negocio

**Passo a passo:**
1. KLaOS > CRM > Tarefas (ou dentro do negocio)
2. Clique em **+ Nova Tarefa**
3. Preencha:
   - Titulo: "Ligar para Gustavo sobre pagamento"
   - Descricao: "Confirmar se fez o deposito"
   - Status: Pendente
   - Prioridade: Alta
   - Data limite: (amanha)
   - Negocio: Contrato Mais Saude
   - Contato: Gustavo Oliveira
   - Atribuir para: (seu usuario)
4. Salve

**Resultado esperado:**
- [ ] Tarefa criada com todos os campos
- [ ] Aparece na lista de tarefas
- [ ] Aparece na aba Tarefas do negocio

## Teste 5.2 - Filtros de Tarefas

**Passo a passo:**
Teste cada filtro:
1. **Status:** Pendente / Em Progresso / Concluida / Cancelada
2. **Prioridade:** Baixa / Media / Alta / Urgente
3. **Data:** Todas / Atrasadas / Hoje / Esta Semana / Este Mes
4. **Busca:** Busque pelo titulo

**Resultado esperado:**
- [ ] Cada filtro retorna apenas tarefas correspondentes
- [ ] Busca funciona por titulo e descricao

## Teste 5.3 - Atualizar Status da Tarefa

**Passo a passo:**
1. Mude o status da tarefa para "Em Progresso"
2. Depois para "Concluida"

**Resultado esperado:**
- [ ] Status atualizado
- [ ] Na visao do negocio, contador de tarefas atualiza (ex: "1/1 concluida")

## Teste 5.4 - Tarefa Atrasada

**Passo a passo:**
1. Crie tarefa com data limite no passado
2. Filtre por "Atrasadas"

**Resultado esperado:**
- [ ] Tarefa aparece com indicador de atraso
- [ ] Filtro "Atrasadas" a encontra

---

# MODULO 6: BUSCA GLOBAL

## Teste 6.1 - Busca Global (Cmd+K)

**Passo a passo:**
1. No KLaOS CRM, pressione **Cmd+K** (ou Ctrl+K)
2. Digite "Mais Saude"
3. Verifique os resultados

**Resultado esperado:**
- [ ] Modal de busca abre
- [ ] Encontra a Empresa "Mais Saude 24 Horas"
- [ ] Encontra o Negocio "Contrato Mais Saude"
- [ ] Encontra o Contato "Gustavo" (se vinculado a empresa)
- [ ] Resultados ordenados por relevancia

## Teste 6.2 - Busca por Diferentes Entidades

**Passo a passo:**
1. Busque por "gustavo" - deve encontrar contato
2. Busque por "cobranca" - deve encontrar negocio (tags ou nome)
3. Busque por "clinica" - deve encontrar empresa

**Resultado esperado:**
- [ ] Busca funciona em portugues (acentos)
- [ ] Resultados mostram tipo da entidade (Contato/Empresa/Negocio)

---

# MODULO 7: CONECTORES EXTERNOS

## Teste 7.1 - Verificar Conectores Disponiveis

**Passo a passo:**
1. KLaOS > Settings > Conectores
2. Verifique quais CRMs aparecem

**Resultado esperado:**
- [ ] Lista mostra: Kommo, Pipedrive, HubSpot, RD Station
- [ ] Status de cada um (Conectado / Nao conectado)

## Teste 7.2 - Conectar RD Station (se tiver credenciais)

**Passo a passo:**
1. Clique em RD Station > Configurar
2. Insira a API Key
3. Clique em Conectar

**Resultado esperado:**
- [ ] Conexao estabelecida
- [ ] Status muda para "Conectado"

## Teste 7.3 - Sincronizar Dados Externos

**Passo a passo:**
1. Apos conectar um CRM externo, clique em **Sincronizar**
2. Aguarde

**Resultado esperado:**
- [ ] Negocios importados aparecem com badge de origem (ex: "Kommo")
- [ ] Negocios externos sao **readonly** (nao editaveis)
- [ ] Filtro "Origem: Externo" mostra apenas esses negocios

## Teste 7.4 - Converter Negocio Externo para Interno

**Passo a passo:**
1. Encontre um negocio externo (readonly)
2. Clique em **Converter para Interno**
3. Confirme

**Resultado esperado:**
- [ ] Negocio se torna editavel
- [ ] Origem muda de "externo" para "interno"
- [ ] Referencia ao negocio original mantida

---

# MODULO 8: INTEGRACAO CRM + FRONTDESK

## Teste 8.1 - Contato CRM Reflete no Frontdesk

**Passo a passo:**
1. No KLaOS CRM, crie um contato:
   - Nome: "Teste Integracao"
   - Email: teste.integracao@example.com
   - Telefone: +5531999998888
2. Salve
3. Abra o Frontdesk (via SSO)
4. Va em Contatos > busque por "Teste Integracao"

**Resultado esperado:**
- [ ] Contato existe no Frontdesk
- [ ] Nome, email e telefone corretos
- [ ] Se NAO aparece: sync pode ser assincrono, aguarde ou force sync

## Teste 8.2 - Editar Contato no CRM e Verificar no Frontdesk

**Passo a passo:**
1. No KLaOS CRM, edite o contato "Teste Integracao"
2. Altere o telefone para +5531988887777
3. Salve
4. No Frontdesk, busque novamente o contato

**Resultado esperado:**
- [ ] Telefone atualizado no Frontdesk
- [ ] Demais campos mantidos

## Teste 8.3 - Conversa no Frontdesk com Contato CRM

**Passo a passo:**
1. No Frontdesk, envie uma mensagem WhatsApp para o numero do contato "Teste Integracao"
   (ou simule uma conversa de entrada)
2. Verifique se a conversa mostra os dados do contato

**Resultado esperado:**
- [ ] Conversa criada vinculada ao contato
- [ ] Painel lateral mostra nome, email, telefone do contato
- [ ] Historico de conversas do contato acessivel

## Teste 8.4 - Labels do Frontdesk e Negocios CRM

**Passo a passo:**
1. No Frontdesk, abra uma conversa
2. Adicione a label "cobranca-5d"
3. No KLaOS, verifique se o negocio vinculado (se existir) reflete essa informacao

**Resultado esperado:**
- [ ] Label aplicada na conversa do Frontdesk
- [ ] Verificar se ha sync de labels para o CRM (pode nao ter ainda)

## Teste 8.5 - Criar Contato no Frontdesk e Verificar no CRM

**Passo a passo:**
1. No Frontdesk, crie um contato manualmente:
   - Clique em Contatos > + Novo Contato
   - Nome: "Criado no Frontdesk"
   - Email: frontdesk.teste@example.com
2. No KLaOS CRM, busque por "Criado no Frontdesk"

**Resultado esperado:**
- [ ] Contato aparece no CRM (se sync bidirecional estiver ativo)
- [ ] Se NAO aparece: documentar que sync e unidirecional (CRM → Frontdesk apenas)

---

# MODULO 9: WORKFLOW COMPLETO (TESTE END-TO-END)

## Teste 9.1 - Fluxo Completo: Do CRM a Cobranca

Este teste conecta todas as pontas.

**Passo a passo:**

### Etapa 1: Preparar no CRM
1. Criar empresa "Teste E2E LTDA"
2. Criar contato "Maria E2E" vinculado a empresa, com telefone real
3. Criar negocio "Cobranca Teste E2E" valor R$ 100, estagio "Inadimplente"
4. Adicionar atividade: "Nota - Teste end-to-end de cobranca"

### Etapa 2: Verificar no Frontdesk
5. Abrir Frontdesk via SSO
6. Buscar contato "Maria E2E" - deve existir
7. Verificar que labels estao disponiveis

### Etapa 3: Simular Cobranca
8. No KLaOS > Funil > Cobranca
9. Verificar se "Maria E2E" pode ser matriculada (ou criar devedor teste no TENEX)
10. Se matriculada em campanha: verificar se mensagem e enviada
11. No Frontdesk: verificar se conversa foi criada com label correta

### Etapa 4: Simular Resposta
12. Enviar resposta simulada (ou responder do telefone de teste)
13. Verificar no Frontdesk se resposta aparece
14. Verificar se AI Agent responde (se configurado)

### Etapa 5: Simular Pagamento
15. Mover negocio para estagio "Pago" no Kanban CRM
16. Verificar se status muda para "won"
17. Verificar se a campanha de cobranca detectou o pagamento (via TENEX)

### Etapa 6: Verificar Metricas
18. No KLaOS: Verificar cards da campanha (enviados, pagamentos)
19. No Frontdesk > Relatorios: Verificar metricas de conversas

**Resultado esperado:**
- [ ] Empresa criada no CRM
- [ ] Contato criado e sincronizado com Frontdesk
- [ ] Negocio no Kanban com atividades
- [ ] Cobranca enviada via WhatsApp
- [ ] Conversa visivel no Frontdesk com labels
- [ ] Resposta processada pelo AI Agent
- [ ] Pagamento detectado e fluxo encerrado
- [ ] Metricas refletem todas as acoes

---

# MODULO 10: CASOS DE ERRO

## Teste 10.1 - Campos Obrigatorios Vazios

**Passo a passo:**
1. Tente criar negocio sem nome
2. Tente criar contato sem nome
3. Tente criar empresa sem nome

**Resultado esperado:**
- [ ] Erro de validacao em cada caso
- [ ] Mensagem clara indicando campo obrigatorio

## Teste 10.2 - Valor Negativo em Negocio

**Passo a passo:**
1. Tente criar negocio com valor -100

**Resultado esperado:**
- [ ] Erro: valor nao pode ser negativo

## Teste 10.3 - Email Invalido

**Passo a passo:**
1. Tente criar contato com email "nao-e-email"
2. Tente criar empresa com email "invalido@"

**Resultado esperado:**
- [ ] Erro de validacao de formato

## Teste 10.4 - Website Invalido

**Passo a passo:**
1. Tente criar empresa com website "nao-e-url"

**Resultado esperado:**
- [ ] Erro: URL deve comecar com http:// ou https://

## Teste 10.5 - Deletar Pipeline com Negocios

**Passo a passo:**
1. Tente deletar o pipeline que tem negocios ativos

**Resultado esperado:**
- [ ] Erro: "Pipeline possui X negocios ativos, nao pode ser excluido"

---

# RESUMO DE RESULTADOS

| Modulo | Total Testes | OK | Falha | Obs |
|---|---|---|---|---|
| 1. Pipelines e Estagios | 5 | | | |
| 2. Empresas | 6 | | | |
| 3. Contatos | 7 | | | |
| 4. Negocios (Deals) | 10 | | | |
| 5. Tarefas | 4 | | | |
| 6. Busca Global | 2 | | | |
| 7. Conectores Externos | 4 | | | |
| 8. Integracao Frontdesk | 5 | | | |
| 9. Teste End-to-End | 1 | | | |
| 10. Casos de Erro | 5 | | | |
| **TOTAL** | **49** | | | |

---

# NOTAS DE INTEGRACAO CRM ↔ FRONTDESK

## O que funciona hoje:
1. **CRM → Frontdesk (unidirecional):** Contatos criados/editados no CRM sao sincronizados para o Frontdesk (fire-and-forget)
2. **Conversas ↔ Negocios:** Negocios podem ter `conversation_id` vinculando a uma conversa
3. **Contatos ↔ Conversas:** Contatos CRM tem `frontdesk_contact_id` vinculando ao contato no Frontdesk
4. **Templates WhatsApp:** Templates do Frontdesk sao usados pelo sistema de Cobranca

## O que pode precisar de validacao:
1. **Sync bidirecional:** Contato criado no Frontdesk reflete no CRM? (verificar)
2. **Labels sync:** Labels do Frontdesk refletem no CRM? (provavelmente nao)
3. **Webhook de conversa:** Quando conversa e criada no Frontdesk, o CRM e notificado? (via webhook)

---

**Documento criado por:** KLaOS Team
**Versao:** 1.0
**Data:** Abril 2026
