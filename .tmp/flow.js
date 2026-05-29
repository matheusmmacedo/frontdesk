const { Client } = require('pg');
const URL = process.env.DB_URL;
const SP = `to_char(((created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI:SS')`;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== AGORA SP ===');
  console.log((await c.query(`SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI:SS') sp`)).rows[0].sp);

  console.log('\n=== ÚLTIMA MENSAGEM POR CONTA (SP) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT account_id,
           to_char((max(created_at) AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI:SS') AS ultima,
           round(extract(epoch from (now()-max(created_at)))/60) AS min_atras,
           count(*) FILTER (WHERE created_at > now()-interval '8 hours') AS msgs_8h
    FROM messages GROUP BY account_id ORDER BY account_id`)).rows,null,2));

  console.log('\n=== ÚLTIMAS 15 MENSAGENS DE ENTRADA (qualquer conta, message_type=0) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT id, account_id, conversation_id, ${SP} AS criada
    FROM messages WHERE message_type=0 ORDER BY id DESC LIMIT 15`)).rows,null,2));

  console.log('\n=== DISTRIBUIÇÃO POR HORA conta 9 (SP) últimas 10h ===');
  console.log(JSON.stringify((await c.query(`
    SELECT to_char(((date_trunc('hour', created_at) AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:00') AS hora,
           count(*) FILTER (WHERE message_type=0) entrada,
           count(*) FILTER (WHERE message_type=1) saida
    FROM messages WHERE account_id=9 AND created_at > now()-interval '10 hours'
    GROUP BY 1 ORDER BY 1`)).rows,null,2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
