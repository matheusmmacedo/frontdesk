# ANALISE DE TEMPLATES - Texto Exato do Cliente
## Revisao de Aprovacao Meta (UTILITY)
### 08/04/2026 - NAO ENVIADO A META

---

# TEMPLATE 1: Geracao do Boleto (D-5)
**Nome Meta:** `fatura_lembrete_5dias`

## Texto Exato (Gustavo):

Ola {{1}}!
Informamos que sua fatura da MAIS SAUDE 24 HORAS, no valor de {{2}} vence em 5 dias, no dia {{3}}.

Realize o pagamento de preferencia antes do vencimento para evitar multas e juros.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

Botoes: [Pagar via PIX] [Ver Boleto (PDF)]

## Chance de Aprovacao UTILITY: 95%

## Riscos:
- Nenhum risco significativo. Texto transacional, tom educado, dados da fatura.

---

# TEMPLATE 2: Dia do Vencimento (D0)
**Nome Meta:** `cobranca_vencimento_hoje`

## Texto Exato (Gustavo):

Ola {{1}}!
Sua fatura da MAIS SAUDE 24 HORAS VENCE HOJE dia {{3}}. O valor de {{2}}.

Realize o pagamento antes do vencimento para evitar multas e juros.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

Botoes: [Pagar via PIX] [Ver Boleto (PDF)]

## Chance de Aprovacao UTILITY: 85%

## Riscos:
- "VENCE HOJE" em capslock pode ser interpretado como pressao pela Meta. Risco baixo-medio.
- Recomendacao: trocar para "vence hoje" minusculo sobe para 95%.

---

# TEMPLATE 3: 1 Dia Vencido (D+1)
**Nome Meta:** NOVO - sugestao: `aviso_boleto_vencido`

## Texto Exato (Gustavo):

Aviso de vencimento

Ola {{1}}!

Queremos te avisar que o boleto registrado em seu CPF venceu dia {{3}} gerado pela MAIS SAUDE 24 HORAS, no valor de {{2}}.

Realize o pagamento e regularize seu debito.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

Botoes: [Pagar via PIX] [Ver Boleto (PDF)]

## Chance de Aprovacao UTILITY: 65%

## Riscos:
- "Aviso de vencimento" como texto solto no inicio do body pode confundir o parser da Meta (nao e header, e body text). Risco medio.
- "boleto registrado em seu CPF" - mencao direta a CPF como dado pessoal pode ser flaggado pela revisao automatica da Meta. Risco medio-alto.
- "regularize seu debito" - linguagem aceitavel mas no limite.
- Recomendacao: remover "registrado em seu CPF" sobe para 85%. Remover "Aviso de vencimento" do inicio sobe para 90%.

---

# TEMPLATE 4: 7 Dias Vencido (D+7)
**Nome Meta:** `cobranca_atraso_5dias` (reutilizar, mudar step no KLaOS)

## Texto Exato (Gustavo):

Ola {{1}}!
Queremos te lembrar que a cobranca gerada pela MAIS SAUDE 24 HORAS, no valor de {{2}} venceu a 7 dias, no dia {{3}}.

Lembrando que o boleto e registrado no banco e com a falta do pagamento o banco pode executar o titulo no SPC e em protesto.

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

Botoes: [Pagar via PIX] [Ver Boleto (PDF)]

## Chance de Aprovacao UTILITY: 80%

## Riscos:
- "venceu a 7 dias" - erro gramatical (correto: "ha 7 dias"). Meta nao rejeita por gramatica mas fica mal pro cliente.
- "executar o titulo no SPC e em protesto" - mencao a SPC + protesto juntos e linguagem forte. Risco medio. Meta geralmente aceita como aviso factual em UTILITY.
- Recomendacao: corrigir "a 7 dias" para "ha 7 dias" e remover "no SPC e" deixando so "em protesto" sobe para 90%.

---

# TEMPLATE 5: 15 Dias Vencido (D+15)
**Nome Meta:** `fatura_atraso_15dias`

## Texto Exato (Gustavo):

Bom dia

Recebemos hoje um relatorio do banco onde consta o seu CPF na lista de inadimplentes e ultrapassou o prazo permitido para pagamento.

Gostaria de saber se voce consegue fazer o pagamento hoje ainda e enviar o comprovante?

Caso contrario o nosso sistema ira atualizar e vamos perder acesso a sua conta.

Se isso acontecer o banco vai executar o titulo no cartorio e cobrar taxa extrajudicial alem de SPC e Serasa.

Para isso nao acontecer gentileza encaminhar comprovante com urgencia!

Codigo de barras do boleto:
{{4}}

Caso tenha alguma duvida entre em contato neste Whatsapp
Telefone: (31) 98248-8131
Email: adm@atendmedbh.com.br

Botoes: [Pagar via PIX] [Ver Boleto (PDF)]

## Chance de Aprovacao UTILITY: 20%

## Riscos:
- "Bom dia" - saudacao temporal em template que pode ser enviado a qualquer hora. Flag leve.
- "seu CPF na lista de inadimplentes" - dado pessoal sensivel (CPF) + termo estigmatizante (inadimplentes). Flag alto.
- "Gostaria de saber se voce consegue" - tom conversacional/interativo. Templates UTILITY devem ser informativos, nao conversacionais. Meta pode reclassificar como MARKETING.
- "vamos perder acesso a sua conta" - ameaca de suspensao de servico. Meta pode interpretar como retencao = MARKETING.
- "o banco vai executar o titulo no cartorio e cobrar taxa extrajudicial alem de SPC e Serasa" - acumulo de ameacas (cartorio + extrajudicial + SPC + Serasa) em uma frase. Flag alto por linguagem coerciva.
- "gentileza encaminhar comprovante com urgencia!" - exclamacao + urgencia. Pressao.
- Sem nome do cliente {{1}} - nao personaliza. Meta prefere templates personalizados.
- Sem valor {{2}} nem data {{3}} - nao tem dados transacionais basicos.
- RISCO PRINCIPAL: Acumulo de flags. Cada um isolado seria risco medio, mas juntos o risco e muito alto de rejeicao ou reclassificacao para MARKETING.

---

# TEMPLATE 6: 21 Dias Vencido - Transbordo Humano (D+21)
**Nome Meta:** `fatura_atraso_21dias`

## Texto Exato (Gustavo):

Ola {{1}}

Informamos que, devido a inadimplencia, seu titulo foi encaminhado ao cartorio de protesto e aos orgaos de protecao ao credito (SPC e Serasa). Para regularizar sua situacao e evitar restricoes no CPF, entre em contato com URGENCIA pelo WhatsApp ou telefone abaixo.

Telefone: (31) 98248-8131

Sem botoes (transbordo humano)

## Chance de Aprovacao UTILITY: 85%

## Riscos:
- "com URGENCIA" em capslock - pode ser visto como pressao. Risco baixo-medio.
- Conteudo factual sobre protesto/SPC e aceitavel em UTILITY.
- Recomendacao: trocar "com URGENCIA" para "o mais breve possivel" sobe para 95%.

---

# RESUMO DE APROVACAO

| # | Template | Texto | % Aprovacao | Acao |
|---|---|---|---|---|
| 1 | D-5 Geracao | Conforme Gustavo | 95% | Aprovar - enviar como esta |
| 2 | D0 Vencimento | Conforme Gustavo | 85% | Aprovar com ressalva (VENCE HOJE capslock) |
| 3 | D+1 Vencido | Conforme Gustavo | 65% | Risco medio - "CPF" pode causar rejeicao |
| 4 | D+7 Vencido | Conforme Gustavo | 80% | Aprovar com ressalva (SPC + gramatica) |
| 5 | D+15 Vencido | Conforme Gustavo | 20% | ALTO RISCO - multiplas flags, provavel rejeicao |
| 6 | D+21 Transbordo | Conforme Gustavo | 85% | Aprovar com ressalva (URGENCIA capslock) |

---

# ALERTAS IMPORTANTES

## Template 5 (D+15) - ALTO RISCO
Este template tem 20% de chance de aprovacao UTILITY. Se rejeitado, o nome fica bloqueado por 30 dias no Meta. Recomendacao forte: ajustar antes de enviar.

## Template 3 (D+1) - TEMPLATE NOVO
Nao existe no Meta hoje. Precisa criar. Nome sugerido: `aviso_boleto_vencido`. Apos criar, precisa adicionar step D+1 no KLaOS.

## Negritos
Templates WABA nao suportam formatacao (negrito/italico). Asteriscos aparecem como texto literal. Os negritos que o Gustavo pediu NAO funcionam em templates.

## Mudanca na Regua
Gustavo propoe regua diferente da atual. Confirmar se quer:
- Adicionar D+1 (novo)
- Mudar D+5 para D+7
- Manter ou remover D+10

---

**Status:** ANALISE - NAO ENVIADO A META
**Proximo passo:** Aprovar com cliente antes de enviar
