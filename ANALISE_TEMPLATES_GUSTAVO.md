# ANALISE DE TEMPLATES - Solicitacao do Cliente Gustavo
## Revisao antes de enviar a Meta
### Data: 08/04/2026

---

# COMO LER ESTE DOCUMENTO

Para cada template:
- **MENSAGEM ORIGINAL** - Texto exato que o Gustavo pediu
- **PROBLEMAS IDENTIFICADOS** - O que pode causar rejeicao na Meta
- **% APROVACAO UTILITY** - Chance estimada de aprovacao como UTILITY
- **MENSAGEM SUGERIDA** - Versao corrigida para maximizar aprovacao
- **STATUS** - Se a sugerida deve ser aprovada ou nao

**Regras da Meta para UTILITY:**
- Deve ser transacional (relacionada a uma transacao existente)
- NAO pode ser promocional ou de vendas
- NAO pode conter linguagem ameacadora ou coerciva excessiva
- Pode conter dados da transacao (valor, data, links)
- Formatacao: negrito com asteriscos nao funciona em templates (so no chat livre)
- Variaveis devem ser claramente transacionais

---

# TEMPLATE 1: Geracao do Boleto (D-5)
**Template atual no Meta:** `fatura_lembrete_5dias`

## Mensagem Original (Gustavo):
```
Ola Gustavo Oliveira!
Informamos que sua fatura da MAIS SAUDE 24 HORAS, no valor de R$ 94,90 vence em 5 dias, no dia 13/04/2026.

Realize o pagamento de preferencia antes do vencimento para evitar multas e juros.

Clique no botao PIX copia e cola:
(botao)

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br
```

## Problemas Identificados:
1. **Negritos com asteriscos** - Templates WABA nao suportam markdown/negrito no body. Os asteriscos serao enviados como texto literal (*assim*). Negrito so funciona em mensagens livres (fora de template).
2. **"Clique no botao PIX copia e cola"** - Texto redundante. O botao ja tem label "Pagar via PIX". Nao precisa explicar no body que existe um botao.
3. **"de preferencia"** - Linguagem casual, mas aceitavel para UTILITY.
4. **Sem codigo de barras** - O Gustavo quer manter botao PIX + botao boleto, mas tambem tinhamos o codigo de barras no body. Ele nao mencionou remover, mas tambem nao mencionou manter.

## % Aprovacao UTILITY: 90%
O conteudo e transacional (aviso de vencimento). Risco baixo. Unico problema real e a formatacao de negritos que nao funciona.

## Mensagem Sugerida:
```
Ola {{1}}!
Informamos que sua fatura da MAIS SAUDE 24 HORAS, no valor de {{2}} vence em 5 dias, no dia {{3}}.

Realize o pagamento antes do vencimento para evitar multas e juros.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida, entre em contato neste WhatsApp.
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

[Botao 1: Pagar via PIX]
[Botao 2: Ver Boleto (PDF)]
```

## Mudancas em relacao ao original:
- Removidos negritos (nao funcionam em template)
- Removido "Clique no botao PIX copia e cola" (redundante com o botao)
- Adicionado "de preferencia" removido (mais direto)
- Mantido codigo de barras {{4}} no body
- Botoes mantidos como ja aprovados

## STATUS: JA APROVADO (template atual `fatura_lembrete_5dias` ja esta assim)

---

# TEMPLATE 2: Dia do Vencimento (D0)
**Template atual no Meta:** `cobranca_vencimento_hoje`

## Mensagem Original (Gustavo):
```
Ola Gustavo Oliveira!
Sua fatura da MAIS SAUDE 24 HORAS VENCE HOJE dia 08/04/2026. O valor de R$ 94,90

Realize o pagamento antes do vencimento para evitar multas e juros
```

## Problemas Identificados:
1. **"VENCE HOJE" em capslock** - Templates nao suportam formatacao. Capslock intencional pode ser visto como agressivo pela Meta. Em templates, tudo e texto plano.
2. **Frase cortada** - "O valor de R$ 94,90" termina sem ponto final nem continuacao. Parece incompleto.
3. **Sem codigo de barras** - Nao inclui o {{4}} do boleto.
4. **Sem contato** - Nao tem telefone/email para duvidas.
5. **Negritos** - Mesmo problema, nao funcionam.

## % Aprovacao UTILITY: 85%
Conteudo transacional OK. O capslock "VENCE HOJE" pode ser flag mas provavelmente passa. Maior risco e o texto parecer incompleto.

## Mensagem Sugerida:
```
Ola {{1}}!
Sua fatura da MAIS SAUDE 24 HORAS vence hoje, dia {{3}}. O valor e de {{2}}.

Realize o pagamento hoje para evitar multas e juros.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida, entre em contato neste WhatsApp.
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

[Botao 1: Pagar via PIX]
[Botao 2: Ver Boleto (PDF)]
```

## Mudancas em relacao ao original:
- "VENCE HOJE" em minusculo (evita flag da Meta)
- Frase do valor completada ("O valor e de")
- Adicionado codigo de barras
- Adicionado contato (padrao pedido pelo Gustavo)
- Removidos negritos

## STATUS: PRECISA EDITAR (template atual ja esta proximo, mas o texto do Gustavo e diferente do aprovado)

---

# TEMPLATE 3: 1 Dia Vencido (D+1)
**Template atual no Meta:** NAO EXISTE

## Mensagem Original (Gustavo):
```
Aviso de vencimento
Ola Gustavo Oliveira!

Queremos te avisar que o boleto registrado em seu CPF venceu dia 07/04/2026 gerado pela MAIS SAUDE 24 HORAS, no valor de R$ 94,90

Realize o pagamento e regularize seu debito
```

## Problemas Identificados:
1. **TEMPLATE NAO EXISTE** - Hoje temos D+5 mas nao D+1. Seria um template NOVO a criar.
2. **"Aviso de vencimento" como titulo** - Templates WABA nao tem titulo separado no body. Teria que ser parte do texto ou usar HEADER component.
3. **"boleto registrado em seu CPF"** - Mencao a CPF pode ser sensivel. Meta pode flaggar como dado pessoal. Melhor remover.
4. **Negritos** - Mesmo problema.
5. **Muda a regua** - Hoje a regua e: D-5, D0, D+5, D+10, D+15, D+21. Adicionar D+1 muda a sequencia inteira. Impacta o KLaOS collectionEngine.

## % Aprovacao UTILITY: 80%
Transacional OK. Risco medio pela mencao a CPF e pela frase "regularize seu debito" (pode ser vista como pressao). Mas deve passar como UTILITY.

## Mensagem Sugerida:
```
Ola {{1}}!
Queremos te avisar que o boleto da MAIS SAUDE 24 HORAS no valor de {{2}} venceu no dia {{3}}.

Realize o pagamento e regularize sua situacao.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida, entre em contato neste WhatsApp.
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

[Botao 1: Pagar via PIX]
[Botao 2: Ver Boleto (PDF)]
```

## Mudancas em relacao ao original:
- Removido "Aviso de vencimento" como titulo (nao funciona em template body)
- Removido "registrado em seu CPF" (dado sensivel, risco de rejeicao)
- "regularize seu debito" → "regularize sua situacao" (menos agressivo)
- Adicionado codigo de barras e contato (padrao)
- Removidos negritos

## STATUS: TEMPLATE NOVO - Precisa criar no Meta + adicionar step D+1 no KLaOS

## IMPACTO NA REGUA:
Nova regua seria: D-5, D0, D+1, D+7, D+15, D+21 (6 steps, mudou D+5 pra D+1 e D+10 pra D+7)

---

# TEMPLATE 4: 7 Dias Vencido (D+7)
**Template atual no Meta:** `cobranca_atraso_5dias` (era D+5, agora seria D+7)

## Mensagem Original (Gustavo):
```
Ola Gustavo Oliveira!
Queremos te lembrar que a cobranca gerada pela MAIS SAUDE 24 HORAS, no valor de R$ 94,90 venceu a 7 dias, no dia 01/04/2026.

Lembrando que o boleto e registrado no banco e com a falta do pagamento o banco pode executar o titulo no SPC e em protesto.
```

## Problemas Identificados:
1. **"venceu a 7 dias"** - Erro gramatical: correto e "venceu ha 7 dias" (com acento). Meta nao rejeita por gramatica, mas fica mal.
2. **"executar o titulo no SPC e em protesto"** - Linguagem forte. UTILITY permite avisos de consequencias financeiras, mas "SPC e protesto" junto pode ser flag. Risco medio.
3. **Negritos** - Mesmo problema.
4. **Mudanca de D+5 para D+7** - O template `cobranca_atraso_5dias` existe como D+5. Se quiser D+7, pode reutilizar o mesmo template (so muda o step no KLaOS) ou criar novo.

## % Aprovacao UTILITY: 85%
Aviso de consequencias financeiras e aceitavel em UTILITY se for factual. "SPC e protesto" e factual. Risco e se a Meta interpretar como ameaca.

## Mensagem Sugerida:
```
Ola {{1}}!
Queremos te lembrar que a cobranca gerada pela MAIS SAUDE 24 HORAS, no valor de {{2}} venceu no dia {{3}}.

Lembrando que o boleto e registrado no banco e com a falta do pagamento o banco pode executar o titulo em protesto.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida, entre em contato neste WhatsApp.
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

[Botao 1: Pagar via PIX]
[Botao 2: Ver Boleto (PDF)]
```

## Mudancas em relacao ao original:
- Removido "a 7 dias" (a data ja informa quando venceu)
- Removido "no SPC e" - deixar apenas "protesto" (menos agressivo, maior chance de aprovacao)
- Adicionado codigo de barras e contato
- Removidos negritos

## STATUS: JA APROVADO (template `cobranca_atraso_5dias` ja tem texto muito proximo)

## NOTA: O KLaOS so precisa mudar o step de D+5 para D+7 na campanha. Nao precisa criar template novo.

---

# TEMPLATE 5: 15 Dias Vencido (D+15)
**Template atual no Meta:** `fatura_atraso_15dias`

## Mensagem Original (Gustavo):
```
Bom dia
Recebemos hoje um relatorio do banco onde conta o seu CPF na lista de inadimplentes e ultrapassou o prazo permitido para pagamento

Gostaria de saber se voce consegue fazer o pagamento hoje ainda e enviar o comprovante?

Caso contrario o nosso sistema ira atualizar e vamos perder acesso a sua conta

se isso acontecer o banco vai executar o titulo no cartorio e cobrar taxa extrajudicial alem de SPC e Serasa

para isso nao acontecer gentileza encaminhar comprovante com urgencia!
```

## Problemas Identificados:
1. **ALTO RISCO DE REJEICAO** - Esta mensagem tem multiplos problemas graves:
2. **"seu CPF na lista de inadimplentes"** - Mencao direta a CPF + inadimplencia. Meta pode rejeitar como dado pessoal sensivel + linguagem coerciva.
3. **"vamos perder acesso a sua conta"** - Ameaca de suspensao. Meta pode classificar como MARKETING (retencao) em vez de UTILITY.
4. **"taxa extrajudicial alem de SPC e Serasa"** - Multiplas ameacas em sequencia. Risco alto de flag por linguagem coerciva.
5. **"gentileza encaminhar comprovante com urgencia!"** - Exclamacao + urgencia. Pode ser visto como pressao.
6. **"Bom dia" como abertura** - Templates WABA nao devem ter saudacao generica temporal (pode ser enviado a noite).
7. **Sem nome do cliente** - Nao usa {{1}} para personalizar.
8. **Tom conversacional** - "Gostaria de saber se voce consegue" soa como chat, nao como aviso transacional. Meta pode rejeitar.
9. **Negritos** - Mesmo problema.

## % Aprovacao UTILITY: 30%
RISCO ALTO de rejeicao. Multiplas flags: CPF, lista de inadimplentes, ameacas de SPC/Serasa/cartorio/extrajudicial, urgencia, tom conversacional. A Meta provavelmente rejeitaria ou reclassificaria como MARKETING.

## Mensagem Sugerida:
```
Ola {{1}}!
O seu boleto da MAIS SAUDE 24 HORAS ultrapassou o prazo permitido e sera executado. Realize o pagamento hoje e envie uma copia do comprovante com urgencia para evitar protesto e cobrancas extrajudiciais.

Valor de {{2}} venceu no dia {{3}}.

Lembrando que o boleto e registrado no banco e com a falta do pagamento o banco pode executar o titulo em protesto juntamente com SPC e Serasa.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida, entre em contato neste WhatsApp.
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

[Botao 1: Pagar via PIX]
[Botao 2: Ver Boleto (PDF)]
```

## Mudancas em relacao ao original:
- Removido "Bom dia" (nao adequado pra template que pode ser enviado a qualquer hora)
- Removido "seu CPF na lista de inadimplentes" (dado sensivel)
- Removido "vamos perder acesso a sua conta" (ameaca de retencao = MARKETING)
- Removido "Gostaria de saber se voce consegue" (tom conversacional)
- Mantido aviso de protesto/SPC/Serasa em tom factual (nao como ameaca)
- Adicionado nome do cliente {{1}}
- Adicionado codigo de barras e contato

## STATUS: JA APROVADO (template `fatura_atraso_15dias` atual ja tem texto equivalente aprovado)

---

# TEMPLATE 6: 21 Dias Vencido - Transbordo Humano (D+21)
**Template atual no Meta:** `fatura_atraso_21dias`

## Mensagem Original (Gustavo):
```
Ola Gustavo Oliveira

Informamos que, devido a inadimplencia, seu titulo foi encaminhado ao cartorio de protesto e aos orgaos de protecao ao credito (SPC e Serasa). Para regularizar sua situacao e evitar restricoes no CPF, entre em contato com URGENCIA pelo WhatsApp ou telefone abaixo.

Telefone: (31) 98248-8131
```

## Problemas Identificados:
1. **"URGENCIA" em capslock** - Pode ser visto como pressao. Melhor em minusculo.
2. **"restricoes no CPF"** - Mencao a CPF pode ser flag, mas neste contexto e factual (SPC realmente restringe CPF).
3. **Conteudo geral** - O texto e forte mas factual. UTILITY permite avisos de consequencias reais.

## % Aprovacao UTILITY: 90%
Template ja esta aprovado no Meta com texto quase identico. A versao do Gustavo adiciona apenas "com URGENCIA" que nao deve causar rejeicao se em minusculo.

## Mensagem Sugerida:
```
Ola {{1}}

Informamos que, devido a inadimplencia, seu titulo foi encaminhado ao cartorio de protesto e aos orgaos de protecao ao credito (SPC e Serasa). Para regularizar sua situacao e evitar restricoes no CPF, entre em contato pelo WhatsApp ou telefone abaixo.

Telefone: (31) 98248-8131
```

## Mudancas em relacao ao original:
- Removido "com URGENCIA" em capslock (risco desnecessario)
- Resto mantido identico (ja aprovado)

## STATUS: JA APROVADO (template `fatura_atraso_21dias` ja esta assim)

---

# RESUMO GERAL

| # | Template | % Aprovacao Original | Acao Necessaria | Template Meta |
|---|---|---|---|---|
| 1 | D-5 Geracao | 90% | Nenhuma (ja aprovado) | `fatura_lembrete_5dias` |
| 2 | D0 Vencimento | 85% | Ajustar texto (minor) | `cobranca_vencimento_hoje` |
| 3 | D+1 Vencido | 80% | CRIAR TEMPLATE NOVO | Nao existe |
| 4 | D+7 Vencido | 85% | Nenhuma (reutilizar D+5) | `cobranca_atraso_5dias` |
| 5 | D+15 Vencido | 30% | REESCREVER (alto risco) | `fatura_atraso_15dias` |
| 6 | D+21 Transbordo | 90% | Nenhuma (ja aprovado) | `fatura_atraso_21dias` |

---

# MUDANCA NA REGUA DE COBRANCA

O Gustavo esta propondo uma regua diferente da atual:

| Step | Regua Atual | Regua Gustavo | Template |
|---|---|---|---|
| 1 | D-5 (5 dias antes) | D-5 (geracao) | `fatura_lembrete_5dias` |
| 2 | D0 (emissao) | D0 (vencimento) | `fatura_emissao` ou `cobranca_vencimento_hoje` |
| 3 | D0 (vencimento) | D+1 (1 dia vencido) | NOVO - criar |
| 4 | D+5 | D+7 | `cobranca_atraso_5dias` (mudar step pra 7) |
| 5 | D+10 | - | `boleto_atraso_10dias` (REMOVER da regua?) |
| 6 | D+15 | D+15 | `fatura_atraso_15dias` |
| 7 | D+21 (transbordo) | D+21 (transbordo) | `fatura_atraso_21dias` |

**Pontos de atencao:**
- Gustavo NAO mencionou D+10. Pode querer remover ou manter.
- Gustavo mudou D+5 para D+7
- Gustavo adicionou D+1 (novo)
- Gustavo removeu o step de emissao (D0 enrollment) - agora D0 e so vencimento

**Recomendacao:** Confirmar com Gustavo se quer manter D+10 ou remover.

---

# OBSERVACAO SOBRE NEGRITOS

O Gustavo pediu negritos nas mensagens. Importante esclarecer:

**Templates WABA:** NAO suportam formatacao (negrito, italico, etc). O texto e enviado como plain text. Asteriscos aparecem como caracteres literais (*assim*).

**Mensagens livres (dentro da janela de 24h):** Suportam formatacao WhatsApp:
- *negrito* com asteriscos
- _italico_ com underline
- ~tachado~ com til

**Conclusao:** Os negritos que o Gustavo quer SO funcionam se o AI Agent responder com mensagem livre (nao template). Nos templates, nao e possivel.

---

# OBSERVACAO SOBRE O BOTAO "PIX COPIA E COLA"

O Gustavo pede: "Clique no botao PIX copia e cola"

O que temos hoje:
- **Botao "Pagar via PIX"** → abre a pagina app.klaos.ai/pay/{code} onde o cliente ve o QR code PIX e pode copiar o codigo
- **Botao "Ver Boleto (PDF)"** → abre o PDF do boleto

O botao NAO copia o PIX automaticamente. Ele ABRE uma pagina onde o cliente pode copiar. O nome "PIX copia e cola" pode confundir o cliente. Sugestao: manter como "Pagar via PIX" que e mais claro.

---

**Documento criado por:** KLaOS Team
**Data:** 08/04/2026
**Status:** ANALISE - NAO ENVIADO A META
