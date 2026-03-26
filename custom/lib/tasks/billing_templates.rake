# frozen_string_literal: true

# Rake tasks to create/update Meta WhatsApp message templates
# for the Mais Saude 24h billing flow.
#
# Usage:
#   rake billing_templates:sync CONNECTION_ID=<whatsapp_connection_id>

namespace :billing_templates do
  FOOTER_CONTATO = <<~TEXT.chomp
    Se você não reconhece essa cobrança ou tem alguma dúvida sobre o pagamento entre em contato com seu fornecedor:
    Telefone: (31) 98248-8131
    Email: adm@atendmedbh.com.br
  TEXT

  TEMPLATES = {
    cobranca_lembrete_5dias: {
      name: 'cobranca_lembrete_5dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nTudo bem? Queremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de R$ {{2}} vence em 5 dias, no dia {{3}}.\n\nAproveita e já realiza o pagamento para não ter nenhuma preocupação!\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_emissao: {
      name: 'cobranca_emissao',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de R$ {{2}} vence no dia {{3}}.\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_vencimento_hoje: {
      name: 'cobranca_vencimento_hoje',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de R$ {{2}} vence hoje {{3}}.\n\nEvite multas e juros, pague sua fatura em dia.\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_atraso_5dias: {
      name: 'cobranca_atraso_5dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de R$ {{2}} venceu no dia {{3}}.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto.\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_atraso_10dias: {
      name: 'cobranca_atraso_10dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nO seu boleto do MAIS SAÚDE 24 HORAS está ultrapassando o prazo máximo permitido em contrato, no valor de R$ {{2}} venceu no dia {{3}}.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto juntamente com serasa e spc.\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_atraso_15dias: {
      name: 'cobranca_atraso_15dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento link_pagamento],
      body: "Olá {{1}}!\nO seu boleto do MAIS SAÚDE 24 HORAS Ultrapassou o prazo permitido e será executado, você precisa realizar o pagamento hoje ainda e enviar uma cópia do comprovante com urgência para evitar protesto e cobranças extrajudiciais\n\nValor de R$ {{2}} venceu no dia {{3}}.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto juntamente com serasa e spc.\n\nPara efetuar o pagamento e visualizar mais informações da cobrança, clique no link:\n{{4}}\n\n#{FOOTER_CONTATO}"
    },

    cobranca_atraso_21dias: {
      name: 'cobranca_atraso_21dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente],
      body: "Olá {{1}}\n\nComo não houve o pagamento, o seu título foi enviado no cartório juntamente com o SPC e Serasa e caso queira regularizar a situação você pode entrar em contato através deste WhatsApp para realizar a negociação do pagamento Para regularização do CPF e dos benefícios contratados\n\nBasta entrar em contato e solicitar negociação.\n\nTelefone: (31) 98248-8131"
    }
  }.freeze

  def self.find_connection
    id = ENV.fetch('CONNECTION_ID') { abort 'ERROR: CONNECTION_ID env var required' }
    WhatsappConnection.find(id)
  end

  def self.example_values(variables)
    variables.map do |var|
      case var
      when 'nome_cliente'    then 'Maria'
      when 'valor'           then '150,00'
      when 'data_vencimento' then '25/04/2026'
      when 'link_pagamento'  then 'https://exemplo.com/pagamento/123'
      end
    end
  end

  def self.body_component(tpl)
    {
      type: 'BODY',
      text: tpl[:body],
      example: { body_text: [example_values(tpl[:variables])] }
    }
  end

  desc 'Sync all billing templates to Meta (creates missing, updates existing)'
  task sync: :environment do
    connection = find_connection
    crud = WhatsappConnections::Meta::TemplateCrudService.new(connection)

    # Sync from Meta first to get current state
    WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
    existing = (connection.reload.message_templates || []).index_by { |t| t['name'] }

    TEMPLATES.each do |key, tpl|
      meta_tpl = existing[tpl[:name]]

      if meta_tpl
        template_id = meta_tpl['id']
        puts "[UPDATE] #{tpl[:name]} (id: #{template_id})..."
        crud.update_template(template_id, { components: [body_component(tpl)] })
        puts "  -> OK"
      else
        puts "[CREATE] #{tpl[:name]}..."
        payload = {
          name: tpl[:name],
          language: tpl[:language],
          category: tpl[:category],
          components: [body_component(tpl)]
        }
        result = crud.create_template(payload)
        puts "  -> OK (id: #{result['id']})"
      end
    rescue StandardError => e
      puts "  -> ERROR: #{e.message}"
    end

    puts "\nDone!"
  end

  desc 'List all billing template definitions and their variables'
  task definitions: :environment do
    puts "\n=== Billing Templates - Mais Saude 24h ===\n\n"
    TEMPLATES.each do |key, tpl|
      puts "#{key}"
      puts "  Name:      #{tpl[:name]}"
      puts "  Variables: #{tpl[:variables].map.with_index(1) { |v, i| '{{' + i.to_s + '}} = ' + v }.join(', ')}"
      puts "  Body:"
      tpl[:body].lines.each { |l| puts "    #{l}" }
      puts
    end
  end
end
