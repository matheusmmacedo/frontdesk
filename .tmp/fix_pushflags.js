const { Client } = require('pg');
const URL = process.env.DB_URL;
const IDS = process.env.IDS.split(',').map(Number);
// 1 creation + 2 assignment + 4 assigned_new_message + 8 mention + 16 participating_new_message = 31
const PUSH = 31;
const EMAIL = 31;
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  console.log('ANTES:');
  console.log(JSON.stringify((await c.query('SELECT user_id, email_flags, push_flags FROM notification_settings WHERE user_id = ANY($1) ORDER BY user_id', [IDS])).rows));
  const r = await c.query('UPDATE notification_settings SET push_flags=$2, email_flags=$3, updated_at=now() WHERE user_id = ANY($1)', [IDS, PUSH, EMAIL]);
  console.log('linhas atualizadas:', r.rowCount);
  console.log('DEPOIS:');
  console.log(JSON.stringify((await c.query('SELECT user_id, email_flags, push_flags FROM notification_settings WHERE user_id = ANY($1) ORDER BY user_id', [IDS])).rows));
  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
