const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, ShadingType, AlignmentType } = require('docx');
const fs = require('fs');

function h1(text, time) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 500, after: 200 }, children: [
    new TextRun({ text, bold: true, color: '0f3460' }),
    ...(time ? [new TextRun({ text: `  (${time})`, color: '999999', size: 18 })] : []),
  ]});
}
function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 200, after: 100 }, children: [
    new TextRun({ text, bold: true, color: '1a1a2e', size: 22 }),
  ]});
}
function tela(text) {
  return new Paragraph({ spacing: { after: 100 }, children: [
    new TextRun({ text: 'TELA: ', bold: true, color: '6c757d' }), new TextRun({ text, color: '6c757d' }),
  ]});
}
function fala(text) {
  return new Paragraph({ spacing: { after: 150 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'f0f4ff' }, children: [
    new TextRun({ text: `"${text}"`, italics: true, size: 21 }),
  ]});
}
function acao(text) {
  return new Paragraph({ spacing: { after: 50 }, indent: { left: 400 }, children: [
    new TextRun({ text: '> ', bold: true, color: '22c55e' }), new TextRun({ text, size: 20 }),
  ]});
}
function ressalva(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'fff3cd' }, children: [
    new TextRun({ text: 'RESSALVA: ', bold: true, size: 18, color: '856404' }), new TextRun({ text, size: 18, color: '856404' }),
  ]});
}
function fnota(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'e8f5e9' }, children: [
    new TextRun({ text: 'FRONTDESK: ', bold: true, size: 18, color: '1b5e20' }), new TextRun({ text, size: 18, color: '1b5e20' }),
  ]});
}
function instrucao(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'ede9fe' }, children: [
    new TextRun({ text: 'INSTRUCAO TECNICA: ', bold: true, size: 18, color: '5b21b6' }), new TextRun({ text, size: 18, color: '5b21b6' }),
  ]});
}
function br() { return new Paragraph({ spacing: { after: 50 }, children: [] }); }
function makeTable(headers, rows) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({ tableHeader: true, children: headers.map(h =>
        new TableCell({ shading: { type: ShadingType.SOLID, color: '0f3460' }, children: [
          new Paragraph({ children: [new TextRun({ text: h, bold: true, color: 'ffffff', size: 18 })] })
        ]})
      )}),
      ...rows.map((row, i) => new TableRow({ children: row.map(cell =>
        new TableCell({ shading: { type: ShadingType.SOLID, color: i % 2 === 0 ? 'f8f9fa' : 'ffffff' }, children: [
          new Paragraph({ children: [new TextRun({ text: cell, size: 18 })] })
        ]})
      )})),
    ],
  });
}

const doc = new Document({
  styles: { default: { document: { run: { font: 'Calibri', size: 22 } } } },
  sections: [{
    properties: { page: { margin: { top: 800, right: 800, bottom: 800, left: 800 } } },
    children: [
      new Paragraph({ heading: HeadingLevel.TITLE, alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [
        new TextRun({ text: 'Roteiro de Apresentacao', bold: true, size: 36, color: '1a1a2e' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'Mais Saude 24h — Cobranca Automatizada', size: 28, color: '16213e', italics: true }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'Campanha: Apresentacao Gustavo', size: 22, color: '666666' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'KLaOS + Frontdesk — Demo ao Vivo', size: 20, color: '666666' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 }, children: [
        new TextRun({ text: 'Duracao estimada: 15-20 minutos (com testes ao vivo)', size: 20, color: '999999' }),
      ]}),

      // ==================== PARTICIPANTES ====================
      h1('Participantes da Demo'),
      makeTable(['Nome', 'Telefone', 'Divida', 'Papel'], [
        ['Gustavo Oliveira', '+55 31 9891-2489', 'R$ 299,50', 'Devedor principal (recebe msgs + responde)'],
        ['Matheus Macedo', '+55 21 96479-8660', 'R$ 209,70', 'Devedor secundario (recebe msgs)'],
        ['Daniel Limeira', '+55 21 98341-0604', 'R$ 149,70', 'Devedor terciario (recebe msgs)'],
      ]),
      br(),
      ressalva('Os tres ja estao matriculados na campanha "Apresentacao Gustavo". A campanha esta em rascunho e sera ativada ao vivo. A campanha esta em modo demo com intervalos de 1 minuto entre steps. Ao ativar, os disparos acontecem AUTOMATICAMENTE a cada 60 segundos — nao precisa disparar manualmente.'),

      // ==================== CENA 1 ====================
      h1('CENA 1: Dashboard de Cobranca', '2 min'),
      tela('app-dev.klaos.ai > Funil > Cobranca'),
      br(),
      fala('Estamos no KLaOS, no modulo de Cobranca. Aqui vemos o dashboard com os numeros gerais em tempo real: quase 500 devedores sincronizados do Tenex, mais de 26 mil reais de divida total, e a media de atraso. Os stats cards refletem dinamicamente os filtros aplicados.'),
      acao('Apontar para os 4 stats cards'),
      br(),
      fala('Temos duas campanhas: a Demo Cliente que e nossa campanha de testes, e a Apresentacao Gustavo que vamos usar agora pra demonstrar o funcionamento completo ao vivo.'),
      acao('Mostrar os cards das campanhas'),
      br(),
      fala('Na aba Devedores vejo toda a base sincronizada do Tenex. Posso buscar, filtrar por status, e ordenar por divida ou atraso. Clicando em qualquer devedor, abro os dados completos — email, telefone e CPF copiaveis — e as parcelas em aberto com links de Boleto e PIX.'),
      acao('Clicar aba Devedores'),
      acao('Expandir um devedor pra mostrar dados + parcelas'),

      // ==================== CENA 2 ====================
      h1('CENA 2: Campanha Apresentacao Gustavo', '2 min'),
      tela('Clicar no card "Apresentacao Gustavo"'),
      br(),
      fala('Vou abrir a campanha Apresentacao Gustavo. Ela foi criada com 6 passos de regua, usando templates WABA oficiais aprovados pelo Meta. Cada passo tem um template, um dia de disparo relativo ao vencimento, e uma tag automatica que vai ser aplicada no Frontdesk.'),
      acao('Clicar no card da campanha'),
      br(),
      fala('Na aba Cadencia vejo a regua visual: passo 1 envia a fatura no dia da matricula com tag pendente amarela. Passo 2 no dia do vencimento com tag cobranca-0d azul. Passo 3 no D+5 com tag rosa. Passo 4 no D+10 com tag roxa. Passo 5 no D+15 com tag laranja. E passo 6 no D+21 com tag transbordo-humano azul, que transfere pro time de cobranca.'),
      acao('Mostrar aba Cadencia com a timeline dos 6 steps'),
      br(),

      makeTable(['Passo', 'Dia', 'Template', 'Tag (cor)', 'Acao'], [
        ['1', 'Matricula', 'fatura_emissao', 'pendente (amarelo)', 'Informa valor e link'],
        ['2', 'Vencimento', 'cobranca_vencimento_hoje', 'cobranca-0d (azul)', 'Lembra que vence hoje'],
        ['3', 'D+5', 'cobranca_atraso_5dias', 'cobranca-5d (rosa)', 'Alerta de atraso'],
        ['4', 'D+10', 'cobranca_10dias_atraso', 'cobranca-10d (roxa)', 'Aviso de protesto'],
        ['5', 'D+15', 'fatura_atraso_15dias', 'cobranca-15d (laranja)', 'Alerta SPC/Serasa'],
        ['6', 'D+21', 'fatura_atraso_21dias', 'transbordo-humano (azul)', 'Transfere pra humano'],
      ]),

      br(),
      fala('Na aba Matriculados vemos os tres devedores inscritos: Gustavo, Matheus e Daniel. Todos no step 0, aguardando ativacao.'),
      acao('Clicar aba Matriculados e mostrar os 3 enrollments'),

      // ==================== CENA 3 ====================
      h1('CENA 3: Ativando a Campanha', '1 min'),
      tela('Botao Ativar > Modal Review'),
      br(),
      fala('Vou ativar a campanha. Antes, o sistema mostra o Review com os 3 devedores que serao impactados, a divida total, e as tags da regua. Confirmo a ativacao.'),
      acao('Clicar "Ativar"'),
      acao('Mostrar modal Review com os 3 devedores'),
      acao('Clicar "Confirmar e Ativar"'),
      br(),
      instrucao('Apos ativar, o modo demo dispara automaticamente a cada 60 segundos. Step 1 vai sair quase imediatamente, step 2 em 1 minuto, e assim por diante. A regua completa roda em ~6 minutos.'),

      // ==================== CENA 4 ====================
      h1('CENA 4: Primeiro Disparo — Template no WhatsApp', '3 min'),
      tela('WhatsApp do Gustavo + Frontdesk'),
      br(),
      fala('O primeiro template foi disparado. Gustavo, mostra no seu WhatsApp — voce recebeu a mensagem da Mais Saude informando o valor de R$ 299,50 e o link de pagamento.'),
      acao('Gustavo mostra celular com a mensagem recebida'),
      br(),
      fala('Agora vamos ao Frontdesk ver como isso aparece. Vou abrir pelo SSO do KLaOS.'),
      acao('KLaOS > Atendimento > Frontdesk > "Abrir Frontdesk"'),
      br(),
      fala('No Frontdesk, abro a conversa do Gustavo no inbox KLaOS Cobranca. Vejo a mensagem que foi enviada e as tags automaticas: pendente em amarelo e mais-saude em verde — a tag permanente que identifica o cliente do plano.'),
      acao('Abrir conversa do Gustavo no Frontdesk'),
      acao('Mostrar tags: pendente + mais-saude'),
      br(),
      fnota('A tag mais-saude e aplicada automaticamente no momento da matricula e NUNCA e removida, mesmo quando o pagamento for confirmado.'),

      // ==================== CENA 5 ====================
      h1('CENA 5: Disparos Progressivos — Tags Mudando', '4 min'),
      tela('Frontdesk conversa do Gustavo + WhatsApp'),
      br(),
      fala('Agora vou simular a passagem dos dias, disparando os proximos templates. Cada um muda a tag automaticamente.'),
      br(),

      h2('Step 2 — Dia do Vencimento'),
      instrucao('AUTOMATICO — o KLaOS dispara sozinho em ~1 minuto apos o step anterior'),
      fala('Olha o WhatsApp do Gustavo — chegou a mensagem do dia do vencimento. E no Frontdesk, a tag mudou de pendente pra cobranca-0d em azul claro. O sistema removeu a anterior automaticamente.'),
      acao('Mostrar WhatsApp com nova msg'),
      acao('Mostrar tag cobranca-0d azul no Frontdesk'),
      br(),

      h2('Step 3 — D+5'),
      instrucao('AUTOMATICO — dispara ~1 minuto apos o step 2'),
      fala('Agora o step de 5 dias de atraso. Tag mudou pra cobranca-5d em rosa.'),
      acao('Mostrar tag rosa no Frontdesk'),
      br(),

      h2('Step 4 — D+10'),
      instrucao('AUTOMATICO — dispara ~1 minuto apos o step 3'),
      fala('Step de 10 dias. Tag cobranca-10d em roxa. A mensagem ja avisa sobre protesto bancario.'),
      acao('Mostrar tag roxa'),
      br(),

      h2('Step 5 — D+15'),
      instrucao('AUTOMATICO — dispara ~1 minuto apos o step 4'),
      fala('Step de 15 dias. Tag cobranca-15d em laranja. Mensagem menciona SPC e Serasa.'),
      acao('Mostrar tag laranja'),
      br(),

      ressalva('O modo demo dispara a cada 60 segundos. O Gustavo tem ~1 minuto entre cada mensagem pra mostrar no WhatsApp e comentar. Se precisar de mais tempo, o Claude pode pausar a campanha e reativar.'),

      // ==================== CENA 6 ====================
      h1('CENA 6: Lara Respondendo o Gustavo', '4 min'),
      tela('WhatsApp do Gustavo + Frontdesk conversa'),
      br(),
      fala('Agora o Gustavo vai responder uma mensagem de cobranca pra gente ver a Lara em acao.'),
      br(),
      instrucao('Gustavo envia no WhatsApp: "Ola quero saber mais sobre essa cobranca"'),
      fala('Gustavo enviou uma mensagem. A Lara — nossa IA — detecta que ele e um devedor, consulta o Tenex em tempo real pelo CPF, e responde explicando o valor, o vencimento, os dias de atraso, e oferece opcoes de pagamento.'),
      acao('Mostrar resposta da Lara no Frontdesk'),
      br(),
      instrucao('Gustavo envia: "Quero pagar por Pix"'),
      fala('Gustavo disse que quer pagar por Pix. A Lara envia o link do QR Code do Pix e pede o comprovante: "Depois que concluir, me envie o comprovante por aqui, por gentileza."'),
      acao('Mostrar Lara enviando link PIX'),
      acao('Mostrar Lara pedindo comprovante'),
      br(),
      fala('Tudo automatico, sem intervencao humana. A Lara identificou o devedor, explicou a divida, e ofereceu o meio de pagamento que o cliente preferiu.'),

      // ==================== CENA 7 ====================
      h1('CENA 7: Transbordo pro Time Humano', '2 min'),
      tela('Frontdesk conversa do Gustavo'),
      br(),
      fala('Agora vou disparar o ultimo step — D+21 — que faz o transbordo pro time humano.'),
      instrucao('AUTOMATICO — dispara ~1 minuto apos o step 5. Faz handoff pro time cobranca.'),
      br(),
      fala('A mensagem final foi enviada avisando que a divida sera encaminhada ao cartorio de protesto e SPC. E olha no Frontdesk: a tag mudou pra transbordo-humano em azul, e a conversa foi automaticamente atribuida ao time de cobranca. A regra de automacao do Frontdesk fez isso sozinha.'),
      acao('Mostrar tag transbordo-humano azul'),
      acao('Mostrar na sidebar que a conversa esta atribuida ao time "cobranca"'),
      br(),
      fala('Na caixa do time cobranca, o operador humano agora ve essa conversa e pode assumir o atendimento.'),
      acao('Navegar: sidebar > Times > cobranca'),
      acao('Mostrar a conversa do Gustavo na fila do time'),
      br(),
      fnota('A regra de automacao "Transbordo Humano" do Frontdesk detecta a tag transbordo-humano e executa: atribui ao time cobranca + envia email de alerta pro gestor.'),

      // ==================== CENA 8 ====================
      h1('CENA 8: Tags Manuais e Situacionais', '2 min'),
      tela('Frontdesk conversa do Gustavo'),
      br(),
      fala('Alem das tags automaticas da regua, o operador pode adicionar tags manuais. Por exemplo, o Gustavo disse que vai pagar amanha — adiciono a tag cobranca-promessa.'),
      instrucao('Claude adiciona tag cobranca-promessa na conversa do Gustavo. Comando: "tag cobranca-promessa gustavo"'),
      acao('Mostrar tag adicionada na conversa'),
      br(),
      fala('Essas tags situacionais ajudam o time a filtrar e priorizar. Temos tags pra promessa de pagamento, negociacao, segunda via, cartao recusado, cancelamento pendente.'),

      // ==================== CENA 9 ====================
      h1('CENA 9: Confirmacao de Pagamento — Limpeza de Tags', '3 min'),
      tela('Frontdesk conversa do Gustavo'),
      br(),
      fala('Agora vamos simular a confirmacao do pagamento. Quando o Tenex confirma, a tag pagamento-realizado e adicionada. Vou adicionar agora.'),
      instrucao('Claude adiciona tag pagamento-realizado na conversa do Gustavo. Comando: "tag pagamento-realizado gustavo"'),
      br(),
      fala('Olha o que aconteceu automaticamente: a regra de automacao Pagamento Realizado do Frontdesk executou. Ela removeu TODAS as tags de cobranca — transbordo-humano, cobranca-promessa, todas. Adicionou pagamento-realizado em verde claro. E resolveu a conversa.'),
      acao('Mostrar que tags de cobranca sumiram'),
      acao('Mostrar pagamento-realizado verde'),
      acao('Mostrar que a conversa foi resolvida'),
      br(),
      fala('Mas olha uma coisa importante: a tag mais-saude em verde permanece! Ela nunca e removida. Identifica pra sempre que o Gustavo e cliente do plano Mais Saude 24 Horas. Mesmo com o pagamento confirmado e todas as outras tags limpas.'),
      acao('Apontar para mais-saude verde que permaneceu'),
      br(),
      fnota('A regra de automacao remove uma lista especifica de tags (pendente, cobranca-0d/5d/10d/15d, transbordo-humano, situacionais). Tags permanentes como mais-saude, enviado-ao-spc, cancelado e quer-cancelar NAO estao nessa lista, por isso sobrevivem.'),

      // ==================== CENA 10 ====================
      h1('CENA 10: Regras de Automacao e Etiquetas', '2 min'),
      tela('Frontdesk > Configuracoes > Automacao + Etiquetas'),
      br(),
      fala('Vou mostrar onde essas regras vivem. Em Configuracoes, Automacao, temos as duas regras que vimos funcionando: Pagamento Realizado e Transbordo Humano. O operador pode ver e editar essas regras.'),
      acao('Navegar: Configuracoes > Automacao'),
      acao('Mostrar as 2 regras'),
      br(),
      fala('E em Etiquetas, as 19 etiquetas padronizadas com cores definidas pela operacao. Destaque para as quatro permanentes: mais-saude verde, enviado-ao-spc laranja, cancelado preto e quer-cancelar amarelo.'),
      acao('Navegar: Configuracoes > Etiquetas'),
      acao('Mostrar lista com cores'),

      // ==================== CENA 11 ====================
      h1('CENA 11: Timeline Completa no KLaOS', '2 min'),
      tela('KLaOS > Campanha Apresentacao Gustavo > Matriculados'),
      br(),
      fala('Pra finalizar, volto ao KLaOS e abro a timeline do Gustavo. Aqui vejo todo o historico completo: quando foi matriculado, cada mensagem enviada com o conteudo, quando foi entregue, quando foi lida, quando respondeu, quando houve transbordo, e quando o pagamento foi confirmado. Tudo rastreado.'),
      acao('Voltar pro KLaOS'),
      acao('Abrir campanha > Matriculados > expandir Gustavo'),
      acao('Mostrar timeline com todos os eventos'),

      // ==================== ENCERRAMENTO ====================
      h1('ENCERRAMENTO', '30s'),
      br(),
      new Paragraph({ spacing: { after: 200 }, shading: { type: ShadingType.SOLID, color: 'e8f5e9' }, children: [
        new TextRun({ text: '"Resumindo o que vimos: do Tenex ao pagamento, tudo automatizado. Os devedores sao sincronizados com parcelas e links. A regua dispara nos dias certos com templates aprovados pelo Meta e auto-preenchimento inteligente. As tags se atualizam sozinhas no Frontdesk com cores que facilitam a gestao visual. A Lara atende quem responde, identifica pelo CPF e oferece Pix e boleto. O transbordo pro time humano e automatico no D+21. E quando o pagamento e confirmado, todas as tags de cobranca sao limpas preservando as permanentes. KLaOS e Frontdesk trabalhando juntos, com rastreabilidade completa de cada etapa."', italics: true, bold: true, size: 21 }),
      ]}),

      // ==================== TESTE DE TAGS ====================
      h1('APENDICE A: Passo a Passo de Teste de Tags (Gustavo)'),
      br(),
      new Paragraph({ spacing: { after: 100 }, children: [
        new TextRun({ text: 'Sequencia de comandos pra testar tags ao vivo na conversa do Gustavo:', italics: true, color: '666666' }),
      ]}),
      br(),
      makeTable(['#', 'Comando pro Claude', 'O que acontece', 'Verificar no Frontdesk'], [
        ['1', 'disparar step 1 gustavo', 'Envia fatura_emissao', 'Tag: pendente (amarelo) + mais-saude (verde)'],
        ['2', 'disparar step 2 gustavo', 'Envia cobranca_vencimento_hoje', 'Tag muda: cobranca-0d (azul claro)'],
        ['3', 'disparar step 3 gustavo', 'Envia cobranca_atraso_5dias', 'Tag muda: cobranca-5d (rosa)'],
        ['4', 'disparar step 4 gustavo', 'Envia cobranca_10dias_atraso', 'Tag muda: cobranca-10d (roxa)'],
        ['5', 'disparar step 5 gustavo', 'Envia fatura_atraso_15dias', 'Tag muda: cobranca-15d (laranja)'],
        ['6', 'disparar step 6 gustavo', 'Envia fatura_atraso_21dias + handoff', 'Tag: transbordo-humano (azul) + team cobranca'],
        ['7', 'Gustavo responde no WhatsApp', 'Lara atende automaticamente', 'Ver resposta da Lara na conversa'],
        ['8', 'tag cobranca-promessa gustavo', 'Adiciona tag situacional', 'Tag aparece na sidebar'],
        ['9', 'tag pagamento-realizado gustavo', 'Aciona automacao de pagamento', 'Tags limpas, so mais-saude resta, conversa resolvida'],
      ]),

      br(),
      ressalva('Entre cada step, esperar 10-15 segundos pro WhatsApp receber e pro Frontdesk atualizar. O Gustavo deve mostrar o celular apos cada disparo.'),
      ressalva('Se o Gustavo responder no WhatsApp apos qualquer step, a Lara vai atender. Isso abre a janela de 24h e permite mensagens de texto livre (nao so templates).'),
      ressalva('O step 6 (transbordo) alem de enviar o template, faz handoff real: muda status pra open, atribui ao team cobranca, e a Lara para de responder.'),
      fnota('Apos o step 9 (pagamento), a conversa fica resolvida. Se quiser reabrir pra mostrar algo, o Claude pode mudar o status via API.'),

      // ==================== DADOS TECNICOS ====================
      h1('APENDICE B: Dados Tecnicos da Campanha'),
      br(),
      makeTable(['Campo', 'Valor'], [
        ['Campanha ID', 'f0dab2d3-68e6-45f4-b4d7-24cfdf05b27f'],
        ['Status', 'draft (sera ativada ao vivo)'],
        ['Inbox', 'KLaOS Cobranca (ID 30) — WABA +553197286773'],
        ['Handoff Team', 'cobranca (ID 2)'],
        ['Stop on Payment', 'Sim'],
        ['Horario', '0h-23h, todos os dias'],
        ['Auto-enroll', 'Sim'],
      ]),
      br(),
      h2('Gustavo Oliveira'),
      makeTable(['Campo', 'Valor'], [
        ['Telefone', '+553198912489'],
        ['Divida', 'R$ 299,50'],
        ['Enrollment ID', 'a verificar apos ativacao'],
        ['Conversa Frontdesk', 'a ser criada no step 1'],
      ]),
      br(),
      h2('Templates WABA (todos APPROVED, encoding OK)'),
      makeTable(['Template', 'Params', 'Obs'], [
        ['fatura_emissao', 'nome, valor, vencimento, link', ''],
        ['cobranca_vencimento_hoje', 'nome, valor, vencimento, link', ''],
        ['cobranca_atraso_5dias', 'nome, valor, vencimento, link', ''],
        ['cobranca_10dias_atraso', 'nome, valor, vencimento, link', 'NOVO — substituiu fatura_vencida_10dias (encoding fix)'],
        ['fatura_atraso_15dias', 'nome, valor, vencimento, link', ''],
        ['fatura_atraso_21dias', 'nome (so 1 param)', 'Ultimo step — handoff'],
      ]),

      // ==================== CHECKLIST ====================
      h1('Checklist Pre-Gravacao'),
      br(),
      ...[
        'KLaOS logado com workspace "Mais Saude"',
        'Campanha "Apresentacao Gustavo" visivel em draft',
        'Gustavo, Matheus e Daniel matriculados (step 0)',
        'WhatsApp do Gustavo aberto e visivel na gravacao',
        'Templates WABA aprovados (8 templates, todos encoding OK)',
        'SSO funcionando (Abrir Frontdesk sem senha)',
        '19 etiquetas visiveis em Frontdesk > Configuracoes > Etiquetas',
        '2 regras de automacao ativas em Frontdesk > Configuracoes > Automacao',
        'Claude pronto pra disparar templates via API (roteiro ao vivo)',
        'OBS gravando tela + audio',
      ].map(item => new Paragraph({ bullet: { level: 0 }, spacing: { after: 50 }, children: [new TextRun({ text: item, size: 20 })] })),
    ],
  }],
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync('C:/dev/gmb/frontdesk/ROTEIRO_VIDEO_MAIS_SAUDE.docx', buffer);
  console.log('Word FINAL gerado — Apresentacao Gustavo!');
});
