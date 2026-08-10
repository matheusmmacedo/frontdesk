# frozen_string_literal: true

# SORTEIO DA CAIXA NÃO PEGA QUEM NÃO É DO TIME
#
# Gustavo, 10/08: "hoje eu percebi várias transferências assim aleatórias para o
# meu login, estou devolvendo para ela".
#
# Medido no mesmo dia, conta 9:
#
#   46  "Atribuído a X por I.A"        <- sorteio cego, sem time
#   12  "Atribuído a X via TIME por I.A" <- decisão de verdade
#   34  das 46 caíram no Gustavo
#    8  foram pra Ludiana, que deveria receber a maior parte
#    4  citam a Yasmin, que está de férias
#
# O QUE ACONTECE
#
# `AutoAssignmentHandler` roda quando a conversa vira `open` sem dono:
#
#   allowed_agent_ids = team_id.present? ? team_member_ids_with_capacity
#                                        : inbox.member_ids_with_assignment_capacity
#
# Sem `team_id`, o pool é a INBOX INTEIRA. Quem está online recebe, não importa
# o assunto nem o time. O Gustavo fica sempre online, então é sorteado o tempo
# todo — inclusive para conversa de plano e dependente, que é da Ludiana.
#
# Isso também atropela a assistente: ela lê a mensagem e decide o destino, mas o
# sorteio já gravou um dono segundos antes. O fix de 07/08 no KLaOS faz a decisão
# ganhar do sorteio quando ela existe; o problema aqui é o outro caso, quando não
# há decisão nenhuma e o sorteio decide sozinho.
#
# A REGRA
#
# Conversa SEM time não é sorteada. Ela fica sem dono até que alguém decida —
# a assistente, que roteia por assunto, ou um atendente que a pegue. Conversa
# COM time continua sorteando entre os membros daquele time, como sempre.
#
# Por que não é o mesmo que "desligar o auto-assignment": o rodízio de time
# segue intacto, e é ele que distribui o trabalho de verdade. O que sai é o
# sorteio cego, que hoje só cria retrabalho — o Gustavo recebe e devolve na mão.
#
# Conversa sem dono não some: aparece na caixa como não atribuída, e o
# `conversation_orphan_guard` continua cuidando das que ficam paradas.
#
# Desligável por conta: settings['klaos_sorteio_so_do_time'] = false.

module KlaosSorteioSoDoTime
  private

  def run_auto_assignment
    return super if team_id.present?
    return super unless KlaosSorteioSoDoTime.ativo?(account)

    Rails.logger.info(
      "[KlaosSorteioSoDoTime] conv #{id} sem time — sorteio da caixa não vai escolher dono"
    )
    nil
  end

  def self.ativo?(account)
    (account&.settings || {})['klaos_sorteio_so_do_time'] != false
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.ancestors.include?(KlaosSorteioSoDoTime)

  Conversation.prepend(KlaosSorteioSoDoTime)
  Rails.logger.info '[KlaosSorteioSoDoTime] prepended on Conversation'
end
