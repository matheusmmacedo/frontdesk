const { Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, ShadingType, AlignmentType } = require('docx');
const fs = require('fs');

function h1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 500, after: 200 }, children: [
    new TextRun({ text, bold: true, color: '0f3460' }),
  ]});
}
function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 300, after: 100 }, children: [
    new TextRun({ text, bold: true, color: '1a1a2e', size: 24 }),
  ]});
}
function h3(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_3, spacing: { before: 200, after: 80 }, children: [
    new TextRun({ text, bold: true, color: '2d3748', size: 22 }),
  ]});
}
function p(text) {
  return new Paragraph({ spacing: { after: 100 }, children: [new TextRun({ text, size: 20 })] });
}
function bullet(text) {
  return new Paragraph({ bullet: { level: 0 }, spacing: { after: 50 }, children: [new TextRun({ text, size: 20 })] });
}
function bullet2(text) {
  return new Paragraph({ bullet: { level: 1 }, spacing: { after: 30 }, children: [new TextRun({ text, size: 18 })] });
}
function klaosBox(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'dbeafe' }, children: [
    new TextRun({ text: 'KLAOS: ', bold: true, size: 18, color: '1e40af' }), new TextRun({ text, size: 18, color: '1e40af' }),
  ]});
}
function fdBox(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'e8f5e9' }, children: [
    new TextRun({ text: 'FRONTDESK: ', bold: true, size: 18, color: '1b5e20' }), new TextRun({ text, size: 18, color: '1b5e20' }),
  ]});
}
function ecosBox(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'fef3c7' }, children: [
    new TextRun({ text: 'ECOSSISTEMA: ', bold: true, size: 18, color: '92400e' }), new TextRun({ text, size: 18, color: '92400e' }),
  ]});
}
function conclusaoBox(text) {
  return new Paragraph({ spacing: { after: 100 }, indent: { left: 200 }, shading: { type: ShadingType.SOLID, color: 'ede9fe' }, children: [
    new TextRun({ text, bold: true, size: 18, color: '5b21b6' }),
  ]});
}
function br() { return new Paragraph({ spacing: { after: 50 }, children: [] }); }

function makeTable(headers, rows) {
  return new Table({
    width: { size: 100, type: WidthType.PERCENTAGE },
    rows: [
      new TableRow({ tableHeader: true, children: headers.map(h =>
        new TableCell({ shading: { type: ShadingType.SOLID, color: '0f3460' }, children: [
          new Paragraph({ children: [new TextRun({ text: h, bold: true, color: 'ffffff', size: 16 })] })
        ]})
      )}),
      ...rows.map((row, i) => new TableRow({ children: row.map(cell =>
        new TableCell({ shading: { type: ShadingType.SOLID, color: i % 2 === 0 ? 'f8f9fa' : 'ffffff' }, children: [
          new Paragraph({ children: [new TextRun({ text: String(cell), size: 16 })] })
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
      // === CAPA ===
      new Paragraph({ heading: HeadingLevel.TITLE, alignment: AlignmentType.CENTER, spacing: { after: 200 }, children: [
        new TextRun({ text: 'Analise PRD KLaOS CRM', bold: true, size: 40, color: '0f3460' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'vs Estado Atual do Ecossistema', size: 28, color: '1a1a2e', italics: true }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'KLaOS (Cerebro) + Frontdesk (Atendimento & Conexoes)', size: 22, color: '666666' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 100 }, children: [
        new TextRun({ text: 'Abril 2026', size: 20, color: '999999' }),
      ]}),
      new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 }, children: [
        new TextRun({ text: 'Analise automatizada de codigo, banco de dados, APIs e integracoes de ambos os sistemas', size: 18, color: '999999' }),
      ]}),

      // === VISAO ECOSSISTEMA ===
      h1('Visao do Ecossistema KLaOS + Frontdesk'),
      br(),
      p('O KLaOS e o Frontdesk nao sao sistemas concorrentes — sao partes complementares de um ecossistema unico. Cada um tem um papel claro:'),
      br(),
      makeTable(['Sistema', 'Papel', 'Responsabilidades'], [
        ['KLaOS', 'Cerebro / Orquestrador', 'CRM, Pipeline, Deals, IA, Forecast, BI, Automacoes, Agentes, Marketing, Cobranca, Analytics'],
        ['Frontdesk (Chatwoot)', 'Canal de Atendimento & Conexoes', 'Conversas em tempo real, WhatsApp (oficial + nao-oficial), widgets, inbox management, routing de agentes, CSAT, SLA'],
      ]),
      br(),
      ecosBox('O Frontdesk fornece ao KLaOS: canais de comunicacao (WhatsApp, web widget, email), gestao de conversas, routing de atendentes, templates WABA, automacoes de atendimento. O KLaOS fornece ao Frontdesk: inteligencia (agentes IA), contexto de CRM (dados do deal na conversa), orquestracao de campanhas, e decisoes de negocio.'),
      br(),

      h2('Como os dois se integram hoje'),
      makeTable(['Integracao', 'Direcao', 'Mecanismo', 'Status'], [
        ['Agent Bot', 'KLaOS > Frontdesk', 'agent_frontdesk_bridge: provisiona bot IA no inbox', 'OK - Funciona'],
        ['Webhooks de Conversa', 'Frontdesk > KLaOS', 'conversation_created, message_created, conversation_updated', 'OK - Funciona'],
        ['Sync de Contatos', 'Bidirecional', 'conversationContactSync.service.ts: cria contato CRM a partir de conversa', 'OK - Funciona'],
        ['Criacao de Deal', 'KLaOS > Frontdesk', 'agent_frontdesk_bridge com auto_create_crm_deal', 'PARCIAL - Config existe, fluxo incompleto'],
        ['WhatsApp Pool', 'Frontdesk > KLaOS', 'WhatsApp Connection Pool: meta_cloud + evolution providers', 'OK - Funciona'],
        ['WABA Templates', 'KLaOS > Frontdesk', 'Templates de cobranca registrados via rake task', 'OK - Funciona'],
        ['Tags de Campanha', 'KLaOS > Frontdesk', 'KLaOS aplica/remove tags na conversa via API Chatwoot', 'OK - Funciona'],
        ['Handoff IA > Humano', 'KLaOS > Frontdesk', 'agent_handoff_config: transfere conversa para team humano', 'OK - Funciona'],
        ['SSO', 'KLaOS > Frontdesk', 'Login unico: KLaOS abre Frontdesk sem senha adicional', 'OK - Funciona'],
      ]),

      // === LEGENDA ===
      br(),
      h1('Legenda de Status'),
      makeTable(['Simbolo', 'Significado'], [
        ['OK', 'Existe e funciona no ecossistema'],
        ['PARCIAL', 'Existe parcialmente ou precisa ajustes'],
        ['FALTA', 'Nao existe em nenhum dos dois sistemas'],
        ['KLAOS', 'Responsabilidade exclusiva do KLaOS'],
        ['FRONTDESK', 'Responsabilidade exclusiva do Frontdesk'],
        ['AMBOS', 'Requer trabalho coordenado nos dois sistemas'],
      ]),
      br(),

      // === SPRINT 0 ===
      h1('SPRINT 0 — Fundacao Tecnica'),
      p('Objetivo: Base tecnica solida que suporte todas as funcionalidades futuras sem retrabalho.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado no KLaOS', 'Estado no Frontdesk', 'Veredicto'], [
        ['Infra cloud (staging + prod)', 'AMBOS', 'Supabase + Railway (dev + prod)', 'Railway (dev + prod)', 'OK'],
        ['Multi-tenant', 'AMBOS', 'workspaces + RLS no Supabase', 'accounts (Chatwoot nativo)', 'OK'],
        ['Auth + SSO + JWT + RBAC', 'KLAOS', 'Supabase Auth, roles: super_admin/admin/user', 'Devise + JWT (nativo Chatwoot)', 'PARCIAL — Falta role Viewer e Manager no KLaOS'],
        ['Data model CRM (Company, Contact, Deal, Pipeline, Stage)', 'KLAOS', 'bi_crm_deals, bi_crm_contacts, bi_crm_companies, crm_pipelines, crm_stages', 'N/A (CRM nao mora aqui)', 'OK — Esta no KLaOS'],
        ['Event Store', 'KLAOS', 'events table + audit_logs (nao e event sourcing puro)', 'Activity messages em conversations (nativo)', 'PARCIAL — Precisa Event Store CRM dedicado'],
        ['API REST base', 'KLAOS', '/api/crm/* com CRUD completo', 'Contacts/Companies API (atendimento)', 'OK'],
        ['Webhooks', 'AMBOS', 'Webhooks para Evolution/WABA/Frontdesk', 'Webhook hooks system (nativo Chatwoot)', 'OK'],
        ['Observabilidade', 'AMBOS', 'Logger + audit_logs, sem tracing', 'Basico (logs Rails)', 'PARCIAL'],
      ]),
      br(),
      conclusaoBox('Sprint 0 esta em ~80%. A fundacao existe nos dois lados. Gap principal: Event Store CRM dedicado e RBAC com 4 niveis.'),

      // === SPRINT 1 ===
      h1('SPRINT 1 — Core Entities (Empresa, Contato, Deal)'),
      p('Objetivo: Cadastro completo das entidades basicas do CRM com campos customizados.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Cadastro de Empresa', 'KLAOS', 'bi_crm_companies existe com CRUD', 'OK'],
        ['Cadastro de Contato', 'AMBOS', 'KLaOS: bi_crm_contacts | Frontdesk: contacts (com sync bidirecional)', 'OK — Sync funciona'],
        ['Cadastro de Deal', 'KLAOS', 'bi_crm_deals com value, currency, pipeline, stage, probability', 'OK'],
        ['Campos Customizados', 'KLAOS', 'custom_fields JSONB nos deals, sem tabela de definicoes', 'PARCIAL — Falta crm_custom_field_definitions'],
        ['Origem do Lead', 'KLAOS', 'leads + lead_touchpoints (channel, utm, event_type)', 'OK'],
        ['Busca Global', 'AMBOS', 'KLaOS: API search | Frontdesk: trigram search em contacts', 'PARCIAL — Falta full-text unificado no KLaOS'],
        ['Importacao CSV', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Deteccao de Duplicatas', 'KLAOS', 'Nao existe (Frontdesk tem merge manual de contacts)', 'FALTA'],
      ]),
      br(),
      ecosBox('Contatos existem nos dois lados por design: o Frontdesk gerencia o contato como "pessoa que conversa" (telefone, conversa, inbox). O KLaOS gerencia como "lead/prospect" (score, ICP, deal). O sync bidirecional via webhooks mantem ambos atualizados.'),

      // === SPRINT 2 ===
      h1('SPRINT 2 — Pipeline & Kanban'),
      p('Objetivo: Interface visual de gestao de pipeline com kanban interativo e multiplos funis.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Gerenciador de Pipelines', 'KLAOS', 'crm_pipelines + crm_stages com order, probability, color', 'OK'],
        ['Kanban Principal', 'KLAOS', 'Frontend React existe, precisa validar completude', 'PARCIAL'],
        ['Drag and Drop', 'KLAOS', 'Provavel no frontend, precisa validar', 'PARCIAL'],
        ['Filtros no Kanban', 'KLAOS', 'API suporta filtros', 'PARCIAL — UI precisa validar'],
        ['Visao de Lista', 'KLAOS', 'API suporta', 'PARCIAL'],
        ['Rotting Indicator', 'KLAOS', 'Sem campo rotting_days em crm_stages', 'FALTA'],
        ['Quick Edit', 'KLAOS', 'API permite, UI precisa validar', 'PARCIAL'],
      ]),
      br(),
      klaosBox('O Kanban e 100% responsabilidade do KLaOS. O Frontdesk nao exibe pipeline — ele mostra conversas. Se o agente no Frontdesk precisar ver o deal, vemos na sidebar via bridge.'),

      // === SPRINT 3 ===
      h1('SPRINT 3 — Atividades, Tarefas & Timeline'),
      p('Objetivo: Registrar todo o historico de interacoes e criar sistema de tarefas com lembretes.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Timeline do Deal', 'KLAOS', 'crm_deal_activities existe com implementacao minima', 'PARCIAL'],
        ['Log de Atividade (call, meeting, email, note)', 'AMBOS', 'KLaOS: tabela existe, tipos limitados | Frontdesk: activity messages em conversations', 'PARCIAL — Frontdesk ja loga atividades de conversa que alimentam o KLaOS via webhook'],
        ['Tarefas Manuais', 'KLAOS', 'crm_tasks com todos os campos necessarios', 'OK'],
        ['Board de Tarefas', 'KLAOS', 'tasks table (todo/doing/done, priority, type)', 'OK'],
        ['Lembretes/Notificacoes', 'AMBOS', 'KLaOS: notifications | Frontdesk: notificacoes in-app de conversa', 'PARCIAL — Falta lembrete 24h antes de tarefa'],
        ['Email Tracking', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Notas Internas', 'AMBOS', 'KLaOS: lead_notes | Frontdesk: notes em contacts + notas privadas em conversas', 'PARCIAL — Falta notas em deals no KLaOS'],
        ['Historico da Empresa', 'KLAOS', 'Parcial via deals relacionados', 'PARCIAL'],
      ]),
      br(),
      ecosBox('O Frontdesk gera atividades naturalmente: cada conversa, mensagem, resolucao e mudanca de status e um evento. O KLaOS consome esses eventos via webhook e registra na timeline do deal/contato. O fluxo e: Frontdesk gera > webhook > KLaOS registra.'),

      // === SPRINT 4 ===
      h1('SPRINT 4 — Forecast & Reports v1'),
      p('Objetivo: Visibilidade de pipeline e previsao de receita com metricas essenciais de vendas.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Tela de Forecast', 'KLAOS', 'businessMetrics.service.ts tem calculos, sem UI dedicada', 'PARCIAL'],
        ['Meta por Rep/Time', 'KLAOS', 'Sem tabela de metas', 'FALTA'],
        ['Relatorio de Pipeline', 'KLAOS', 'engineBI.service.ts tem aggregations basicas', 'PARCIAL'],
        ['Analise Win/Loss', 'KLAOS', 'Deals tem status won/lost, sem analise dedicada', 'PARCIAL'],
        ['Velocidade do Pipeline', 'KLAOS', 'Nao implementado', 'FALTA'],
        ['Relatorio de Atividade', 'AMBOS', 'KLaOS: agent_analytics_daily | Frontdesk: ReportingEvents de conversations', 'PARCIAL — Dados existem nos dois, falta consolidar'],
        ['Exportacao XLSX/CSV', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Dashboard do Vendedor', 'KLAOS', 'Nao existe', 'FALTA'],
      ]),
      br(),
      ecosBox('O Frontdesk contribui com metricas de atendimento: tempo de primeira resposta, tempo de resolucao, CSAT, SLA. Esses dados alimentam a visao RevOps quando combinados com pipeline e forecast do KLaOS.'),

      // === SPRINT 5 ===
      h1('SPRINT 5 — Automacoes & Triggers'),
      p('Objetivo: Motor de automacao que dispara acoes baseadas em eventos sem codigo.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Builder de Gatilhos (no-code)', 'KLAOS', 'Nao existe para CRM (Frontdesk tem AutomationRule para conversas)', 'FALTA — CRM triggers no KLaOS'],
        ['Eventos de Deal (movido, criado, rotting)', 'KLAOS', 'Sem event triggers para CRM', 'FALTA'],
        ['Acoes (criar tarefa, webhook, email, mover estagio)', 'AMBOS', 'KLaOS: Scheduler + pg-boss | Frontdesk: 16 actions para conversas', 'PARCIAL'],
        ['Templates de Automacao prontas', 'AMBOS', 'KLaOS: nao tem | Frontdesk: Macros para conversas', 'FALTA — Templates CRM no KLaOS'],
        ['Log de Execucao', 'AMBOS', 'KLaOS: audit_logs | Frontdesk: basic logging', 'PARCIAL'],
        ['Notificacoes Push', 'AMBOS', 'KLaOS: notifications table | Frontdesk: notificacoes in-app', 'OK'],
      ]),
      br(),
      ecosBox('A automacao opera em duas camadas: (1) Frontdesk: automacoes de CONVERSA — quando recebe msg com tag X, atribui ao time Y, muda prioridade. Ja funciona com 85+ condicoes e 16 acoes. (2) KLaOS: automacoes de NEGOCIO/CRM — quando deal muda de estagio, cria tarefa, notifica. Essa camada FALTA. As duas devem se complementar via webhooks.'),

      // === SPRINT 6 ===
      h1('SPRINT 6 — AI Agents Fase 1'),
      p('Objetivo: Primeiros agentes de IA: enriquecimento de leads e geracao de tarefas contextuais.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Enrichment Agent', 'KLAOS', 'Sem agent de enriquecimento. leads tem campos mas preenchimento manual/Unipile', 'FALTA'],
        ['Task Agent', 'KLAOS', 'agent_tasks e ai_actions existem, mas nao geram tarefas CRM automaticas', 'PARCIAL'],
        ['Lead Scoring v1', 'KLAOS', 'leads.lead_score (0-100), icp_fit, engagement_percent, lead_scores_history com breakdown', 'OK'],
      ]),
      br(),
      klaosBox('Os agentes de IA sao 100% KLaOS. O Frontdesk e um CANAL onde esses agentes operam (ex: agent bot respondendo no WhatsApp), mas a inteligencia, decisao e orquestracao sao do KLaOS.'),
      fdBox('O Frontdesk ja suporta Agent Bots nativamente — o KLaOS provisiona seus agentes como bots no Frontdesk via agent_frontdesk_bridge. Esse mecanismo ja funciona.'),

      // === SPRINT 7 ===
      h1('SPRINT 7 — Integracao KLaOS (Marketing + CS)'),
      p('Objetivo: Conectar CRM ao ecossistema KLaOS com dados de Marketing e CS para visao RevOps.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Marketing > CRM (MQL sync)', 'KLAOS', 'lead_touchpoints + lead_conversions existem, sem sync auto para deals', 'PARCIAL'],
        ['Attribution multi-touch', 'KLAOS', 'lead_touchpoints rastreia multiplos canais com UTM', 'PARCIAL — Falta exibicao na timeline do deal'],
        ['CS Integration (health score)', 'AMBOS', 'KLaOS: sem modulo CS estruturado | Frontdesk: CSAT surveys + SLA tracking', 'FALTA — Precisa health score consolidado'],
        ['Handoff Deal ganho > CS onboarding', 'AMBOS', 'KLaOS: pode disparar webhook | Frontdesk: pode criar conversa de onboarding', 'FALTA — Fluxo nao implementado'],
        ['Frontdesk <> KLaOS Bridge', 'AMBOS', 'Bridge funcional: bots, webhooks, sync contatos, tags', 'OK'],
        ['Visao RevOps 360', 'KLAOS', 'board_snapshots tem KPIs parciais', 'PARCIAL'],
      ]),
      br(),
      ecosBox('O Frontdesk e o braco de CS natural do ecossistema: conversas de suporte, CSAT, SLA, resolucao de tickets. Esses dados devem fluir pro KLaOS como sinais de health score. O handoff CRM>CS tambem passa pelo Frontdesk: deal ganho > cria conversa de onboarding no inbox de CS.'),

      // === SPRINT 8 ===
      h1('SPRINT 8 — Forecast Preditivo'),
      p('Objetivo: Modelo probabilistico por deal baseado em dados historicos.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Win Score por deal (ML)', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Categorias de Forecast', 'KLAOS', 'Deal tem probability mas sem categorias (commit/best_case/pipeline)', 'FALTA'],
        ['Forecast historico', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Cenarios (Conservador/Base/Otimista)', 'KLAOS', 'Nao existe', 'FALTA'],
      ]),
      br(),
      klaosBox('Forecast e 100% KLaOS. O Frontdesk contribui indiretamente: dados de engajamento de conversas (tempo de resposta, frequencia) podem ser features do modelo de ML.'),

      // === SPRINT 9 ===
      h1('SPRINT 9 — Communication Agent'),
      p('Objetivo: Disparos de comunicacao contextuais e personalizados via email e WhatsApp.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['Email personalizado por IA', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Templates dinamicos', 'AMBOS', 'KLaOS: collection_templates + WABA | Frontdesk: WABA templates registrados', 'PARCIAL — So cobranca, falta vendas'],
        ['Sequencias de nurturing', 'KLAOS', 'collection_sequence_steps para cobranca, nao para vendas', 'PARCIAL'],
        ['WhatsApp Business API (disparos)', 'AMBOS', 'KLaOS: orquestra disparo | Frontdesk: canal de entrega (WhatsApp Connection Pool)', 'OK'],
        ['A/B testing', 'KLAOS', 'linkedin_message_variants para LinkedIn, nao para email/WhatsApp', 'PARCIAL'],
        ['LGPD/Opt-in', 'AMBOS', 'Nao implementado formalmente', 'FALTA'],
      ]),
      br(),
      ecosBox('O Communication Agent do KLaOS DECIDE o que enviar (template, momento, canal). O Frontdesk ENTREGA a mensagem via seus canais conectados (WhatsApp oficial/nao-oficial, web widget). O fluxo e: KLaOS decide > chama API Frontdesk > Frontdesk entrega via canal > webhook confirma entrega > KLaOS registra. Isso ja funciona para cobrancas.'),

      // === SPRINT 10-12 ===
      h1('SPRINT 10-12 — BI Dashboard, BI Chat, Auto-Gestao'),
      p('Objetivo: Dashboard avancado, assistente conversacional e CRM que age proativamente.'),
      br(),
      makeTable(['Item do PRD', 'Quem faz', 'Estado Atual', 'Veredicto'], [
        ['BI Dashboard RevOps', 'KLAOS', 'board_snapshots, analytics_* tables, engineBI.service.ts', 'PARCIAL'],
        ['Metricas de CS no dashboard', 'AMBOS', 'Frontdesk gera dados (CSAT, SLA) | KLaOS consolida', 'PARCIAL — Falta integracao'],
        ['BI Chat Agent', 'KLAOS', 'Infra de agentes existe, sem agent BI CRM dedicado', 'PARCIAL'],
        ['Anomaly Detection', 'KLAOS', 'anomalyDetection.service.ts + analytics_anomalies table', 'OK'],
        ['Deal Routing Inteligente', 'KLAOS', 'Nao existe', 'FALTA'],
        ['Process Optimizer', 'KLAOS', 'analytics_recommendations table existe', 'PARCIAL'],
      ]),

      // ============================================
      // CAPACIDADES DO FRONTDESK
      // ============================================
      h1('O que o Frontdesk ja entrega ao Ecossistema'),
      p('O Frontdesk (fork Chatwoot) nao e um CRM — e o modulo de atendimento e comunicacao do KLaOS. Suas capacidades sao essenciais para o funcionamento do CRM.'),
      br(),

      h2('Canais de Comunicacao (ja funcionam)'),
      makeTable(['Canal', 'Tipo', 'Estado', 'Uso pelo KLaOS'], [
        ['WhatsApp Oficial (Meta Cloud API)', 'WABA', 'OK - WhatsApp Connection Pool com sync de templates', 'Cobranca automatizada, templates de vendas, notificacoes'],
        ['WhatsApp Nao-Oficial (Evolution API)', 'API terceiro', 'OK - Instancias via QR code', 'Atendimento multi-numero, canais de suporte'],
        ['Web Widget (Live Chat)', 'Nativo Chatwoot', 'OK', 'Chat ao vivo no site, captura de leads'],
        ['Email', 'IMAP/SMTP', 'OK - Nativo Chatwoot', 'Suporte por email, notificacoes'],
        ['Facebook Messenger', 'API Meta', 'OK - Nativo Chatwoot', 'Social selling, atendimento'],
        ['Instagram DM', 'API Meta', 'OK - Nativo Chatwoot', 'Social selling, atendimento'],
        ['Telegram', 'API nativa', 'OK - Nativo Chatwoot', 'Canal alternativo'],
        ['API Channel', 'Custom', 'OK - Nativo Chatwoot', 'Integracoes custom'],
      ]),
      br(),

      h2('Gestao de Atendimento (ja funciona)'),
      makeTable(['Funcionalidade', 'Estado', 'Valor pro CRM'], [
        ['Inbox por canal com routing automatico', 'OK', 'Cada canal e um inbox: KLaOS Cobranca, Suporte, Vendas'],
        ['Atribuicao a agentes e times', 'OK', 'Handoff IA>humano, escalonamento por tag/prioridade'],
        ['SLA Policies', 'OK', 'Medir tempo de resposta por tipo de atendimento'],
        ['CSAT Surveys', 'OK', 'Health score do cliente como input pro CRM'],
        ['Automacao de conversas (85+ condicoes, 16 acoes)', 'OK', 'Tags automaticas, escalonamento, notificacoes'],
        ['Labels/Tags com cores', 'OK', 'Status de cobranca, tipo de cliente, prioridade'],
        ['Macros (sequencia de acoes)', 'OK', 'Operacoes repetitivas padronizadas'],
        ['Notas em contatos', 'OK', 'Contexto que alimenta o CRM'],
        ['Campaigns (one-off e ongoing)', 'OK', 'Mensagens em massa para base de contatos'],
        ['Agent Bots (IA do KLaOS)', 'OK', 'Agentes KLaOS respondendo no Frontdesk'],
        ['Captain (IA nativa Chatwoot)', 'OK', 'Sugestoes de resposta, knowledge base'],
      ]),
      br(),

      h2('Pendencias Tecnicas do Frontdesk'),
      makeTable(['Pendencia', 'Impacto', 'Status'], [
        ['QR code Evolution sem auto-refresh/polling', 'UX ruim ao conectar WhatsApp nao-oficial', 'Registrada em memoria'],
        ['Evolution cleanup incompleto on delete', 'Instancias orfas na Evolution API', 'Registrada em memoria'],
        ['Webhook setup na criacao de instancia Evolution', 'Instancias sem webhook = msgs perdidas', 'Registrada em memoria'],
        ['Billing Templates v2 (5 vars + 2 botoes)', 'Templates no Meta ainda em v1', 'Rake task pronta, falta editar no Meta'],
        ['Bridge CRM: sidebar com dados do deal', 'Agente nao ve contexto do deal na conversa', 'Nao implementado'],
        ['Bridge CRM: criar deal a partir de conversa', 'Fluxo manual, deveria ser automatico/1-click', 'Config existe, fluxo incompleto'],
      ]),

      // ============================================
      // PLANO DE ACAO
      // ============================================
      h1('PLANO DE ACAO CONSOLIDADO'),
      br(),

      h2('KLAOS — Backend/Supabase (20 itens)'),
      br(),

      h3('Prioridade ALTA — Sprints 0-2'),
      bullet('1. RBAC: Adicionar role "Viewer" e "Manager" no workspace_members'),
      bullet('2. crm_custom_field_definitions: tabela de definicao de campos (entity_type, name, slug, field_type, options, is_required, display_order)'),
      bullet('3. crm_stages: adicionar campo rotting_days para calcular deals em risco'),
      bullet('4. crm_stages: adicionar campo automation_triggers (JSONB) para triggers por estagio'),
      bullet('5. bi_crm_deals: adicionar campo forecast_category (commit/best_case/pipeline/omit)'),
      bullet('6. bi_crm_deals: adicionar campo win_score (probabilidade ML)'),
      bullet('7. bi_crm_deals: adicionar campo lost_reason'),
      bullet('8. bi_crm_deals: adicionar campo source_id (ref a lead_touchpoints)'),
      bullet('9. crm_deal_activities: expandir tipos (call/email/meeting/note/task/visit) com duration_min, outcome, ai_generated'),
      br(),

      h3('Prioridade MEDIA — Sprints 3-5'),
      bullet('10. Tabela crm_goals: metas por rep/time/periodo com target_value e currency'),
      bullet('11. Tabela crm_triggers: motor de automacao CRM (event_type, conditions, actions, execution_log)'),
      bullet('12. Tabela crm_events: Event Store imutavel dedicado para CRM (type, payload, actor_id, timestamp)'),
      bullet('13. Endpoint de importacao CSV com validacao e deteccao de duplicatas'),
      bullet('14. Service de deteccao de duplicatas por email/CNPJ/domain com sugestao de merge'),
      bullet('15. Deal notes: notas internas vinculadas a deals (nao so a leads)'),
      br(),

      h3('Prioridade BAIXA — Sprints 6-12'),
      bullet('16. Enrichment Agent: consulta CNPJ.ws, LinkedIn, Clearbit ao criar lead/empresa'),
      bullet('17. Task Agent CRM: gera tarefas automaticas com ai_reason baseado em contexto do deal'),
      bullet('18. Forecast ML model: win_score baseado em historico de deals fechados'),
      bullet('19. Communication Agent para vendas: nurturing sequences alem de cobranca'),
      bullet('20. BI Chat Agent CRM: agent que responde perguntas sobre pipeline/vendas'),
      br(),

      h2('FRONTDESK — custom/ (6 itens)'),
      br(),

      h3('Prioridade ALTA — Melhorar integracao com KLaOS'),
      bullet('1. Bridge CRM: exibir dados do deal do KLaOS na sidebar da conversa'),
      bullet2('Chamar API KLaOS para buscar deal associado ao contato'),
      bullet2('Mostrar: nome do deal, valor, estagio, lead score, owner'),
      bullet('2. Bridge CRM: botao "Criar Deal" na conversa que chama KLaOS API'),
      bullet('3. Bridge CRM: sync de status — conversa resolved > webhook > atualizar deal no KLaOS'),
      br(),

      h3('Prioridade MEDIA — Pendencias tecnicas'),
      bullet('4. WhatsApp Evolution: QR code com auto-refresh, polling de status, countdown visual'),
      bullet('5. WhatsApp Evolution: cleanup completo on delete (logout + disable chatwoot + delete instance)'),
      bullet('6. WhatsApp Evolution: webhook setup correto na criacao de instancia'),
      br(),

      // === RESUMO EXECUTIVO ===
      h1('Resumo Executivo'),
      br(),
      makeTable(['Sprint PRD', '% Ecossistema', 'KLaOS', 'Frontdesk', 'Maior Gap'], [
        ['0 - Fundacao', '~80%', 'Event Store CRM, RBAC', '-', 'Event Store dedicado'],
        ['1 - Core Entities', '~60%', 'CustomField defs, CSV, duplicatas', 'Sync contatos OK', 'Importacao CSV'],
        ['2 - Pipeline & Kanban', '~40%', 'Rotting, validar frontend', '-', 'Rotting indicator'],
        ['3 - Atividades & Timeline', '~35%', 'Activity types, deal notes', 'Gera eventos via webhook', 'Email tracking'],
        ['4 - Forecast & Reports v1', '~15%', 'Metas, dashboard, export', 'CSAT/SLA como input', 'Tabela de metas'],
        ['5 - Automacoes & Triggers', '~10%', 'Trigger builder CRM inteiro', 'AutomationRule de conversas OK', 'Trigger builder CRM'],
        ['6 - AI Agents Fase 1', '~25%', 'Enrichment, Task Agent CRM', 'Agent Bot bridge OK', 'Enrichment Agent'],
        ['7 - Integracao', '~40%', 'MQL sync, RevOps 360', 'Bridge, health score input', 'CS health score'],
        ['8 - Forecast Preditivo', '~5%', 'ML model inteiro', '-', 'Win Score ML'],
        ['9 - Communication Agent', '~30%', 'Nurturing vendas, A/B', 'Canais de entrega OK', 'Sequencias de vendas'],
        ['10 - BI Dashboard', '~20%', 'Paineis RevOps', 'Metricas CS como input', 'Dashboard completo'],
        ['11 - BI Chat Agent', '~15%', 'Agent CRM dedicado', '-', 'Agent BI CRM'],
        ['12 - Auto-Gestao', '~10%', 'Deal routing, optimizer', '-', 'Deal routing'],
      ]),
      br(),

      // === CONCLUSAO ===
      h1('Conclusao'),
      br(),
      new Paragraph({ spacing: { after: 200 }, shading: { type: ShadingType.SOLID, color: 'e8f5e9' }, children: [
        new TextRun({ text: 'O ecossistema KLaOS + Frontdesk esta bem estruturado. O KLaOS concentra CRM, IA, analytics e orquestracao (~95% do PRD). O Frontdesk concentra atendimento, canais de comunicacao e gestao de conversas — e o ponto de contato real com o cliente. Os dois se integram via webhooks, agent bots e API. O gap principal nao e de arquitetura (que esta correta), mas de implementacao: automacoes CRM, forecast preditivo, e agentes especializados ainda nao foram construidos no KLaOS.', bold: true, italics: true, size: 21 }),
      ]}),
      br(),

      h2('Divisao de Responsabilidades Final'),
      makeTable(['Area', 'KLaOS', 'Frontdesk'], [
        ['CRM (Deals, Pipeline, Kanban)', 'Dono', '-'],
        ['Contatos/Leads', 'Dono (CRM)', 'Dono (conversa) + sync'],
        ['Agentes IA', 'Dono (cerebro)', 'Canal (Agent Bot)'],
        ['WhatsApp', 'Orquestrador (decide o que enviar)', 'Executor (Connection Pool, entrega)'],
        ['Automacoes', 'CRM triggers (deals, tarefas)', 'Conversation triggers (tags, routing)'],
        ['Analytics/BI', 'Dono (dashboard, forecast)', 'Fonte de dados (CSAT, SLA, tempos)'],
        ['Atendimento ao Cliente', '-', 'Dono (inbox, agentes humanos, SLA)'],
        ['Cobranca', 'Orquestrador (campanhas)', 'Canal (WhatsApp) + tags + handoff'],
        ['Comunicacao (email, msg)', 'Decide', 'Entrega'],
      ]),
    ],
  }],
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync('C:/dev/gmb/frontdesk/ANALISE_PRD_CRM_VS_ESTADO_ATUAL.docx', buffer);
  console.log('Word gerado: ANALISE_PRD_CRM_VS_ESTADO_ATUAL.docx');
});
