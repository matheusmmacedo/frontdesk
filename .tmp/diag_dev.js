const { Client } = require('pg');
const URL = process.env.DB_URL;
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== VAPID public key presente? ===');
  const v = await c.query("SELECT serialized_value::text AS val FROM installation_configs WHERE name='VAPID_KEYS'");
  const raw = v.rows[0]?.val || '';
  console.log('tem public_key:', /public_key/.test(raw), '| tem private_key:', /private_key/.test(raw), '| len:', raw.length);

  console.log('\n=== users (gustavo/marta/yasmin) + audio ===');
  const u = await c.query(`SELECT id, name, ui_settings->>'enable_audio_alerts' audio FROM users WHERE LOWER(name) LIKE '%gustavo%' OR LOWER(name) LIKE '%marta%' OR LOWER(name) LIKE '%yasmin%' ORDER BY name`);
  console.log(JSON.stringify(u.rows, null, 2));
  const ids = u.rows.map(r => r.id);

  console.log('\n=== notification_settings flags ===');
  console.log(JSON.stringify((await c.query('SELECT user_id, account_id, email_flags, push_flags FROM notification_settings WHERE user_id = ANY($1) ORDER BY user_id', [ids])).rows, null, 2));

  console.log('\n=== subscriptions push (total na instância) ===');
  console.log(JSON.stringify((await c.query('SELECT subscription_type, count(*) FROM notification_subscriptions GROUP BY subscription_type')).rows, null, 2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
