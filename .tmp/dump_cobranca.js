const { Client } = require('pg');
const URL = process.env.DB_URL;
const NAMES = [
  'cobr_d5_lembrete','cobr_d0_vencimento','cobr_d1_vencido','cobr_d7_atraso','cobr_d15_atraso',
  'cobr_card_d5_lembrete','cobr_card_d0_vencimento','cobr_card_d1_recusado','cobr_card_d7_atraso_v2','cobr_card_d15_atraso_v2'
];
const comp = (tpl, type) => (tpl.components || []).find(x => String(x.type).toUpperCase() === type);
const bodyOf = t => (comp(t,'BODY')||{}).text || '';
const footerOf = t => (comp(t,'FOOTER')||{}).text || '';
const btnsOf = t => ((comp(t,'BUTTONS')||{}).buttons || []).map(b => `${b.type}: "${b.text}"${b.url?(' -> '+b.url):''}`);

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  const r = await c.query(`SELECT jsonb_array_elements(message_templates) AS tpl FROM channel_whatsapp WHERE account_id=9 LIMIT 500`);
  const byName = {};
  r.rows.map(x => x.tpl).forEach(t => { byName[t.name] = t; });
  NAMES.forEach(n => {
    const t = byName[n];
    if (!t) { console.log(`\n##### ${n} — NÃO ENCONTRADO`); return; }
    console.log(`\n##### ${n} (${t.language}) [${t.status}] cat=${t.category}`);
    console.log('--- BODY ---');
    console.log(JSON.stringify(bodyOf(t))); // JSON pra ver \n e asteriscos exatos
    const f = footerOf(t); if (f) console.log('--- FOOTER ---\n' + JSON.stringify(f));
    const b = btnsOf(t); if (b.length) console.log('--- BUTTONS ---\n' + b.join('\n'));
  });
  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
