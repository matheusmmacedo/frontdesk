# frozen_string_literal: true

# Rake tasks to seed/sync Meta WhatsApp message templates for the
# Mais Saude 24h billing flow.
#
# **Source of truth:** PLANO_TEMPLATES_META_FINAL.md (raiz do repo, 2026-04-08).
# Texts approved by Gustavo, naming convention `cobr_*` (substituted ms24h_*
# que ficaram locked 30 dias após cleanup acidental em 2026-04-30).
#
# Estrutura: 7 templates UTILITY pt_BR, ciclo D-5 → D+1 → D+7 → D+15 → D+21
# + cobr_pagto_ok (confirma pagamento). 5 deles têm 2 botões URL (PIX +
# Boleto), 2 não têm botão (transbordo + pagto_ok).
#
# **Idempotência:** existing → PATCH components, missing → POST. Sync continua
# acontecendo via TemplatesSyncJob (3h) + webhook real-time. Esse rake é
# manual seed only; do NOT use to "push state" on schedule.
#
# Usage:
#   rake billing_templates:sync        CONNECTION_ID=<whatsapp_connection_id>
#   rake billing_templates:definitions

namespace :billing_templates do
  STD_FOOTER = <<~TEXT.chomp
    Caso tenha alguma dúvida entre em contato neste WhatsApp
    Telefone: (31) 98248-8131
    Email: adm@atendmedbh.com.br
  TEXT

  PIX_BUTTON_URL    = 'https://app.klaos.ai/pay/{{1}}'
  BOLETO_BUTTON_URL = 'https://app.klaos.ai/boleto/{{1}}'

  PAY_BUTTONS = [
    { type: 'URL', text: 'Pagar via PIX',     url: PIX_BUTTON_URL },
    { type: 'URL', text: 'Ver Boleto (PDF)',  url: BOLETO_BUTTON_URL }
  ].freeze

  STD_VARS_4 = %w[nome_cliente valor data_vencimento codigo_barras].freeze
  STD_VARS_1NAME = %w[nome_cliente].freeze
  STD_VARS_1VAL = %w[valor].freeze
  STD_VARS_1BARRAS = %w[codigo_barras].freeze

  TEMPLATES = {
    cobr_d5_lembrete: {
      name: 'cobr_d5_lembrete',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_4,
      body: "Olá {{1}}!\nInformamos que sua fatura da MAIS SAÚDE 24 HORAS, no valor de {{2}} *vence em 5 dias, no dia {{3}}.*\n\nRealize o pagamento de preferência *antes do vencimento para evitar multas e juros.*\n\nCódigo de barras do boleto:\n{{4}}\n\n#{STD_FOOTER}",
      buttons: PAY_BUTTONS
    },

    cobr_d0_vencimento: {
      name: 'cobr_d0_vencimento',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_4,
      body: "Olá {{1}}!\nSua fatura da MAIS SAÚDE 24 HORAS *vence hoje dia {{3}}. O valor de {{2}}.*\n\nRealize *o pagamento antes do vencimento* para evitar multas e juros.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{STD_FOOTER}",
      buttons: PAY_BUTTONS
    },

    cobr_d1_vencido: {
      name: 'cobr_d1_vencido',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_4,
      body: "*Boleto Vencido*\n\nOlá {{1}}!\nQueremos te avisar que *o boleto registrado em seu CPF venceu dia {{3}}* gerado pela MAIS SAÚDE 24 HORAS, no valor de {{2}}.\n\nRealize o pagamento e regularize seu débito.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{STD_FOOTER}",
      buttons: PAY_BUTTONS
    },

    cobr_d7_atraso: {
      name: 'cobr_d7_atraso',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_4,
      body: "Olá {{1}}!\nQueremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, *no valor de {{2}} venceu há 7 dias, no dia {{3}}.*\n\nLembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título no SPC e em protesto.\n\nCódigo de barras do boleto:\n{{4}}\n\n#{STD_FOOTER}",
      buttons: PAY_BUTTONS
    },

    # NOTE: este body NÃO usa {{1}}/{{2}}/{{3}} — só {{1}}=código de barras.
    # Conforme reescrito pelo Gustavo no plano original ("MUDEI VAMOS TENTAR ASSIM").
    cobr_d15_atraso: {
      name: 'cobr_d15_atraso',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_1BARRAS,
      body: "Olá, recebemos hoje um relatório do banco onde consta o seu nome na lista de inadimplentes, pois seu boleto ultrapassou o prazo permitido para pagamento.\n\nVocê consegue fazer o pagamento hoje ainda e enviar o comprovante?\n\n*Caso não consiga, o banco vai executar o título além de SPC.*\n\nPara isso não acontecer gentileza encaminhar comprovante.\n\nCódigo de barras do boleto:\n{{1}}\n\n#{STD_FOOTER}",
      buttons: PAY_BUTTONS
    },

    cobr_d21_transbordo: {
      name: 'cobr_d21_transbordo',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_1NAME,
      body: "Olá {{1}}\n\nInformamos que, devido à inadimplência, seu título foi encaminhado ao cartório de protesto e aos órgãos de proteção ao crédito (SPC e Serasa). Para regularizar sua situação e evitar restrições no CPF, entre em contato com urgência pelo WhatsApp ou telefone abaixo.\n\nTelefone: (31) 98248-8131",
      buttons: nil
    },

    cobr_pagto_ok: {
      name: 'cobr_pagto_ok',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_1VAL,
      body: 'Pagamento confirmado! Recebemos o valor de {{1}} referente à sua mensalidade do plano Mais Saúde. Obrigado por manter seus benefícios em dia.',
      buttons: nil
    },

    # ===== Família CARTÃO recorrência (meio_pagamento_tipo IN (1, 11, 12)) =====
    # Cartão recorrência NÃO tem código de barras, NÃO tem PDF, NÃO tem PIX —
    # só tem checkout_url / pagamento_online_codigo. Botão único "Atualizar
    # Pagamento" ou "Pagar Agora" → KLaOS resolve o destino do code.

    cobr_card_d5_lembrete: {
      name: 'cobr_card_d5_lembrete',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento],
      body: "Olá {{1}}!\nInformamos que sua mensalidade da MAIS SAÚDE 24 HORAS, no valor de {{2}}, *vai ser cobrada no seu cartão de crédito em 5 dias, no dia {{3}}.*\n\nConfirme que seus dados de pagamento estão atualizados clicando no botão abaixo.\n\n#{STD_FOOTER}",
      buttons: [{ type: 'URL', text: 'Atualizar Pagamento', url: 'https://app.klaos.ai/pay/{{1}}' }]
    },

    cobr_card_d0_vencimento: {
      name: 'cobr_card_d0_vencimento',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento],
      body: "Olá {{1}}!\nSua mensalidade da MAIS SAÚDE 24 HORAS *vai ser cobrada no cartão hoje, dia {{3}}. O valor de {{2}}.*\n\nCaso prefira fazer o pagamento manualmente, use o link abaixo.\n\n#{STD_FOOTER}",
      buttons: [{ type: 'URL', text: 'Pagar Agora', url: 'https://app.klaos.ai/pay/{{1}}' }]
    },

    cobr_card_d1_recusado: {
      name: 'cobr_card_d1_recusado',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento],
      body: "*Pagamento Não Identificado*\n\nOlá {{1}}!\nTentamos realizar a cobrança no seu cartão de crédito, mas *não conseguimos concluir o pagamento da mensalidade no valor de {{2}}* gerada pela MAIS SAÚDE 24 HORAS, com vencimento em {{3}}.\n\nAtualize seus dados de pagamento ou faça uma nova tentativa pelo link abaixo.\n\n#{STD_FOOTER}",
      buttons: [{ type: 'URL', text: 'Atualizar Pagamento', url: 'https://app.klaos.ai/pay/{{1}}' }]
    },

    cobr_card_d7_atraso: {
      name: 'cobr_card_d7_atraso',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: %w[nome_cliente valor data_vencimento],
      body: "Olá {{1}}!\nQueremos te lembrar que *a sua mensalidade da MAIS SAÚDE 24 HORAS, no valor de {{2}}, está em aberto há 7 dias, com vencimento em {{3}}.*\n\nRealize o pagamento pelo link abaixo para evitar a suspensão dos benefícios do plano.\n\n#{STD_FOOTER}",
      buttons: [{ type: 'URL', text: 'Pagar Agora', url: 'https://app.klaos.ai/pay/{{1}}' }]
    },

    # Sem variável no body — espelha o tom enxuto do cobr_d15_atraso
    cobr_card_d15_atraso: {
      name: 'cobr_card_d15_atraso',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: [],
      body: "Olá, identificamos que sua mensalidade da MAIS SAÚDE 24 HORAS continua em aberto, mesmo após várias tentativas de cobrança no seu cartão de crédito.\n\nVocê consegue realizar o pagamento hoje ainda?\n\n*Caso não consiga, sua mensalidade pode ser registrada no SPC.*\n\nAtualize seu pagamento pelo link abaixo.\n\n#{STD_FOOTER}",
      buttons: [{ type: 'URL', text: 'Pagar Agora', url: 'https://app.klaos.ai/pay/{{1}}' }]
    },

    cobr_card_d21_transbordo: {
      name: 'cobr_card_d21_transbordo',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_1NAME,
      body: "Olá {{1}}\n\nInformamos que, devido à inadimplência prolongada no pagamento da sua mensalidade no cartão, sua situação foi encaminhada para análise. Para regularizar e evitar restrições no CPF, entre em contato com urgência pelo WhatsApp ou telefone abaixo.\n\nTelefone: (31) 98248-8131",
      buttons: nil
    },

    cobr_card_pagto_ok: {
      name: 'cobr_card_pagto_ok',
      language: 'pt_BR',
      category: 'UTILITY',
      variables: STD_VARS_1VAL,
      body: 'Pagamento confirmado! Recebemos o valor de {{1}} referente à sua mensalidade do plano Mais Saúde no cartão de crédito. Obrigado por manter seus benefícios em dia.',
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
      when 'data_vencimento' then '25/05/2026'
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

    TEMPLATES.each do |_key, tpl|
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
    puts "\n=== Billing Templates - Mais Saude 24h (cobr_*) ===\n\n"
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
