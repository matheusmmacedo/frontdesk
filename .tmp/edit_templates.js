// Editor de templates Meta — Mais Saúde (account 9, WABA Klaus).
// Dry-run por padrão. Só envia com: node edit_templates.js --send <name|all>
// Estratégia segura: pega os components ATUAIS do cache (espelho do Meta),
// troca SÓ o texto do BODY, mantém example/botões/estrutura. POST em /{id}.
const { Client } = require('pg');
const https = require('https');
const URL = process.env.DB_URL;
const GRAPH_VER = 'v21.0';
// Token de management documentado (Daniel Limeira, System User permanente).
const FALLBACK_TOKEN = 'EAAOFw8i5U5YBRHSZCIutGm4mpkHiZBuNr9XS71IqsQlJKQPs0FcK9KB5TCDIQPRCbCeRtfk1nCiafDjni0xNBQ2g10h50Wqv9YQtlOhkdYPsmMzaUqronCw7ZCMcsZB0XWkmv6i3JsWJ5wZADqfy49XhkhyHS3eEOmFEXCeGfvJiBVVNEkPN1hNwKraDZAMAZDZD';

// ---- NOVOS BODIES (aprovados) ----
const NEW_BODY = {
  cobr_d5_lembrete:
`Olá {{1}}!

Esta mensagem é apenas um lembrete de pagamento do boleto que vai vencer.
Sua fatura da MAIS SAÚDE 24 HORAS *vence no dia {{3}}*. O valor é de {{2}}.

Você pode realizar o pagamento *antes do vencimento*, assim evita esquecimento e evita multas e juros.
Desejamos uma excelente semana!

Código de barras do boleto:
{{4}}

*Para facilitar seu pagamento, você pode clicar no botão abaixo e copiar a chave PIX Copia e Cola.*

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_d0_vencimento:
`Olá {{1}}!
Sua fatura da MAIS SAÚDE 24 HORAS *vence hoje dia {{3}}. O valor de {{2}}.*

Realize *o pagamento antes do vencimento* para evitar multas e juros.

Código de barras do boleto:
{{4}}

*Para facilitar seu pagamento, você pode clicar no botão abaixo e copiar a chave PIX Copia e Cola.*

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_d1_vencido:
`*Boleto Vencido*

Olá {{1}}!
Queremos te avisar que *o boleto registrado em seu CPF venceu dia {{3}}* gerado pela MAIS SAÚDE 24 HORAS, no valor de {{2}}.

Realize o pagamento e regularize seu débito.

Código de barras do boleto:
{{4}}

*Para facilitar seu pagamento, você pode clicar no botão abaixo e copiar a chave PIX Copia e Cola.*

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_d7_atraso:
`Olá {{1}}!
Queremos te lembrar que a cobrança gerada pela MAIS SAÚDE 24 HORAS, *no valor de {{2}} venceu há 7 dias, no dia {{3}}.*

Lembrando que o boleto é registrado no banco e com a falta do pagamento o banco pode executar o título no SPC e em protesto.

Código de barras do boleto:
{{4}}

*Para facilitar seu pagamento, você pode clicar no botão abaixo e copiar a chave PIX Copia e Cola.*

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_d15_atraso:
`Olá, recebemos hoje um relatório do banco onde consta o seu nome na lista de inadimplentes, pois seu boleto ultrapassou o prazo permitido para pagamento.

Você consegue fazer o pagamento hoje ainda e enviar o comprovante?

*Caso não consiga, o banco vai executar o título além de SPC.*

Para isso não acontecer gentileza encaminhar comprovante.

Código de barras do boleto:
{{1}}

*Para facilitar seu pagamento, você pode clicar no botão abaixo e copiar a chave PIX Copia e Cola.*

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_card_d5_lembrete:
`Olá {{1}}!

Esta mensagem é apenas um lembrete da cobrança da sua mensalidade.
Sua mensalidade da MAIS SAÚDE 24 HORAS *vai ser cobrada no seu cartão de crédito no dia {{3}}*. O valor é de {{2}}.

Confirme que seus dados de pagamento estão atualizados clicando no botão abaixo.
Desejamos uma excelente semana!

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_card_d0_vencimento:
`Olá {{1}}!
Sua mensalidade da MAIS SAÚDE 24 HORAS *vai ser cobrada no cartão hoje, dia {{3}}. O valor de {{2}}.*

Caso prefira fazer o pagamento manualmente, use o link abaixo.

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_card_d1_recusado:
`*Pagamento Não Identificado*

Olá {{1}}!
Tentamos realizar a cobrança no seu cartão de crédito, mas *não conseguimos concluir o pagamento da mensalidade no valor de {{2}}* gerada pela MAIS SAÚDE 24 HORAS, com vencimento em {{3}}.

Atualize seus dados de pagamento ou faça uma nova tentativa pelo link abaixo.

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_card_d7_atraso_v2:
`Olá {{1}}!
Queremos te lembrar que *a sua mensalidade da MAIS SAÚDE 24 HORAS, no valor de {{2}}, está em aberto há 7 dias, com vencimento em {{3}}.*

Realize o pagamento pelo link abaixo para regularizar.

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,

  cobr_card_d15_atraso_v2:
`Olá, identificamos que sua mensalidade da MAIS SAÚDE 24 HORAS continua em aberto, mesmo após várias tentativas de cobrança no seu cartão de crédito.

*Caso o pagamento não seja regularizado, sua mensalidade pode ser registrada no SPC.*

Atualize seu pagamento pelo link abaixo.

Caso tenha alguma dúvida entre em contato neste WhatsApp
Telefone: (31) 98248-8131`,
};

const ORDER = Object.keys(NEW_BODY);

const countVars = s => { const m = s.match(/\{\{\s*\d+\s*\}\}/g) || []; return new Set(m.map(x => x.replace(/\D/g, ''))).size; };
const utf8ok = s => { const bad = (s.match(/�/g) || []).length; return { bad, bytes: Buffer.byteLength(s, 'utf8'), hasAccents: /[ãáâàéêíóôõúçÃ-Ü]/.test(s) }; };

function post(id, components, token) {
  const payload = JSON.stringify({ category: 'UTILITY', components });
  return new Promise(res => {
    const req = https.request({
      hostname: 'graph.facebook.com', path: `/${GRAPH_VER}/${id}`, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload), Authorization: `Bearer ${token}` },
    }, r => { let b = ''; r.on('data', d => b += d); r.on('end', () => res({ status: r.statusCode, body: b })); });
    req.on('error', e => res({ status: 0, body: e.message }));
    req.write(payload); req.end();
  });
}

async function main() {
  const args = process.argv.slice(2);
  const send = args.includes('--send');
  const targetArg = args[args.indexOf('--send') + 1];
  const targets = !send ? ORDER : (targetArg === 'all' || !targetArg ? ORDER : targetArg.split(','));

  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  const chRow = (await c.query(`SELECT provider_config FROM channel_whatsapp WHERE account_id=9 LIMIT 1`)).rows[0];
  const apiKey = chRow?.provider_config?.api_key;
  const token = apiKey || FALLBACK_TOKEN;
  const r = await c.query(`SELECT jsonb_array_elements(message_templates) AS tpl FROM channel_whatsapp WHERE account_id=9 LIMIT 500`);
  const byName = {}; r.rows.map(x => x.tpl).forEach(t => { byName[t.name] = t; });
  await c.end();

  console.log(send ? `>>> MODO ENVIO (--send) alvos: ${targets.join(', ')}` : '>>> DRY-RUN (nada enviado). Use --send <name|all> pra enviar.');
  console.log('token:', token === apiKey ? 'channel api_key' : 'Daniel fallback', '\n');

  for (const name of targets) {
    const tpl = byName[name];
    if (!tpl) { console.log(`!! ${name}: não encontrado`); continue; }
    const newText = NEW_BODY[name];
    const oldBody = (tpl.components || []).find(c => String(c.type).toUpperCase() === 'BODY');
    const oldVars = countVars(oldBody?.text || '');
    const newVars = countVars(newText);
    const u = utf8ok(newText);
    const components = (tpl.components || []).map(comp => {
      if (String(comp.type).toUpperCase() === 'BODY') return { ...comp, text: newText };
      return comp;
    });
    console.log(`#### ${name} (id ${tpl.id})`);
    console.log(`   vars: old=${oldVars} new=${newVars} ${oldVars === newVars ? 'OK' : '!!! DIFERENTE'} | utf8: bad=${u.bad} bytes=${u.bytes} accents=${u.hasAccents}`);
    if (u.bad > 0) { console.log('   !!! UTF-8 com caractere inválido — ABORTANDO esse'); continue; }
    if (oldVars !== newVars) { console.log('   !!! contagem de variáveis mudou — ABORTANDO esse'); continue; }
    if (!send) { console.log('   components a enviar:\n' + JSON.stringify(components).slice(0, 500) + '...'); continue; }
    const resp = await post(tpl.id, components, token);
    console.log(`   -> HTTP ${resp.status}: ${resp.body.slice(0, 300)}`);
  }
}
main().catch(e => { console.error(e.message); process.exit(1); });
