# ANALISE DE TEMPLATES - Texto Exato do Cliente
## Revisao de Aprovacao Meta
### 08/04/2026 - NAO ENVIADO A META

---

# LEGENDA

- **% UTILITY** - Chance de ser aprovado como UTILITY (o que queremos)
- **% MARKETING** - Chance de ser reclassificado para MARKETING (custa 2x mais, NAO queremos)
- **% REJEICAO** - Chance de ser rejeitado completamente (nome bloqueado 30 dias)

Criterios da Meta para UTILITY:
- Deve ser sobre uma transacao existente (fatura, pedido, entrega)
- Tom informativo, nao persuasivo
- Sem linguagem de vendas ou retencao
- Sem pressao excessiva ou ameacas
- Sem capslock para enfase
- Dados transacionais presentes (valor, data, numero)

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

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 95% |
| % MARKETING | 5% |
| % REJEICAO | 0% |

## Riscos:
- Nenhum risco significativo
- Tom informativo, dados transacionais presentes
- "de preferencia" e casual mas nao e flag

## Veredicto: SEGURO PARA ENVIAR

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

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 75% |
| % MARKETING | 20% |
| % REJEICAO | 5% |

## Riscos:
- "VENCE HOJE" em capslock - Meta interpreta capslock como enfase/pressao. Templates UTILITY devem ter tom neutro. Capslock e um dos triggers mais comuns de reclassificacao para MARKETING.
- Risco principal: reclassificacao para MARKETING (20%) por causa do capslock.

## Recomendacao para manter UTILITY:
- Trocar "VENCE HOJE" por "vence hoje" → sobe para 95% UTILITY

## Veredicto: RISCO MEDIO - capslock pode reclassificar para MARKETING

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

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 55% |
| % MARKETING | 30% |
| % REJEICAO | 15% |

## Riscos:
- "Aviso de vencimento" como texto solto no body - nao e header, parece titulo de email marketing. Meta pode interpretar como MARKETING por causa do formato.
- "boleto registrado em seu CPF" - mencao a CPF. A Meta tem sensibilidade a dados pessoais. O sistema automatico de revisao pode flaggar "CPF" como dado pessoal e rejeitar ou reclassificar.
- "regularize seu debito" - aceitavel em UTILITY mas no limite. "Debito" e factual.
- Combinacao "Aviso de vencimento" + "CPF" + "regularize" acumula flags menores que juntas aumentam o risco.

## Recomendacao para manter UTILITY:
- Remover "Aviso de vencimento" do inicio → -10% risco MARKETING
- Remover "registrado em seu CPF" → -15% risco total
- Com ambas mudancas: sobe para 85% UTILITY

## Veredicto: RISCO ALTO - "CPF" + formato de titulo acumulam flags

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

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 70% |
| % MARKETING | 25% |
| % REJEICAO | 5% |

## Riscos:
- "venceu a 7 dias" - erro gramatical (correto: "ha 7 dias"). Nao causa rejeicao mas fica mal.
- "executar o titulo no SPC e em protesto" - SPC + protesto juntos. A Meta aceita avisos de consequencias em UTILITY quando sao factuais, mas o acumulo "SPC E protesto" em uma frase e mais agressivo que necessario. Risco de reclassificacao MARKETING por linguagem coerciva.
- Template atual aprovado como UTILITY tem texto similar ("executar o titulo em protesto" SEM "SPC"). Adicionar "SPC" aumenta o risco.

## Recomendacao para manter UTILITY:
- Corrigir "a 7 dias" para "ha 7 dias"
- Remover "no SPC e" deixando apenas "em protesto" → sobe para 90% UTILITY
- Alternativa: manter "SPC" mas sem "protesto" → 85% UTILITY

## Veredicto: RISCO MEDIO - "SPC e protesto" juntos podem reclassificar

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

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 5% |
| % MARKETING | 40% |
| % REJEICAO | 55% |

## Riscos CRITICOS (7 flags acumulados):

1. **"Bom dia"** - Saudacao temporal. Template pode ser enviado as 22h. Meta flagga como mensagem generica/MARKETING, nao transacional. (Flag leve)

2. **"seu CPF na lista de inadimplentes"** - Dois problemas:
   - CPF = dado pessoal sensivel (flag medio)
   - "lista de inadimplentes" = termo estigmatizante (flag alto)
   - Meta tem politica contra linguagem que estigmatiza ou envergonha o destinatario

3. **"Gostaria de saber se voce consegue fazer o pagamento"** - Tom conversacional/interativo. Templates UTILITY devem INFORMAR, nao PERGUNTAR. Pergunta interativa = MARKETING na visao da Meta. (Flag alto)

4. **"vamos perder acesso a sua conta"** - Ameaca de suspensao de servico. Na visao da Meta, isso e RETENCAO DE CLIENTE = MARKETING. Voce esta condicionando o servico ao pagamento. (Flag critico)

5. **"cartorio e cobrar taxa extrajudicial alem de SPC e Serasa"** - Acumulo de 4 ameacas em uma frase: cartorio + taxa extrajudicial + SPC + Serasa. Linguagem coerciva excessiva. (Flag critico)

6. **"gentileza encaminhar comprovante com urgencia!"** - Exclamacao + "urgencia" = pressao. (Flag medio)

7. **Sem {{1}} {{2}} {{3}}** - Nao tem nome do cliente, valor nem data no corpo. Sem dados transacionais, a Meta nao ve como transacao e sim como comunicacao generica. (Flag alto)

## Risco principal: REJEICAO COMPLETA (55%)
Este template acumula tantos flags que a chance de rejeicao e maior que a de aprovacao em qualquer categoria. Se rejeitado, o nome fica bloqueado 30 dias.

## Recomendacao para manter UTILITY:
Este texto precisa de reescrita significativa. Nao e possivel aprovar como UTILITY com ajustes menores. Seria necessario:
- Adicionar {{1}}, {{2}}, {{3}} (nome, valor, data)
- Remover "Bom dia"
- Remover "CPF na lista de inadimplentes"
- Remover pergunta conversacional
- Remover "perder acesso a conta"
- Reduzir ameacas para uma (so protesto OU so SPC, nao tudo junto)
- Remover exclamacao e "urgencia"
- Tom informativo em vez de conversacional

## Veredicto: NAO ENVIAR - risco altissimo de rejeicao + bloqueio de nome 30 dias

---

# TEMPLATE 6: 21 Dias Vencido - Transbordo Humano (D+21)
**Nome Meta:** `fatura_atraso_21dias`

## Texto Exato (Gustavo):

Ola {{1}}

Informamos que, devido a inadimplencia, seu titulo foi encaminhado ao cartorio de protesto e aos orgaos de protecao ao credito (SPC e Serasa). Para regularizar sua situacao e evitar restricoes no CPF, entre em contato com URGENCIA pelo WhatsApp ou telefone abaixo.

Telefone: (31) 98248-8131

Sem botoes (transbordo humano)

## Analise:

| Metrica | Valor |
|---|---|
| % UTILITY | 75% |
| % MARKETING | 20% |
| % REJEICAO | 5% |

## Riscos:
- "com URGENCIA" em capslock - mesmo problema do template 2. Capslock e trigger de reclassificacao MARKETING. Neste caso e mais arriscado porque combinado com "cartorio", "SPC", "Serasa" e "restricoes no CPF" na mesma mensagem.
- O template atual (ja aprovado) NAO tem "com URGENCIA" e foi aprovado como UTILITY.
- Adicionar "URGENCIA" em capslock aumenta o risco de reclassificacao.

## Recomendacao para manter UTILITY:
- Remover "com URGENCIA" ou trocar para "o mais breve possivel" → sobe para 90% UTILITY
- Manter texto identico ao aprovado atualmente → 95% UTILITY

## Veredicto: RISCO MEDIO - "URGENCIA" capslock pode reclassificar

---

# TABELA RESUMO

| # | Template | Dia | % UTILITY | % MARKETING | % REJEICAO | Acao |
|---|---|---|---|---|---|---|
| 1 | Geracao | D-5 | 95% | 5% | 0% | ENVIAR |
| 2 | Vencimento | D0 | 75% | 20% | 5% | AJUSTAR capslock |
| 3 | 1 dia vencido | D+1 | 55% | 30% | 15% | AJUSTAR "CPF" |
| 4 | 7 dias vencido | D+7 | 70% | 25% | 5% | AJUSTAR "SPC" |
| 5 | 15 dias vencido | D+15 | 5% | 40% | 55% | REESCREVER |
| 6 | 21 dias transbordo | D+21 | 75% | 20% | 5% | AJUSTAR capslock |

---

# IMPACTO NA REGUA

| Step | Atual | Gustavo propoe | Status |
|---|---|---|---|
| 1 | D-5 | D-5 | Igual |
| 2 | D0 (emissao) | D0 (vencimento) | Igual template, diferente trigger |
| 3 | D0 (vencimento) | D+1 (1 dia vencido) | NOVO template + step |
| 4 | D+5 | D+7 | Mudar offset no KLaOS |
| 5 | D+10 | Nao mencionado | CONFIRMAR com Gustavo |
| 6 | D+15 | D+15 | Igual (mas texto diferente) |
| 7 | D+21 | D+21 | Igual |

Perguntas pendentes para Gustavo:
- D+10: manter ou remover da regua?
- Template 5 (D+15): aceita reescrever para garantir UTILITY?
- Negritos: aceita que nao funcionam em templates WABA?

---

# NOTA SOBRE NEGRITOS

Templates WABA NAO suportam formatacao. Negritos com asteriscos (*texto*) aparecem como texto literal com asteriscos. Nao e possivel ter negrito em templates.

Formatacao so funciona em:
- Mensagens livres (dentro da janela de 24h)
- Respostas do AI Agent (mensagens livres, nao templates)

---

**Status:** ANALISE - NAO ENVIADO A META
**Proximo passo:** Validar com cliente, especialmente template 5
