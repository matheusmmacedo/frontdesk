# frozen_string_literal: true

# Rake tasks to seed/sync Meta WhatsApp message templates for the
# Mais Saude 24h billing flow.
#
# Source of truth: the WABA on Meta. This rake is **idempotent**:
# - existing templates → PATCH components (no-op if identical, requeues approval if changed)
# - missing templates  → POST create (goes to PENDING then APPROVED)
#
# Continuous sync of template state into the local DB happens via
# `WhatsappConnections::TemplatesSyncJob` (every 3h) + Meta webhook
# (`template_status_update`, when wired). This rake is **manual seed only**;
# do NOT use it to "push state" to Meta on a schedule.
#
# Usage:
#   rake billing_templates:sync        CONNECTION_ID=<whatsapp_connection_id>
#   rake billing_templates:definitions

namespace :billing_templates do
  FOOTER_CONTATO = <<~TEXT.chomp
    Telefone: (31) 98248-8131
    Email: adm@atendmedbh.com.br
  TEXT

  PIX_BUTTON_URL    = 'https://app.klaos.ai/pay/{{1}}'
  BOLETO_BUTTON_URL = 'https://app.klaos.ai/boleto/{{1}}'

  PAY_BUTTONS = [
    { type: 'URL', text: 'Pagar via PIX',     url: PIX_BUTTON_URL },
    { type: 'URL', text: 'Ver Boleto (PDF)',  url: BOLETO_BUTTON_URL }
  ].freeze

  # Vars contract for the 6 main templates: nome_cliente, valor, data_vencimento, codigo_barras
  STD_VARS = %w[nome_cliente valor data_vencimento codigo_barras].freeze

  # Body texts mirror what is currently APPROVED on the WABA Klaus on Meta.
  # If you change a body, Meta will re-queue the template for approval.
  TEMPLATES = {
    fatura_lembrete_5dias: {
      name: 'fatura_lembrete_5dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nInformamos que sua fatura da MAIS SAÚDE 24 HORAS, no valor de {{2}} vence em 5 dias, no dia {{3}}.\n\nRealize o pagamento antes do vencimento para evitar multas e juros.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    fatura_emissao: {
      name: 'fatura_emissao',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nSua fatura da MAIS SAÚDE 24 HORAS foi emitida. O valor de {{2}} vence no dia {{3}}.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    cobranca_vencimento_hoje: {
      name: 'cobranca_vencimento_hoje',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de {{2}} vence hoje {{3}}.\n\nEvite multas e juros, pague sua fatura em dia.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    cobranca_atraso_5dias: {
      name: 'cobranca_atraso_5dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, no valor de {{2}} venceu no dia {{3}}.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    boleto_atraso_10dias: {
      name: 'boleto_atraso_10dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nSeu boleto da MAIS SAÚDE 24 HORAS no valor de {{2}} venceu no dia {{3}} e ainda não identificamos o pagamento.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    fatura_atraso_15dias: {
      name: 'fatura_atraso_15dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS,
      body: "Olá {{1}}!\nO seu boleto da MAIS SAÚDE 24 HORAS ultrapassou o prazo permitido e será executado. Realize o pagamento hoje e envie uma cópia do comprovante com urgência para evitar protesto e cobranças extrajudiciais.\n\nValor de {{2}} venceu no dia {{3}}.\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título em protesto juntamente com serasa e spc.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{FOOTER_CONTATO}",
      buttons: PAY_BUTTONS
    },

    fatura_atraso_21dias: {
      name: 'fatura_atraso_21dias',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente],
      body: "Olá {{1}}\n\nInformamos que, devido à inadimplência, seu título foi encaminhado ao cartório de protesto e aos órgãos de proteção ao crédito (SPC e Serasa). Para regularizar sua situação e evitar restrições no CPF, entre em contato pelo WhatsApp ou telefone abaixo.\n\nTelefone: (31) 98248-8131",
      buttons: nil
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
      when 'valor'           then 'R$ 150,00'
      when 'data_vencimento' then '25/04/2026'
      when 'codigo_barras'   then '23793.38128 60000.000003 00058.650146 1 92650000015000'
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

  def self.buttons_component(tpl)
    return nil if tpl[:buttons].blank?

    {
      type: 'BUTTONS',
      buttons: tpl[:buttons].map do |btn|
        b = { type: btn[:type], text: btn[:text] }
        b[:url] = btn[:url] if btn[:url]
        b[:example] = [btn[:url].gsub('{{1}}', 'abc123')] if btn[:url]&.include?('{{1}}')
        b
      end
    }
  end

  def self.template_components(tpl)
    components = [body_component(tpl)]
    btn = buttons_component(tpl)
    components << btn if btn
    components
  end

  desc 'Seed/refresh billing templates on Meta (idempotent: PATCH if exists, POST if missing)'
  task sync: :environment do
    connection = find_connection
    crud = WhatsappConnections::Meta::TemplateCrudService.new(connection)

    # Pull current state from Meta first so we know what exists.
    WhatsappConnections::Meta::TemplateSyncService.new(connection).perform
    existing = (connection.reload.message_templates || []).index_by { |t| t['name'] }

    TEMPLATES.each do |key, tpl|
      meta_tpl = existing[tpl[:name]]

      if meta_tpl
        template_id = meta_tpl['id']
        puts "[UPDATE] #{tpl[:name]} (id: #{template_id})..."
        crud.update_template(template_id, { components: template_components(tpl) })
        puts '  -> OK'
      else
        puts "[CREATE] #{tpl[:name]}..."
        payload = {
          name: tpl[:name],
          language: tpl[:language],
          category: tpl[:category],
          components: template_components(tpl)
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
      puts key.to_s
      puts "  Name:      #{tpl[:name]}"
      puts "  Category:  #{tpl[:category]}"
      puts "  Variables: #{tpl[:variables].map.with_index(1) { |v, i| "{{#{i}}} = #{v}" }.join(', ')}"
      puts '  Body:'
      tpl[:body].lines.each { |l| puts "    #{l}" }
      if tpl[:buttons].present?
        puts '  Buttons:'
        tpl[:buttons].each { |b| puts "    [#{b[:type]}] #{b[:text]} → #{b[:url]}" }
      end
      puts
    end
  end
end
