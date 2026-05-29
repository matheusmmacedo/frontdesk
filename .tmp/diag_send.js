const { Client } = require('pg');
const URL = process.env.DB_URL;
const SP = `to_char(((m.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI')`;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('agora SP:', (await c.query("SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI') t")).rows[0].t);

  console.log('\n=== Yasmin (user 14): últimas msgs enviadas com anexo ===');
  const y = await c.query(`
    SELECT m.id, m.conversation_id, m.status, m.message_type,
           ${SP} AS sp, a.file_type,
           m.content_attributes->>'external_error' AS err,
           left(m.content,30) AS txt
    FROM messages m
    JOIN attachments a ON a.message_id = m.id
    WHERE m.account_id=9 AND m.sender_id=14 AND m.sender_type='User'
    ORDER BY m.id DESC LIMIT 20`);
  console.log(JSON.stringify(y.rows, null, 2));

  console.log('\n=== TODAS as msgs de saída com anexo que FALHARAM (status=3), conta 9, últimas 48h ===');
  const f = await c.query(`
    SELECT m.id, m.conversation_id, m.sender_id, ${SP} AS sp, a.file_type,
           m.content_attributes->>'external_error' AS err
    FROM messages m
    JOIN attachments a ON a.message_id = m.id
    WHERE m.account_id=9 AND m.message_type=1 AND m.status=3
      AND m.created_at > now() - interval '48 hours'
    ORDER BY m.id DESC LIMIT 25`);
  console.log('falhas:', f.rows.length);
  console.log(JSON.stringify(f.rows, null, 2));

  console.log('\n=== distribuição status de saída com anexo (últimas 48h) por file_type ===');
  const d = await c.query(`
    SELECT a.file_type, m.status, count(*)
    FROM messages m JOIN attachments a ON a.message_id=m.id
    WHERE m.account_id=9 AND m.message_type=1 AND m.created_at > now()-interval '48 hours'
    GROUP BY a.file_type, m.status ORDER BY a.file_type, m.status`);
  console.log(JSON.stringify(d.rows, null, 2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
