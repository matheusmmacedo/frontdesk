# PLANO DE SUBIDA DE TEMPLATES - META
## Versao Final com Negritos + Novos Nomes
### 08/04/2026 - AGUARDANDO APROVACAO INTERNA

---

# NOTA IMPORTANTE: NEGRITOS FUNCIONAM

Pesquisa confirmou que templates WABA **SUPORTAM** formatacao WhatsApp no body:
- Negrito: *texto* (asteriscos simples)
- Italico: _texto_ (underscores)
- Tachado: ~texto~ (til)

Fonte: documentacao oficial Meta + WhatsApp Help Center

---

# PLANO DE EXECUCAO

## Fase 1: Criar 6 templates NOVOS (nomes novos)
## Fase 2: Testar envio dos novos
## Fase 3: Atualizar KLaOS para usar nomes novos
## Fase 4: Excluir 8 templates antigos

Motivo de criar novos em vez de editar:
- Editar tem lock de 24h entre edicoes
- Nomes novos padronizados
- Templates antigos ficam como fallback ate tudo funcionar
- Exclusao so apos validacao completa

---

# TEMPLATES NOVOS A CRIAR

## Padrao de nomes:
- Prefixo: `ms24h_` (Mais Saude 24 Horas)
- Categoria: UTILITY
- Idioma: pt_BR
- Encoding: Unicode escapes no JSON (\u00e1 para a, etc.)

## Padrao de footer (igual em todos exceto D+21):

```
Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

## Padrao de botoes (igual em todos exceto D+21):

```
[Botao 1] Pagar via PIX → https://app.klaos.ai/pay/{{1}}
[Botao 2] Ver Boleto (PDF) → https://app.klaos.ai/boleto/{{1}}
```

---

# TEMPLATE 1: Geracao do Boleto (D-5)

**Nome Meta:** `ms24h_fatura_geracao`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:**
- {{1}} = nome do cliente
- {{2}} = valor (ex: R$ 150,00)
- {{3}} = data de vencimento
- {{4}} = linha digitavel (codigo de barras)

**Variaveis Botoes:**
- Botao 1 {{1}} = payment page code
- Botao 2 {{1}} = payment page code

**Texto exato a enviar (com negritos do Gustavo):**

```
Ola {{1}}!
Informamos que sua fatura da MAIS SAUDE 24 HORAS, no valor de {{2}} *vence em 5 dias, no dia {{3}}.*

Realize o pagamento de preferencia *antes do vencimento para evitar multas e juros.*

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

**Negritos identificados no Word:**
- "vence em 5 dias, no dia {{3}}." → *vence em 5 dias, no dia {{3}}.*
- "antes do vencimento para evitar multas e juros." → *antes do vencimento para evitar multas e juros.*

**% UTILITY: 95%**

---

# TEMPLATE 2: Dia do Vencimento (D0)

**Nome Meta:** `ms24h_vencimento_hoje`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=nome, {{2}}=valor, {{3}}=data, {{4}}=linha digitavel
**Variaveis Botoes:** {{1}}=code (ambos)

**Texto exato a enviar (com negritos do Gustavo):**

```
Ola {{1}}!
Sua fatura da MAIS SAUDE 24 HORAS *vence hoje dia {{3}}. O valor de {{2}}.*

Realize *o pagamento antes do vencimento* para evitar multas e juros.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

**Negritos identificados no Word:**
- "vence hoje dia {{3}}. O valor de {{2}}." (tudo junto em bold) → *vence hoje dia {{3}}. O valor de {{2}}.*
- "o pagamento antes do vencimento" → *o pagamento antes do vencimento*

**Nota:** Gustavo removeu o capslock "VENCE HOJE". Agora esta em minusculo com negrito. Aprovacao sobe.

**% UTILITY: 90%**

---

# TEMPLATE 3: 1 Dia Vencido (D+1)

**Nome Meta:** `ms24h_boleto_vencido`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=nome, {{2}}=valor, {{3}}=data, {{4}}=linha digitavel
**Variaveis Botoes:** {{1}}=code (ambos)

**Texto exato a enviar (com negritos do Gustavo):**

```
*Boleto Vencido*

Ola {{1}}!
Queremos te avisar que *o boleto registrado em seu CPF venceu dia {{3}}* gerado pela MAIS SAUDE 24 HORAS, no valor de {{2}}.

Realize o pagamento e regularize seu debito.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

**Negritos identificados no Word:**
- "Boleto Vencio" (titulo) → *Boleto Vencido* (corrigido "Vencio" para "Vencido")
- "o boleto registrado em seu CPF venceu dia {{3}}" → *o boleto registrado em seu CPF venceu dia {{3}}*

**Riscos mantidos:**
- "registrado em seu CPF" - flag de dado pessoal (risco medio)
- "Boleto Vencido" como titulo em negrito no body - pode parecer marketing (risco leve)

**% UTILITY: 60%**
**% MARKETING: 25%**
**% REJEICAO: 15%**

**Nota:** Gustavo manteve "CPF" mesmo apos aviso. Vamos subir como ele quer.

---

# TEMPLATE 4: 7 Dias Vencido (D+7)

**Nome Meta:** `ms24h_atraso_7dias`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=nome, {{2}}=valor, {{3}}=data, {{4}}=linha digitavel
**Variaveis Botoes:** {{1}}=code (ambos)

**Texto exato a enviar (com negritos do Gustavo):**

```
Ola {{1}}!
Queremos te lembrar que a cobranca gerada pela MAIS SAUDE 24 HORAS, *no valor de {{2}} venceu ha 7 dias, no dia {{3}}.*

Lembrando que o boleto e registrado no banco e com a falta do pagamento o banco pode executar o titulo no SPC e em protesto.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

**Negritos identificados no Word:**
- "no valor de {{2}} venceu ha 7 dias, no dia {{3}}." → *no valor de {{2}} venceu ha 7 dias, no dia {{3}}.*

**Riscos:**
- "SPC e em protesto" juntos - risco medio de reclassificacao MARKETING

**% UTILITY: 70%**
**% MARKETING: 25%**

**Nota:** Gustavo corrigiu "a 7 dias" para "ha 7 dias" e marcou "VAMOS TENTAR ASSIM". Mantido.

---

# TEMPLATE 5: 15 Dias Vencido (D+15)

**Nome Meta:** `ms24h_atraso_15dias`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=nome, {{2}}=valor, {{3}}=data, {{4}}=linha digitavel
**Variaveis Botoes:** {{1}}=code (ambos)

**Texto exato a enviar (com negritos do Gustavo):**

```
Ola, recebemos hoje um relatorio do banco onde consta o seu nome na lista de inadimplentes, pois seu boleto ultrapassou o prazo permitido para pagamento.

Voce consegue fazer o pagamento hoje ainda e enviar o comprovante?

*Caso nao consiga, o banco vai executar o titulo alem de SPC.*

Para isso nao acontecer gentileza encaminhar comprovante.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

**Negritos identificados no Word:**
- "Caso nao consiga, o banco vai executar o titulo alem de SPC." → *Caso nao consiga, o banco vai executar o titulo alem de SPC.*

**Mudancas que o Gustavo fez (vs versao anterior):**
- Removeu "Bom dia"
- Trocou "seu CPF" por "seu nome"
- Removeu "vamos perder acesso a sua conta"
- Removeu "cartorio + taxa extrajudicial + Serasa" (deixou so "SPC")
- Removeu "com urgencia!"
- Simplificou bastante

**Riscos restantes:**
- Sem {{1}} (nome) no texto - nao personaliza. Meta prefere templates personalizados. (Flag medio)
- Sem {{2}} (valor) e {{3}} (data) no texto - poucos dados transacionais. (Flag medio)
- "lista de inadimplentes" - termo estigmatizante. (Flag medio)
- "Voce consegue fazer o pagamento" - pergunta interativa = tom MARKETING. (Flag medio)
- Acumulo de 4 flags medios = risco consideravel

**% UTILITY: 40%**
**% MARKETING: 45%**
**% REJEICAO: 15%**

**Nota:** Gustavo reescreveu este template ("MUDEI VAMOS TENTAR ASSIM"). Melhorou muito vs versao anterior (era 5% UTILITY). Removeu "Bom dia", "CPF", "perder acesso a conta", "cartorio + extrajudicial + Serasa", "urgencia!". Riscos restantes sao medios. Cliente aceita arriscar.

---

# TEMPLATE 6: 21 Dias Vencido - Transbordo Humano (D+21)

**Nome Meta:** `ms24h_transbordo_21dias`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=nome
**Botoes:** Nenhum (transbordo humano)

**Texto exato a enviar:**

```
Ola {{1}}

Informamos que, devido a inadimplencia, seu titulo foi encaminhado ao cartorio de protesto e aos orgaos de protecao ao credito (SPC e Serasa). Para regularizar sua situacao e evitar restricoes no CPF, entre em contato com urgencia pelo WhatsApp ou telefone abaixo.

Telefone: (31) 98248-8131
```

**Negritos identificados no Word:** Nenhum neste template.

**Mudanca do Gustavo:** Trocou "URGENCIA" capslock por "urgencia" minusculo. Boa mudanca.

**% UTILITY: 90%**

---

# TEMPLATE EXTRA: Pagamento Confirmado

**Nome Meta:** `ms24h_pagamento_ok`
**Categoria:** UTILITY
**Idioma:** pt_BR

**Variaveis Body:** {{1}}=valor
**Botoes:** Nenhum

**Texto (sem mudanca do Gustavo - manter atual):**

```
Pagamento confirmado! Recebemos o valor de {{1}} referente a sua mensalidade do plano Mais Saude. Obrigado por manter seus beneficios em dia.
```

**% UTILITY: 99%**

---

# RESUMO DO PLANO

## Novos templates a CRIAR:

| # | Nome Novo | Dia | % UTILITY | Botoes |
|---|---|---|---|---|
| 1 | ms24h_fatura_geracao | D-5 | 95% | PIX + Boleto |
| 2 | ms24h_vencimento_hoje | D0 | 90% | PIX + Boleto |
| 3 | ms24h_boleto_vencido | D+1 | 60% | PIX + Boleto |
| 4 | ms24h_atraso_7dias | D+7 | 70% | PIX + Boleto |
| 5 | ms24h_atraso_15dias | D+15 | 40% | PIX + Boleto |
| 6 | ms24h_transbordo_21dias | D+21 | 90% | Nenhum |
| 7 | ms24h_pagamento_ok | Pagamento | 99% | Nenhum |

## Templates ANTIGOS a excluir (apos validacao):

| Nome Antigo | Motivo exclusao |
|---|---|
| fatura_lembrete_5dias | Substituido por ms24h_fatura_geracao |
| fatura_emissao | Nao esta mais na regua do Gustavo |
| cobranca_vencimento_hoje | Substituido por ms24h_vencimento_hoje |
| cobranca_atraso_5dias | Substituido por ms24h_atraso_7dias |
| boleto_atraso_10dias | Nao esta mais na regua do Gustavo (confirmar) |
| fatura_atraso_15dias | Substituido por ms24h_atraso_15dias |
| fatura_atraso_21dias | Substituido por ms24h_transbordo_21dias |
| aviso_pagamento_ok | Substituido por ms24h_pagamento_ok |

## Encoding (codificacao):

Todos os templates serao enviados com:
- Header HTTP: `Content-Type: application/json; charset=utf-8`
- Caracteres acentuados em unicode escapes no JSON:
  - a = \u00e1
  - e = \u00e9
  - i = \u00ed
  - o = \u00f3
  - u = \u00fa
  - a = \u00e3
  - o = \u00f5
  - c = \u00e7
  - A = \u00c1
  - U = \u00da
- Negritos com asteriscos: *texto em negrito*

---

# ORDEM DE EXECUCAO

1. **VOCE APROVA** os 7 templates acima
2. Eu **CRIO** os 7 novos no Meta (nomes ms24h_*)
3. **AGUARDO** aprovacao da Meta (minutos a horas)
4. **TESTO** enviando pro seu numero
5. Voce **VALIDA** as mensagens no WhatsApp
6. KLaOS **ATUALIZA** os steps da campanha para os novos nomes
7. **TESTA** campanha end-to-end
8. Apos tudo validado: **EXCLUO** os 8 templates antigos

---

# DECISOES TOMADAS

1. **D+10** - NAO esta no doc do Gustavo → REMOVIDO da regua. Template `boleto_atraso_10dias` sera excluido.
2. **Template 5 (D+15)** - Gustavo reescreveu e disse "MUDEI VAMOS TENTAR ASSIM" → Vamos arriscar com o texto dele.
3. **Template 3 (D+1)** - Gustavo manteve "CPF" → Vamos em frente.
4. **"Boleto Vencio"** → Corrigido para "Boleto Vencido" → OK.

---

**Status:** AGUARDANDO APROVACAO INTERNA
**NAO ENVIADO A META**
