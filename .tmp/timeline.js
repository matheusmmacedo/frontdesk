const { Client } = require('pg');
const URL = process.env.DB_URL;
const SP = `((created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo')`;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== AGORA (UTC e SP) ===');
  console.log(JSON.stringify((await c.query(
    `SELECT to_char(now() AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS') utc,
            to_char(now() AT TIME ZONE 'America/Sao_Paulo','YYYY-MM-DD HH24:MI:SS') sp`)).rows,null,2));

  console.log('\n=== IDADE DA ÚLTIMA MENSAGEM (conta 9) ===');
  console.log(JSON.stringify((await c.query(
    `SELECT max(created_at) m, round(extract(epoch from (now()-max(created_at)))/60) AS min_atras
     FROM messages WHERE account_id=9`)).rows,null,2));

  console.log('\n=== MAIORES INTERVALOS ENTRE MENSAGENS (conta 9, últimas 12h) — acha o buraco da queda ===');
  console.log(JSON.stringify((await c.query(`
    WITH x AS (
      SELECT id, created_at,
             lag(created_at) OVER (ORDER BY created_at) AS prev
      FROM messages
      WHERE account_id=9 AND created_at > now() - interval '12 hours'
    )
    SELECT to_char(${SP.replace(/created_at/g,'prev')},'HH24:MI:SS') AS antes,
           to_char(${SP},'HH24:MI:SS') AS depois,
           round(extract(epoch from (created_at-prev))/60) AS gap_min
    FROM x WHERE prev IS NOT NULL
    ORDER BY (created_at-prev) DESC LIMIT 8`)).rows,null,2));

  console.log('\n=== ÚLTIMAS 12 RESPOSTAS DA LARA (AgentBot, conta 9) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT id, conversation_id,
           to_char(${SP},'MM-DD HH24:MI:SS') AS criada,
           left(content,60) AS trecho
    FROM messages
    WHERE account_id=9 AND sender_type='AgentBot' AND message_type=1
    ORDER BY id DESC LIMIT 12`)).rows,null,2));

  console.log('\n=== CONVERSAS ABERTAS NA CONTA 9 ONDE A ÚLTIMA MSG É DO CONTATO (esperando resposta) ===');
  console.log(JSON.stringify((await c.query(`
    WITH last_msg AS (
      SELECT DISTINCT ON (conversation_id) conversation_id, message_type, sender_type, created_at
      FROM messages WHERE account_id=9
      ORDER BY conversation_id, id DESC
    )
    SELECT conv.display_id, conv.status,
           to_char(((lm.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI:SS') AS ultima_msg,
           round(extract(epoch from (now()-lm.created_at))/60) AS min_atras
    FROM last_msg lm
    JOIN conversations conv ON conv.id = lm.conversation_id
    WHERE lm.message_type=0 AND conv.status=0
    ORDER BY lm.created_at DESC LIMIT 20`)).rows,null,2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
