# frozen_string_literal: true

# KLaOS — MACRO COM ENVIO SEQUENCIAL
#
# Problema (Blue Care, 04/08/2026, relatado pelo Ricardo): a macro `/Planos`
# entregava as IMAGENS TODAS NO FIM, depois de todos os textos. No sistema
# antigo deles a automacao esperava uma mensagem sair pra mandar a proxima.
#
# Causa: `Macros::ExecutionService#perform` cria as acoes em sequencia, mas o
# ENVIO e assincrono. E `Message#send_reply` (upstream, app/models/message.rb)
# atrasa DE PROPOSITO so quem tem anexo:
#
#   attachments.blank? ? SendReplyJob.perform_later(id)
#                      : SendReplyJob.set(wait: 2.seconds).perform_later(id)
#
# O comentario do upstream explica o motivo: o ActiveStorage so anexa o arquivo
# depois do commit, entao mandar na hora enviaria imagem vazia.
#
# Como a macro cria as 21 acoes em milissegundos, todos os textos entram na fila
# com wait=0 e todas as imagens com wait=2s. No aparelho do cliente isso vira
# "texto, texto, texto... e as fotos no final" — exatamente a queixa.
# Confirmado na conv 56: 20 mensagens criadas entre 18:50:09 e 18:50:14.
#
# Solucao: dar a cada acao da macro a SUA vez na fila, com espacamento
# crescente. A acao 1 sai em 0s, a 2 em 3s, a 3 em 6s, e assim por diante.
# Anexo nunca desce dos 2s do upstream (senao volta o bug do arquivo vazio).
#
# Isso resolve dois problemas de uma vez: a ordem passa a ser a que o Ricardo
# montou, e o cliente para de receber uma rajada de 21 mensagens de uma vez —
# rajada faz bloquear, e bloqueio derruba a qualidade do numero.
#
# Ajuste por conta (segundos entre uma mensagem e a proxima):
#   UPDATE accounts SET custom_attributes = custom_attributes ||
#     jsonb_build_object('klaos_macro_step_seconds', 4) WHERE id = 12;
# Sem configurar, usa 3s. Zero desliga o espacamento (volta ao padrao Chatwoot).

Rails.application.reloader.to_prepare do
  # Canal pra passar o atraso da acao atual ate o callback do Message.
  #
  # ATENCAO: `Current` aqui NAO e ActiveSupport::CurrentAttributes — e um
  # module simples com thread_mattr_accessor (lib/current.rb). Por isso
  # `attribute :foo` nao existe; tem que ser thread_mattr_accessor mesmo.
  # Como e por thread, o valor nao vaza entre requests/jobs concorrentes.
  unless Current.respond_to?(:klaos_macro_step_delay)
    Current.module_eval { thread_mattr_accessor :klaos_macro_step_delay }
  end

  module KlaosMacroSequencedSend
    # Só interfere quando a mensagem nasce DENTRO de uma macro; fora dela o
    # comportamento do Chatwoot fica intacto.
    def send_reply
      atraso = Current.klaos_macro_step_delay
      return super if atraso.blank? || atraso.to_i <= 0

      # Anexo precisa dos 2s do upstream no minimo — o arquivo so existe
      # depois do commit do ActiveStorage.
      espera = attachments.blank? ? atraso.to_i : [atraso.to_i, 2].max
      ::SendReplyJob.set(wait: espera.seconds).perform_later(id)
    end
  end

  module KlaosMacroSequencedExecution
    DEFAULT_STEP_SECONDS = 3

    # `send_message` e `send_attachment` sao private no upstream
    # (app/services/macros/execution_service.rb:23). Mantemos a mesma
    # visibilidade — o `perform` chama por `send`, que ignora isso de
    # qualquer forma.
    private

    def send_message(message)
      com_atraso_da_vez { super }
    end

    def send_attachment(blob_ids)
      com_atraso_da_vez { super }
    end

    # Cada mensagem/anexo da macro pega o proximo slot da fila. Contador e por
    # instancia do service, ou seja, por execucao de macro.
    def com_atraso_da_vez
      intervalo = klaos_step_seconds
      if intervalo <= 0
        yield
        return
      end

      @klaos_passo = @klaos_passo.to_i
      Current.klaos_macro_step_delay = @klaos_passo * intervalo
      @klaos_passo += 1
      yield
    ensure
      Current.klaos_macro_step_delay = nil
    end

    def klaos_step_seconds
      valor = @account&.custom_attributes&.dig('klaos_macro_step_seconds')
      return DEFAULT_STEP_SECONDS if valor.nil?

      valor.to_i
    rescue StandardError
      DEFAULT_STEP_SECONDS
    end
  end

  Message.prepend(KlaosMacroSequencedSend)
  Macros::ExecutionService.prepend(KlaosMacroSequencedExecution)
end
