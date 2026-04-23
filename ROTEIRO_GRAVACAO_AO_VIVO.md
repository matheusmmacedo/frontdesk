# Roteiro de Gravacao ao Vivo — Mais Saude 24h

## Como funciona

- **VOCE (Matheus):** narra, explica, mostra o WhatsApp no celular
- **EU (Claude):** controlo o Playwright, clico nas telas, disparo templates, mudo tags
- **Comunicacao:** voce manda comandos aqui no terminal, eu executo e aviso quando pronto
- **Gravacao:** voce grava a tela do computador + celular ao lado

## Comandos que voce pode mandar

| Comando | O que eu faco |
|---------|---------------|
| `iniciar` | Apago campanha existente, crio nova, abro dashboard |
| `devedores` | Mostro aba devedores, expando um pra mostrar parcelas |
| `campanha` | Abro wizard de nova campanha |
| `ativar` | Ativo a campanha (mostra preview antes) |
| `matricular` | Matriculo voce (Matheus Teste +5521964798660) |
| `disparar step X` | Forca disparo do template do step X pro seu numero |
| `mostrar timeline` | Abro a timeline de eventos do seu enrollment |
| `frontdesk` | Abro o Frontdesk via SSO |
| `conversa` | Abro sua conversa no Frontdesk |
| `tag X` | Adiciono tag X na sua conversa (ex: `tag cobranca-promessa`) |
| `remover tag X` | Removo tag X da sua conversa |
| `limpar tags` | Removo todas as tags de cobranca (simula pagamento) |
| `automacao` | Navego pra Configuracoes > Automacao |
| `etiquetas` | Navego pra Configuracoes > Etiquetas |
| `proximo` | Passo pra proxima cena |
| `espera Xs` | Espero X segundos antes de continuar |
| `screenshot` | Tiro screenshot da tela atual |

---

## Preparacao (antes de gravar)

### Eu faco:
1. Apago enrollments antigos da campanha demo
2. Crio nova campanha com intervalos curtos (segundos, nao dias) pra demo
3. Configuro seu numero como devedor teste
4. Verifico que templates WABA estao aprovados
5. Abro KLaOS logado no Playwright

### Voce faz:
1. Abre gravador de tela (OBS ou similar)
2. Deixa WhatsApp aberto no celular (numero +5521964798660)
3. Posiciona celular visivel na gravacao (ou espelha tela)
4. Testa audio/microfone

---

## Fluxo da Gravacao

### BLOCO 1: KLaOS — Dashboard e Devedores (3 min)

**Voce manda:** `iniciar`
**Eu faco:** Abro app-dev.klaos.ai/collections, mostro dashboard

**Voce fala:**
> "Estamos no KLaOS, no modulo de Cobranca. Aqui vemos o dashboard com os numeros gerais: total de devedores do Tenex, divida total, media de atraso e taxa de recuperacao. Na aba Campanhas vemos as campanhas ativas."

**Voce manda:** `devedores`
**Eu faco:** Clico na aba Devedores, mostro tabela

**Voce fala:**
> "Na aba Devedores temos todos os clientes inadimplentes sincronizados do Tenex. A tabela mostra nome, CPF, telefone, divida e dias de atraso. As colunas sao clicaveis pra ordenar."

**Voce manda:** `expandir devedor`
**Eu faco:** Clico num devedor pra expandir, mostro dados + parcelas

**Voce fala:**
> "Clicando em qualquer devedor, abro o detalhe completo. Primeiro os dados do cliente — email, telefone e CPF copiaveis. Abaixo, as parcelas em aberto com vencimento, valor, dias de atraso, e os links de Boleto e PIX QR Code."

---

### BLOCO 2: Criando Campanha (4 min)

**Voce manda:** `campanha`
**Eu faco:** Clico em Nova Campanha, abro wizard

**Voce fala e eu vou clicando conforme voce pede:**
> "Vou criar uma campanha de cobranca..."

**Voce vai pedindo cada step:**
- `step 1` — eu mostro passo Modelo
- `step 2` — eu mostro passo Informacoes, preencho nome
- `step 3` — eu mostro passo Segmentacao, preencho filtros
- `step 4` — eu mostro passo Inbox, seleciono WABA
- `step 5` — eu mostro passo Cadencia com os 6 steps da regua
- `step 6` — eu mostro Revisao

**Voce manda:** `criar`
**Eu faco:** Clico em Criar Campanha

---

### BLOCO 3: Preview e Ativacao (2 min)

**Voce manda:** `ativar`
**Eu faco:** Clico em Ativar, mostro modal de Review com devedores impactados

**Voce fala:**
> "Antes de ativar, o sistema mostra um preview com todos os devedores que serao impactados, a divida total, e as tags da regua. Posso revisar e expandir cada devedor."

**Voce manda:** `confirmar`
**Eu faco:** Confirmo ativacao

---

### BLOCO 4: Matricular e Disparar (5 min) — TEMPO REAL

**Voce manda:** `matricular`
**Eu faco:** Matriculo voce na campanha

**Voce fala:**
> "Agora vou matricular um devedor na campanha. A partir desse momento a regua comeca."

**Voce manda:** `disparar step 1`
**Eu faco:** Envio template fatura_emissao pro seu WhatsApp
**Voce:** mostra celular recebendo a mensagem

**Voce fala:**
> "Olha aqui no WhatsApp: recebi a primeira mensagem da regua, o template fatura_emissao informando o valor e o link de pagamento."

**Voce manda:** `espera 30s` (ou quanto quiser)

**Voce manda:** `disparar step 2`
**Eu faco:** Envio template cobranca_vencimento_hoje
**Voce:** mostra celular

**Voce fala:**
> "Agora o segundo step, dia do vencimento. No Frontdesk a tag mudou de pendente pra cobranca-0d em azul claro."

**Repete pra steps 3, 4, 5...**

**Voce manda:** `disparar step 6`
**Eu faco:** Envio template fatura_atraso_21dias + faco handoff
**Voce:** mostra celular + mostra conversa atribuida ao time cobranca

---

### BLOCO 5: Lara Respondendo (3 min) — TEMPO REAL

**Voce manda:** `mostrar conversa`
**Eu faco:** Abro a conversa no Frontdesk

**Voce:** responde no WhatsApp com "Ola quero saber mais"
**Eu:** atualizo a tela pra mostrar a resposta da Lara

**Voce:** responde "Sobre essa cobranca"
**Eu:** atualizo

**Voce:** responde "Pix"
**Eu:** atualizo — Lara envia QR Code

**Voce fala:**
> "A Lara identificou a cobranca, explicou o valor e o vencimento, e quando eu disse Pix ela enviou o QR Code automaticamente."

---

### BLOCO 6: Tags Manuais (2 min)

**Voce manda:** `tag cobranca-promessa`
**Eu faco:** Adiciono tag na conversa

**Voce fala:**
> "O operador pode adicionar tags situacionais. Por exemplo, se o cliente promete pagar, adiciono cobranca-promessa."

**Voce manda:** `tag mais-saude`
**Eu faco:** Adiciono tag permanente

**Voce fala:**
> "E a tag mais-saude em verde e permanente — identifica pra sempre que esse cliente e do Mais Saude 24h."

**Voce manda:** `limpar tags`
**Eu faco:** Adiciono pagamento-realizado, automation rule limpa o resto

**Voce fala:**
> "Quando o pagamento e confirmado, adiciono pagamento-realizado. A automacao remove todas as tags de cobranca mas mantem as permanentes — olha, mais-saude continua ali em verde."

---

### BLOCO 7: Automacoes e Etiquetas (2 min)

**Voce manda:** `automacao`
**Eu faco:** Navego pra Configuracoes > Automacao

**Voce fala:**
> "Aqui em Configuracoes, Automacao, temos as duas regras: Pagamento Realizado que limpa tags e resolve, e Transbordo Humano que atribui ao time."

**Voce manda:** `etiquetas`
**Eu faco:** Navego pra Configuracoes > Etiquetas

**Voce fala:**
> "E aqui as 19 etiquetas com cores padronizadas. As permanentes: mais-saude verde, enviado-ao-spc laranja, cancelado preto, quer-cancelar amarelo."

---

### BLOCO 8: Timeline (1 min)

**Voce manda:** `mostrar timeline`
**Eu faco:** Volto pro KLaOS, abro campanha, aba Matriculados, expando seu enrollment

**Voce fala:**
> "De volta ao KLaOS, na timeline vejo todo o historico: cada mensagem enviada, quando foi entregue, quando foi lida, as respostas, tudo rastreado."

---

### ENCERRAMENTO

**Voce fala:**
> "Resumindo: do Tenex ao pagamento, tudo automatizado. A regua dispara sozinha, as tags se atualizam, a Lara atende, e o operador so intervem quando necessario. KLaOS e Frontdesk trabalhando juntos."

---

## Preparacao Tecnica (o que eu configuro antes)

### Templates que vou disparar manualmente (com os params corretos)

| Step | Template | Params |
|------|----------|--------|
| 1 | fatura_emissao | nome, valor, vencimento, link |
| 2 | cobranca_vencimento_hoje | nome, valor, vencimento, link |
| 3 | cobranca_atraso_5dias | nome, valor, vencimento, link |
| 4 | fatura_vencida_10dias | nome, valor, vencimento, link |
| 5 | fatura_atraso_15dias | nome, valor, vencimento, link |
| 6 | fatura_atraso_21dias | nome (so 1 param) |

### Dados do devedor teste

- Nome: Matheus Teste (ou seu nome real)
- Valor: R$ 150,00
- Vencimento: 20/03/2026
- Link: https://maisaudebh.tenex.com.br/fatura/boleto-pdf?codigo=8Pi2iIeNgVO3yxFCKnnnQQ&parcela=1
- Telefone: +5521964798660
- Conversa Chatwoot: #19 (display_id)

### API que uso pra disparar templates

```
POST https://app-desk-dev.klaos.ai/api/v1/accounts/10/conversations/19/messages
Header: api_access_token: PMs7ctLno2qJo9sPR9BGWbDh
Body: { template_params: { name, category, language, processed_params } }
```

### API que uso pra manipular tags

```
Chatwoot Labels API:
GET/POST /api/v1/accounts/10/conversations/19/labels
```

---

## Notas Importantes

- Os templates so funcionam fora da janela de 24h (que e o caso — a conversa esta fora)
- Dentro da janela (se voce responder), a Lara pode mandar texto livre
- Cada template precisa dos params corretos senao da erro 132000 do Meta
- fatura_atraso_21dias so tem 1 param (nome), os outros tem 4
- Apos voce responder no WhatsApp, a janela de 24h abre e a Lara pode responder em texto livre
- A automation rule de pagamento-realizado usa "contains" (nao "equal_to"), entao funciona mesmo com outras tags na conversa
