const { Client } = require('pg');
const URL = process.env.DB_URL;
const SP = `to_char(((m.created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI')`;
const FT = { 0: 'image', 1: 'audio', 2: 'video', 3: 'file' };
const ST = { 0: 'sent', 1: 'delivered', 2: 'read', 3: 'FAILED' };
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  console.log('agora SP:', (await c.query("SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI') t")).rows[0].t);
  console.log('\n=== Yasmin (sender 14) últimas 18 msgs de saída ===');
  const r = await c.query(`
    SELECT m.id, m.status, ${SP} sp, a.file_type, m.content_attributes::text ca, left(m.content,25) txt
    FROM messages m LEFT JOIN attachments a ON a.message_id=m.id
    WHERE m.account_id=9 AND m.sender_id=14 AND m.sender_type='User'
    ORDER BY m.id DESC LIMIT 18`);
  r.rows.forEach(m => {
    const t = m.file_type != null ? FT[m.file_type] : 'texto';
    const st = ST[m.status] || m.status;
    console.log(`id=${m.id} ${m.sp} ${String(t).padEnd(6)} status=${st}${m.status === 3 ? (' ERR=' + (m.ca || '')) : ''}`);
  });
  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
