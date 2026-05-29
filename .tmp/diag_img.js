const { Client } = require('pg');
const URL = process.env.DB_URL;
const SP = `to_char(((m.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI')`;
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  console.log('agora SP:', (await c.query("SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI') t")).rows[0].t);

  console.log('\n=== imagens enviadas (file_type 0) conta 9, últimas 8h: status + erro ===');
  const r = await c.query(`
    SELECT m.id, m.conversation_id, m.sender_id, m.status, ${SP} sp,
           m.content_attributes::text ca, ab.content_type, ab.byte_size
    FROM messages m
    JOIN attachments a ON a.message_id=m.id
    JOIN active_storage_attachments asa ON asa.record_type='Attachment' AND asa.record_id=a.id
    JOIN active_storage_blobs ab ON ab.id=asa.blob_id
    WHERE m.account_id=9 AND m.message_type=1 AND a.file_type=0 AND m.created_at > now()-interval '8 hours'
    ORDER BY m.id DESC LIMIT 25`);
  console.log('total:', r.rows.length);
  r.rows.forEach(m => {
    const st = { 0:'sent',1:'delivered',2:'read',3:'FAILED' }[m.status] || m.status;
    console.log(`id=${m.id} ${m.sp} ${m.content_type} ${Math.round(m.byte_size/1024)}KB status=${st}${m.status===3?(' ERR='+m.ca):''}`);
  });

  console.log('\n=== distribuição status imagem últimas 8h ===');
  console.log(JSON.stringify((await c.query(`
    SELECT m.status, count(*) FROM messages m JOIN attachments a ON a.message_id=m.id
    WHERE m.account_id=9 AND m.message_type=1 AND a.file_type=0 AND m.created_at>now()-interval '8 hours'
    GROUP BY m.status ORDER BY m.status`)).rows, null, 2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
