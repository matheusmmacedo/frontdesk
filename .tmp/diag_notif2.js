const { Client } = require('pg');
const URL = process.env.DB_URL;
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();
  console.log('=== colunas notification_settings ===');
  console.log((await c.query("SELECT column_name FROM information_schema.columns WHERE table_name='notification_settings' ORDER BY ordinal_position")).rows.map(r => r.column_name).join(', '));
  console.log('\n=== colunas notification_subscriptions ===');
  console.log((await c.query("SELECT column_name FROM information_schema.columns WHERE table_name='notification_subscriptions' ORDER BY ordinal_position")).rows.map(r => r.column_name).join(', '));
  console.log('\n=== flags dos 3 users (12,13,14) ===');
  console.log(JSON.stringify((await c.query('SELECT user_id, account_id, email_flags, push_flags FROM notification_settings WHERE user_id IN (12,13,14) ORDER BY user_id')).rows, null, 2));
  console.log('\n=== subscriptions push dos 3 users ===');
  const s = await c.query("SELECT user_id, subscription_type, to_char(created_at,'MM-DD HH24:MI') AS criado FROM notification_subscriptions WHERE user_id IN (12,13,14) ORDER BY user_id");
  console.log(s.rows.length ? JSON.stringify(s.rows, null, 2) : '(NENHUMA subscription push pra 12/13/14!)');
  console.log('\n=== TOTAL subscriptions push na conta toda ===');
  console.log(JSON.stringify((await c.query('SELECT subscription_type, count(*) FROM notification_subscriptions GROUP BY subscription_type')).rows, null, 2));
  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
