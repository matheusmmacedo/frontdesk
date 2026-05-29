const { Client } = require('pg');
const URL = process.env.DB_URL;

const bodyOf = tpl => {
  const c = (tpl.components || []).find(x => String(x.type).toUpperCase() === 'BODY');
  return c ? (c.text || '') : '';
};
const footerOf = tpl => {
  const c = (tpl.components || []).find(x => String(x.type).toUpperCase() === 'FOOTER');
  return c ? (c.text || '') : '';
};
const btnsOf = tpl => {
  const c = (tpl.components || []).find(x => String(x.type).toUpperCase() === 'BUTTONS');
  return c ? (c.buttons || []).map(b => `${b.type}:${b.text}${b.url ? '('+b.url+')' : ''}`).join(' | ') : '';
};
const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  const r = await c.query(`SELECT jsonb_array_elements(message_templates) AS tpl FROM channel_whatsapp WHERE account_id=9 LIMIT 500`);
  const tpls = r.rows.map(x => x.tpl);
  console.log('TOTAL templates:', tpls.length, '\n');

  // 1) Templates com e-mail
  console.log('=== TEMPLATES COM E-MAIL ===');
  tpls.forEach(t => {
    const all = [bodyOf(t), footerOf(t), btnsOf(t)].join(' ');
    if (EMAIL_RE.test(all)) {
      const m = all.match(EMAIL_RE);
      console.log(`- ${t.name} (${t.language}) [${t.status}] email=${m[0]}`);
    }
  });

  // 2) Templates de 5 dias (lembrete)
  console.log('\n=== TEMPLATES "5 DIAS" / LEMBRETE ===');
  tpls.filter(t => /d5|5dias|5_dias|lembrete/i.test(t.name)).forEach(t => {
    console.log(`\n#### ${t.name} (${t.language}) [${t.status}] cat=${t.category}`);
    console.log('BODY:\n' + bodyOf(t));
    const f = footerOf(t); if (f) console.log('FOOTER: ' + f);
    const b = btnsOf(t); if (b) console.log('BUTTONS: ' + b);
  });

  // 3) Lista geral (nome/status/cat) pra mapear card vs boleto
  console.log('\n=== TODOS (nome | lang | status | cat | tem_email | tem_botao) ===');
  tpls.forEach(t => {
    const all = [bodyOf(t), footerOf(t), btnsOf(t)].join(' ');
    console.log(`${t.name} | ${t.language} | ${t.status} | ${t.category} | ${EMAIL_RE.test(all) ? 'EMAIL' : '-'} | ${btnsOf(t) ? 'btn' : '-'}`);
  });

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
