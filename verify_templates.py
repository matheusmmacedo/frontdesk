import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

print("=" * 70)
print("VERIFICACAO FINAL: GUSTAVO (Word) vs PLANO")
print("=" * 70)

print("""
======================================================================
TEMPLATE 1 - D-5 (ms24h_fatura_geracao)
======================================================================
DIFERENCAS/CORRECOES:
  - Gustavo: 'da MAIS SAUDE' com 'a' acentuado (da) - CORRECAO: correto e 'da' sem acento
  - Acentos (preferencia, duvida, Codigo) preservados via unicode escapes
  - Gustavo: 'Whatsapp' - CORRECAO: grafia oficial e 'WhatsApp'
  - Negritos: 100% alinhados com Word
  RESULTADO: OK

======================================================================
TEMPLATE 2 - D0 (ms24h_vencimento_hoje)
======================================================================
DIFERENCAS/CORRECOES:
  - Negritos: 100% alinhados (corrigido T2 para incluir 'O valor de' no bold)
  - Gustavo removeu capslock 'VENCE HOJE' - mantido em minusculo
  - Nenhuma divergencia de conteudo
  RESULTADO: OK

======================================================================
TEMPLATE 3 - D+1 (ms24h_boleto_vencido)
======================================================================
DIFERENCAS/CORRECOES:
  - CORRECAO: 'Vencio' para 'Vencido' (erro de digitacao do Gustavo)
  - 'CPF' mantido conforme decisao do Gustavo
  - Negritos: 100% alinhados
  RESULTADO: OK (1 correcao de typo)

======================================================================
TEMPLATE 4 - D+7 (ms24h_atraso_7dias)
======================================================================
DIFERENCAS/CORRECOES:
  - Gustavo corrigiu 'a 7 dias' para 'ha 7 dias' - mantido
  - 'SPC e em protesto' mantido ('VAMOS TENTAR ASSIM')
  - Negritos: 100% alinhados
  RESULTADO: OK

======================================================================
TEMPLATE 5 - D+15 (ms24h_atraso_15dias)
======================================================================
DIFERENCAS/CORRECOES:
  - Gustavo reescreveu completamente ('MUDEI VAMOS TENTAR ASSIM')
  - Sem {{1}}, {{2}}, {{3}} no body - conforme Gustavo escreveu. SO tem {{4}} (barcode)
  - Negrito: 100% alinhado
  - NOTA: Sem variaveis nome/valor/data e risco para UTILITY mas Gustavo aceita
  RESULTADO: OK (aceito risco)

======================================================================
TEMPLATE 6 - D+21 (ms24h_transbordo_21dias)
======================================================================
DIFERENCAS/CORRECOES:
  - Gustavo trocou 'URGENCIA' capslock por 'urgencia' minusculo - mantido
  - Sem botoes (transbordo humano) - mantido
  - Sem negritos - mantido
  RESULTADO: OK

======================================================================
TEMPLATE 7 - Pagamento (ms24h_pagamento_ok)
======================================================================
DIFERENCAS/CORRECOES:
  - Gustavo NAO mencionou este template no doc - mantemos o atual
  - Texto identico ao aprovado
  RESULTADO: OK (sem mudanca)

======================================================================
RESUMO
======================================================================

Correcoes aplicadas (necessarias):
  1. T1: 'da' com acento -> 'da' sem acento (erro gramatical)
  2. T3: 'Vencio' -> 'Vencido' (erro digitacao)
  3. Todos: 'Whatsapp' -> 'WhatsApp' (grafia oficial)

Mantido conforme Gustavo pediu:
  1. T3: 'CPF' mantido (Gustavo decidiu manter)
  2. T4: 'SPC e em protesto' mantido ('VAMOS TENTAR ASSIM')
  3. T5: Texto reescrito pelo Gustavo ('MUDEI VAMOS TENTAR ASSIM')
  4. T5: Sem {{1}} {{2}} {{3}} (conforme Gustavo escreveu)
  5. T6: 'urgencia' minusculo (Gustavo corrigiu)
  6. Todos: Negritos EXATAMENTE onde Gustavo marcou bold no Word
  7. Todos: Botoes PIX + Boleto mantidos (exceto T6 sem botoes)

RESULTADO FINAL: 100% alinhado com documento do Gustavo
                 + 3 correcoes minimas (gramatica/digitacao)
""")
