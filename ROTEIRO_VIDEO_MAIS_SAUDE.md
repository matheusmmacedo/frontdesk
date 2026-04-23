# Roteiro de Video: Mais Saude 24h - Cobranca Automatizada

**Duracao estimada: 5-6 minutos**

---

## CENA 1: Dashboard KLaOS (30s)

**Tela:** `app-dev.klaos.ai` → Atendimento → Collections

> "Aqui no KLaOS temos o modulo de Cobranca. No dashboard vemos os cards com metricas: total de devedores sincronizados do Tenex, valor total de divida, dias medios de atraso e taxa de recuperacao."

**Acoes:**
- Mostrar os stats cards no topo
- Mostrar os cards de campanhas ativas com metricas (matriculados, enviados, respostas, pagamentos)

---

## CENA 2: Sync Tenex (20s)

**Tela:** Aba "Devedores"

> "Os devedores sao sincronizados automaticamente do Tenex a cada hora. Posso tambem forcar um sync manual. Aqui vejo nome, CPF, telefone, valor da divida e dias de atraso."

**Acoes:**
- Clicar na aba "Devedores"
- Mostrar tabela com busca e filtro por status
- Clicar no botao sync

---

## CENA 3: Criar Campanha (60s)

**Tela:** "Nova Campanha" → Wizard

> "Vou criar uma campanha de cobranca. Posso usar um template pronto ou criar do zero."

### Step 1 - Info:
> "Dou um nome, habilito auto-matricula pra novos devedores entrarem automaticamente."

### Step 2 - Segmentacao:
> "Filtro: minimo 5 dias de atraso, apenas com plano ativo. Marco parar ao pagar."

### Step 3 - Canal:
> "Seleciono o inbox KLaOS Cobranca — e WABA oficial, entao posso mandar template fora da janela de 24 horas."

### Step 4 - Cadencia (regua):
> "Aqui monto a regua de mensagens. Cada step tem o dia relativo ao vencimento e o template WABA aprovado pelo Meta:"

| Step | Dia | Tag | Template |
|------|-----|-----|----------|
| 1 | Enrollment | `pendente` (amarelo) | fatura_emissao |
| 2 | D0 vencimento | `cobranca-0d` (azul claro) | cobranca_vencimento_hoje |
| 3 | D+5 | `cobranca-5d` (rosa) | cobranca_atraso_5dias |
| 4 | D+10 | `cobranca-10d` (roxa) | fatura_vencida_10dias |
| 5 | D+15 | `cobranca-15d` (laranja) | fatura_atraso_15dias |
| 6 | D+21 | `transbordo-humano` (azul) | fatura_atraso_21dias + handoff |

> "No ultimo passo marco 'transferir para humano' — a conversa vai pro time cobranca no Frontdesk."

### Step 5 - Revisao:
> "Reviso tudo e ativo a campanha."

---

## CENA 4: Matricular Devedores (30s)

**Tela:** Detalhe da campanha → aba "Adicionar Devedores"

> "Seleciono os devedores que quero matricular na campanha e clico em matricular. A partir de agora a regua roda sozinha — o sistema checa a cada 30 minutos se ha mensagens pra enviar."

**Acoes:**
- Selecionar 2-3 devedores com checkbox
- Clicar "Matricular"

---

## CENA 5: Acompanhamento (40s)

**Tela:** Aba "Matriculados"

> "Na aba Matriculados vejo cada devedor com: step atual, status de entrega, e proximo disparo. Clicando na linha, abro a timeline com todo o historico."

**Acoes:**
- Mostrar tabela de enrollments
- Expandir uma linha para mostrar timeline de eventos (matriculado → mensagem enviada → entregue → lida)
- Mostrar status de entrega (checkmarks azul/verde)

---

## CENA 6: Frontdesk - Tags na Conversa (60s)

**Tela:** SSO → Chatwoot (app-desk-dev.klaos.ai)

> "Agora vou ao Frontdesk pra ver como as tags aparecem na conversa. Entro pelo SSO do KLaOS."

**Acoes:**
- Abrir o Frontdesk via SSO (menu Atendimento)
- Ir em Conversas → Todos
- Abrir uma conversa do inbox KLaOS Cobranca

> "Veja as tags automaticas: a cada step da regua, a tag muda. Aqui esta `cobranca-5d` rosa — significa que o cliente esta no 5o dia de atraso."

**Acoes:**
- Mostrar as tags na conversa (sidebar direita)
- Apontar as cores diferentes: amarelo (pendente), azul claro (0d), rosa (5d), roxa (10d), laranja (15d)

> "E temos tags permanentes que nunca saem: `mais-saude` em verde — identifica pra sempre que esse cliente e do Mais Saude 24h."

---

## CENA 7: Tags Especiais e Pagamento (40s)

**Tela:** Chatwoot - conversa

> "O operador pode adicionar tags situacionais manualmente conforme a conversa:"

| Tag | Quando usar |
|-----|-------------|
| `cobranca-promessa` | Cliente promete pagar em data X |
| `cobranca-promessa-hoje` | Cliente vai pagar hoje |
| `cobranca-negociacao` | Cliente negocia prazo |
| `cobranca-segunda-via` | Cliente solicita segunda via |
| `cobranca-cartao-recusado` | Cartao recusado |
| `cobranca-cartao-pendente` | Aguardando novo cartao |
| `cobranca-boleto-pendente` | Aguardando boleto (transferido para Marta) |
| `cancelamento-pendente` | Cliente quer cancelar |

> "Quando o pagamento e confirmado, a tag `pagamento-realizado` verde e adicionada. O sistema limpa automaticamente todas as tags de cobranca, mas preserva as permanentes."

**Acoes:**
- Demonstrar adicionando uma tag manualmente na conversa
- Mostrar que as permanentes ficam

---

## CENA 8: Regras de Automacao (40s)

**Tela:** Frontdesk → Configuracoes → Automacao

> "No Frontdesk temos regras de automacao que fazem a magica acontecer nos bastidores. Sao regras visiveis e editaveis aqui em Configuracoes."

**Acoes:**
- Navegar ate Configuracoes → Automacao
- Mostrar a lista com as 2 regras

> "Regra 1 — Pagamento Realizado: quando a tag `pagamento-realizado` e adicionada na conversa, o sistema automaticamente remove todas as tags de cobranca, mantem as permanentes como `mais-saude`, e resolve a conversa."

**Acoes:**
- Clicar na regra pra expandir detalhes
- Mostrar condicao (label contains pagamento-realizado)
- Mostrar acoes (remove labels, add pagamento-realizado, resolve)

> "Regra 2 — Transbordo Humano: quando a tag `transbordo-humano` aparece — no D+21 da regua ou colocada manualmente — a conversa e automaticamente atribuida ao time de cobranca e o gestor recebe um alerta por email."

**Acoes:**
- Clicar na segunda regra
- Mostrar condicao (label contains transbordo-humano)
- Mostrar acoes (assign team cobranca, email)

---

## CENA 9: Etiquetas Configuradas (20s)

**Tela:** Frontdesk → Configuracoes → Etiquetas

> "Todas as 19 etiquetas estao configuradas com cores padronizadas conforme definido pela operacao."

**Acoes:**
- Navegar ate Configuracoes → Etiquetas
- Scroll mostrando toda a lista
- Destacar as 4 permanentes:

| Tag | Cor | Significado |
|-----|-----|-------------|
| `mais-saude` | Verde | Cliente do Mais Saude 24h |
| `enviado-ao-spc` | Laranja | Enviado ao SPC/Serasa |
| `cancelado` | Preto | Contrato cancelado |
| `quer-cancelar` | Amarelo vivo | Cliente quer cancelar |

---

## CENA 10: Lara em Acao (30s)

**Tela:** Conversa no Chatwoot

> "Quando o cliente responde uma mensagem de cobranca, a Lara — nossa IA — assume a conversa. Ela explica a divida, oferece opcoes de pagamento por PIX ou boleto, e pede o comprovante."

**Acoes:**
- Mostrar a conversa com a Lara respondendo
- Mostrar Lara enviando link de PIX
- Mostrar Lara pedindo comprovante

> "Se ela nao conseguir resolver, faz o transbordo pro time de cobranca."

---

## ENCERRAMENTO (15s)

> "Resumindo: do Tenex ao pagamento, tudo automatizado. A regua dispara sozinha, as tags se atualizam, a Lara atende, e o operador so intervem quando necessario. Tudo integrado entre KLaOS e Frontdesk."

---

**Tempo total estimado: ~5:30**

## Checklist pre-gravacao

- [ ] Ter pelo menos 1 campanha ativa com enrollments no KLaOS dev
- [ ] Ter pelo menos 1 conversa no inbox KLaOS Cobranca com tags visiveis
- [ ] Verificar que as 19 etiquetas aparecem em Configuracoes → Etiquetas
- [ ] Verificar que as 2 regras aparecem em Configuracoes → Automacao
- [ ] Ter a conversa da Lara com interacao (PIX/boleto) disponivel pra mostrar
