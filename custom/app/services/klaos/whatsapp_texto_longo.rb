# frozen_string_literal: true

# KLaOS — TEXTO LONGO NO WHATSAPP CLOUD VIRA VARIAS MENSAGENS, NA ORDEM
#
# Pedido do Gustavo (Blue Care, 26/10/2026): as respostas prontas de
# cancelamento de contrato tem de 4589 a 7009 caracteres e o composer travava
# o Enviar com "536 characters over". O limite e da Meta: `text.body` aceita no
# maximo 4096 caracteres (developers.facebook.com/docs/whatsapp/cloud-api/
# messages/text-messages). No sistema anterior (Qualizap) a mensagem saia
# inteira, em partes.
#
# Aqui fica so a regra pura (sem Rails), pra ser testada isolada:
#   - quando dividir: tamanho do texto + reserva do prefixo passa de 4096;
#   - como dividir: blocos de no maximo 3900, quebrando em paragrafo ("\n\n"),
#     depois linha ("\n"), depois espaco; a 1a parte guarda espaco pro prefixo
#     "**Atendente NOME:**\n" que o human_message_prefix.rb poe no before_create.
#
# O tamanho e contado em unidades UTF-16, igual ao `String#length` do JS que o
# contador do composer usa (emoji fora do BMP conta 2). O front tem o espelho
# desta regra em app/javascript/dashboard/helper/klaosTextoLongo.js; os numeros
# precisam ser os mesmos dos dois lados.
#
# Quem cria as N mensagens e quem garante a ordem de envio:
#   custom/config/initializers/klaos_whatsapp_texto_longo.rb
module Klaos
  module WhatsappTextoLongo
    LIMITE_META = 4096
    # Teto de cada parte. A folga ate 4096 cobre a conversao markdown -> WhatsApp
    # feita no envio (Messages::MarkdownRendererService).
    LIMITE_PARTE = 3900
    # Espaco guardado na 1a parte pro prefixo do atendente. Se o prefixo real
    # for maior, a reserva cresce junto (ver #reserva_para).
    RESERVA_PREFIXO = 100
    # Segundos entre a Meta aceitar uma parte e a proxima ir pra fila.
    ESPERA_ENTRE_PARTES = 2
    # Chave em content_attributes que marca cada parte:
    #   { 'grupo' => uuid, 'parte' => 1..N, 'total' => N, 'liberada' => bool }
    CHAVE = 'klaos_texto_longo'

    SEPARADORES = ["\n\n", "\n", ' '].freeze

    module_function

    # Tamanho em unidades UTF-16 (o mesmo numero que o `message.length` do JS).
    def tamanho(texto)
      texto.to_s.each_char.sum { |c| c.ord > 0xFFFF ? 2 : 1 }
    end

    def reserva_para(prefixo)
      [RESERVA_PREFIXO, tamanho(prefixo)].max
    end

    def precisa_dividir?(texto, reserva = RESERVA_PREFIXO)
      tamanho(texto) + reserva > LIMITE_META
    end

    # Devolve as partes, na ordem. Texto que cabe volta como [texto], intacto.
    def dividir(texto, reserva = RESERVA_PREFIXO)
      resto = texto.to_s
      return [resto] unless precisa_dividir?(resto, reserva)

      partes = []
      limite = LIMITE_PARTE - reserva
      while tamanho(resto) > limite
        corte, pulo = ponto_de_corte(resto, limite)
        parte = resto[0...corte].rstrip
        partes << parte unless parte.empty?
        resto = resto[(corte + pulo)..].to_s.sub(/\A\s+/, '')
        limite = LIMITE_PARTE
      end
      partes << resto unless resto.empty?
      partes
    end

    # Onde cortar: o ultimo paragrafo que cabe; senao a ultima linha; senao o
    # ultimo espaco. So aceita um separador da metade do bloco pra frente, pra
    # nao gerar partes minusculas. Sem nenhum, corta seco no limite (o indice e
    # por caractere, entao nunca parte um emoji ao meio).
    def ponto_de_corte(texto, limite)
      cabe = 0
      usado = 0
      texto.each_char do |c|
        peso = c.ord > 0xFFFF ? 2 : 1
        break if usado + peso > limite

        usado += peso
        cabe += 1
      end

      janela = texto[0...cabe]
      minimo = cabe / 2
      SEPARADORES.each do |sep|
        i = janela.rindex(sep)
        return [i, sep.length] if i && i >= minimo && i.positive?
      end
      [cabe, 0]
    end
  end
end
