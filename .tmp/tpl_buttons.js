const { Client } = require('pg');
const URL = process.env.DB_URL;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== MSG TEMPLATE com template_params (account 9) — amostra ===');
  const m = await c.query(`
    SELECT id, conversation_id,
           additional_attributes->'template_params' AS tp
    FROM messages
    WHERE account_id=9 AND additional_attributes->'template_params' IS NOT NULL
    ORDER BY id DESC LIMIT 4`);
  console.log(JSON.stringify(m.rows, null, 2));

  console.log('\n=== DEFINICAO de templates com BUTTONS no canal (account 9) ===');
  const t = await c.query(`SELECT jsonb_array_elements(message_templates) AS tpl FROM channel_whatsapp WHERE account_id=9 LIMIT 300`);
  const isButtons = comp => String(comp.type || '').toUpperCase() === 'BUTTONS';
  const withBtns = t.rows.map(r => r.tpl).filter(tpl => (tpl.components || []).some(isButtons));
  console.log('total templates com BUTTONS:', withBtns.length);
  withBtns.slice(0, 6).forEach(tpl => {
    const b = (tpl.components || []).find(isButtons);
    console.log(`\n-- ${tpl.name} (${tpl.language}) --`);
    console.log(JSON.stringify(b.buttons, null, 2));
  });

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
