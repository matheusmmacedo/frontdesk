const { Client } = require('pg');
const URL = process.env.DB_URL;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== QUEM É A LARA (users) ===');
  const lu = await c.query(`
    SELECT id, name, email, type, confirmed_at,
           ui_settings->'enable_audio_alerts' AS audio
    FROM users WHERE LOWER(name) LIKE '%lara%' OR LOWER(email) LIKE '%lara%' ORDER BY id;`);
  console.log(JSON.stringify(lu.rows, null, 2));

  console.log('\n=== AGENT BOTS (lara pode ser bot) ===');
  const ab = await c.query(`SELECT id, name, account_id, bot_type FROM agent_bots ORDER BY id;`);
  console.log(JSON.stringify(ab.rows, null, 2));

  console.log('\n=== ÚLTIMAS 25 MENSAGENS (fluxo / buraco da queda) ===');
  const m = await c.query(`
    SELECT id, conversation_id, account_id, message_type, sender_type,
           to_char(created_at AT TIME ZONE 'America/Sao_Paulo','YYYY-MM-DD HH24:MI:SS') AS criada
    FROM messages ORDER BY id DESC LIMIT 25;`);
  console.log(JSON.stringify(m.rows, null, 2));

  console.log('\n=== CONTAGEM POR HORA (últimas 6h, SP) ===');
  const h = await c.query(`
    SELECT to_char(date_trunc('hour', created_at AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:00') AS hora,
           count(*) FILTER (WHERE message_type=0) AS entrada,
           count(*) FILTER (WHERE message_type=1) AS saida,
           count(*) AS total
    FROM messages
    WHERE created_at > now() - interval '6 hours'
    GROUP BY 1 ORDER BY 1;`);
  console.log(JSON.stringify(h.rows, null, 2));

  console.log('\n=== SERVER TIME ===');
  const t = await c.query(`SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','YYYY-MM-DD HH24:MI:SS') AS agora_sp;`);
  console.log(JSON.stringify(t.rows, null, 2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
