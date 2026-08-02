# Revisão do plano de sticky assignment — 02/08/2026

Revisão do plano produzido pela investigação de 02/08, depois que o baseline
mediu o ambiente real. **Quatro premissas caíram.** Este documento substitui as
partes afetadas; o resto do plano original continua valendo.

---

## Decisão do dono do produto

> **O sticky gruda em quem RESPONDEU, não em quem estava atribuído.**

É a mudança mais importante da revisão, e ela resolve sozinha o problema que
inviabilizava o desenho anterior.

---

## 1. Por que a premissa antiga caiu

O plano original apostava em `additional_attributes['klaos_last_assignee_id']`,
gravado por `custom/config/initializers/track_resolved_timestamp.rb` no momento
do resolve. O baseline mediu:

| Métrica (PROD conta 9) | Valor |
|---|---|
| Conversas resolvidas com a chave presente | 2208 de 2208 (100%) |
| Chave com valor **não-nulo** | 655 (30%) |
| Não-nulo nos últimos 7 dias | 107 de 488 (**22%**) |
| Valor igual ao `assignee_id` atual | 2201 de 2208 |

Duas conclusões:

1. **Nulo em 78% dos casos recentes.** No instante do resolve o assignee já
   tinha sido zerado (resolve do bot, ou unassign antes do resolve). Não há a
   quem grudar.
2. **Onde não é nulo, não acrescenta nada.** Bate com o assignee atual em
   99,7% dos casos — é espelho do estado corrente, não memória do passado.

---

## 2. O novo critério de dono

**Dono da conversa = o último agente HUMANO que enviou mensagem ao cliente.**

Por que é melhor:

- **Sempre existe**, se houve atendimento humano. Não depende do `assignee`
  estar preenchido no instante certo.
- **Semanticamente correto**: quem falou com o cliente tem o contexto. É o que
  o cliente espera ao voltar.
- **Resolve o bucket órfão**: das 290 conversas resolvidas sem assignee, sem
  time e sem bot, as que tiveram resposta humana passam a ter dono.
- **É auditável**: a mensagem está lá, com autor e timestamp. Não é inferência.

### Definição precisa

Última mensagem com:
- `message_type = 1` (outgoing)
- `sender_type = 'User'`
- `private = false` (nota interna não conta como atendimento)
- `sender_id` **não** pertencendo aos usuários de sistema

### Quem fala com o cliente, e quem pode ser dono

Três papéis distintos escrevem na conversa, e só um deles é candidato a dono:

| Quem | O que faz | `sender_type` | Vira dono sticky? |
|---|---|---|---|
| **Atendente humano** | atende de verdade | `User` | **sim — é o único** |
| **Lara / ANA** | responde como IA | `agent_bot` | não — é o **estado padrão**, para onde a conversa volta quando a janela vence |
| **Klaus** | executa ações de automação | `User` | **não** |

O Klaus não conversa: ele atribui, transfere, devolve ao bot. Mas **escreve
mensagem** — foi observado publicando `"**Histórico da conversa (IA):**"` como
`message_type: 1` (outgoing), `sender_type: user`. Como ele é `User` e não
`AgentBot`, o filtro por tipo sozinho **não** o exclui. Sem tratá-lo, o sticky
grudaria no Klaus em praticamente toda conversa tocada por automação, e o
cliente voltaria para um "atendente" que não existe.

A Lara e a ANA saem naturalmente pelo filtro `sender_type = 'User'`, porque são
`AgentBot` de verdade. E é o comportamento certo: quando só a IA respondeu, não
existe dono humano — a conversa pertence ao bot, que já é o padrão.

### A armadilha dos usuários de sistema

`sender_type = 'User'` **não** significa humano. Verificado em PROD conta 9:

```
 3 | Daniel          | daniel@glocalmybiz.com
12 | Gustavo Oliveira| gustavooliveiranetwork@gmail.com
17 | Klaus           | klaus@klaos.ai          <-- NAO e humano
15 | Ludiana Gomes   | ludianagomes274@gmail.com
13 | Marta Bueno     | martabuenopeixoto89@gmail.com
10 | Matheus         | matheus@matheus.pro.br
14 | Yasmin Pietra   | yasminsayaopietracoelho@gmail.com
```

O **Klaus é um `User`**, não um `AgentBot`, e é ele quem carimba as ações
automáticas do KLaOS (atribuição, transferência, resumo de conversa). Sem
excluí-lo, o sticky grudaria no Klaus em praticamente toda conversa tocada por
automação — e o cliente voltaria para um "atendente" que não existe.

A Lara/ANA não têm esse problema: são `AgentBot` de verdade
(`sender_type = 'agent_bot'`), então já ficam de fora pelo filtro `'User'`.

**Como excluir, de forma multi-tenant:**

`accounts.settings['klaos_system_user_ids']` — array de inteiros.
Default quando ausente: derivar dos agentes cujo e-mail termina em `@klaos.ai`.

Motivo de ser configurável e não hardcode de e-mail: um cliente pode ter usuário
com domínio próprio fazendo papel de robô, e o inverso — um humano da equipe
KLaOS atendendo de verdade. A lista explícita ganha do heurístico.

Para as contas atuais: PROD 9 → `[17]`. DEV 10 → `[25]`. DEV 12 → `[25, 26]`
(Klaus + o usuário-bot ANA, se ainda existir).

---

## 3. Onde capturar

O plano original mandava carimbar no resolve. **Não serve** — é exatamente onde
o dado já morreu.

Duas opções, em ordem de preferência:

### Opção A — calcular na hora (recomendada)

No instante do retorno do cliente, consultar as mensagens da conversa e achar o
último humano. Sem carimbo, sem migration, sem estado para dessincronizar.

- **A favor**: zero dado novo, funciona retroativamente para as 952 conversas do
  passivo, impossível ficar defasado.
- **Contra**: uma query a mais no caminho quente. Mitigável — a busca é por
  `conversation_id`, indexada, com `LIMIT` e varrendo de trás para frente.

### Opção B — carimbar no envio

Um callback em `custom/` que, a cada mensagem outgoing de humano, grava
`klaos_last_human_responder` em `additional_attributes`.

- **A favor**: leitura instantânea na hora da decisão.
- **Contra**: só vale para conversas novas — o passivo de 952 fica de fora até
  alguém responder de novo. E é mais um estado para divergir.

**Recomendação: A.** Se a medição mostrar custo relevante, B vira cache por cima
de A, não substituto.

---

## 4. Os outros três achados do baseline

### 4.1 A exposição é maior que o plano dizia

| Bucket (PROD conta 9) | Qtd |
|---|---|
| Resolvidas com dono humano, sem bot ancorado | 662 |
| Resolvidas **sem** assignee, **sem** time, **sem** bot | 290 |
| **Total mudo se o cliente voltar** | **952** |

O plano cobria só as 662. As 290 também não têm quem responda — e com o critério
novo, boa parte delas passa a ter dono identificável.

### 4.2 Dois terços do estoque ficam fora do alcance

Das 662, **428 (65%) estão paradas há mais de 30 dias**. Com o teto proposto de
`klaos_sticky_sweep_max_age_hours = 720` (30 dias), elas nunca seriam varridas.

Decisão necessária: ou o teto sobe, ou o plano declara explicitamente que o
passivo antigo fica de fora e é tratado à mão. **Não deixar implícito.**

### 4.3 Dev não consegue exercitar o rodízio

Não existe **nenhuma caixa em dev** com 2+ humanos na interseção
`inbox.member_ids_with_assignment_capacity ∩ team.members`:

- **Blue Care (conta 12)**: inbox 38 tem Gustavo(13), Klaus(25), ANA(26). Os
  agentes reais — ricardobluecare(27) e Gustavo Blue Care(28) — estão nos
  **times** mas **não são membros do inbox**. Interseção = 1 pessoa nos times
  18/20/21/22, e **vazia** nos times 16, 17 e 19 (que devolvem 422 no_candidates).
- **Mais Saúde (conta 10)**: inbox 30 tem 1 membro e `enable_auto_assignment`
  está **FALSE**; inbox 37 tem 1 membro.

**Pré-requisito de validação**: como a decisão foi validar em dev (não há Ruby
na máquina para RSpec), arrumar a estrutura de dev deixa de ser opcional. Sem
isso, o requisito 2 não tem como ser provado antes de produção.

Ação mínima: adicionar ricardobluecare(27) e Gustavo Blue Care(28) como membros
do inbox 38, e ligar `enable_auto_assignment` onde estiver desligado.

---

## 5. O que muda nos passos

| Passo | Situação |
|---|---|
| 0 — baseline | **feito** |
| 1 — snapshot no resolve | **descartado.** Commit `37e93b461` não serve: carimba onde o dado já é nulo |
| 1' — **resolvedor de dono por última resposta** | **novo**, substitui o passo 1 |
| 2 — extrair AssignmentPicker / ReturnToBotService | inalterado |
| 3 — config em accounts.settings | inalterado, **mais** `klaos_system_user_ids` |
| 3.5 — **arrumar estrutura de dev** | **novo**, pré-requisito de validação |
| 4 — motor sticky em dry-run | inalterado no desenho; passa a consumir 1' |
| 5–11 | revisar depois do dry-run observado |

---

## 6. Restrições que continuam valendo

- **Não há Ruby na máquina.** `ruby`, `bundle`, Docker, WSL com distro e rbenv:
  todos ausentes, verificado. Nenhum RSpec roda local. Validação do fork é em dev,
  com Playwright clicando de verdade e SQL conferindo o efeito.
- **Toda escolha passa por `inbox.member_ids_with_assignment_capacity`**,
  inclusive a do dono sticky. Já houve regressão de atribuir para quem não era da
  caixa (Gustavo virou assignee no SAC sem ser membro).
- **Não consertar o `reopenPolicy` do KLaOS.** Os bugs dele (`klaos_user_id`
  inexistente, epoch float em timestamptz) são a garantia acidental de que ele
  está inerte. Consertar antes de removê-lo cria duas engines brigando pela
  mesma decisão.
- **Nada em produção** até o dry-run ser observado e revisado com o Gustavo.

---

## 7. Pergunta em aberto para o Gustavo

A janela padrão fica em **360 minutos (6h)**, não nas 24h do documento original.
Motivo: 360 é o que o único cliente maduro escolheu na prática, e o código nunca
acompanhou. Confirmar antes de ligar.
