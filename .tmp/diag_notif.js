const { Client } = require('pg');
const URL = process.env.DB_URL;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== VAPID / WEB PUSH config (installation_configs) ===');
  const cfg = await c.query(`
    SELECT name,
           CASE WHEN serialized_value IS NULL THEN 'NULL'
                ELSE left(serialized_value::text, 60) END AS val
    FROM installation_configs
    WHERE name ILIKE '%VAPID%' OR name ILIKE '%PUSH%' OR name ILIKE '%FCM%'
    ORDER BY name`);
  console.log(cfg.rows.length ? JSON.stringify(cfg.rows, null, 2) : '(nenhuma config VAPID/PUSH encontrada!)');

  console.log('\n=== USERS Gustavo/Marta/Yasmin: audio (ui_settings) ===');
  const u = await c.query(`
    SELECT id, name,
           ui_settings->>'enable_audio_alerts' AS audio,
           ui_settings->>'always_play_audio_alert' AS always_play,
           ui_settings->>'notification_tone' AS tone
    FROM users
    WHERE LOWER(name) LIKE '%gustavo%' OR LOWER(name) LIKE '%marta%' OR LOWER(name) LIKE '%yasmin%'
    ORDER BY name`);
  console.log(JSON.stringify(u.rows, null, 2));
  const uids = u.rows.map(r => r.id);

  console.log('\n=== notification_settings (flags push/email) desses users ===');
  const ns = await c.query(`
    SELECT user_id, account_id, selected_email_flags, selected_push_flags
    FROM notification_settings WHERE user_id = ANY($1) ORDER BY user_id`, [uids]);
  console.log(JSON.stringify(ns.rows, null, 2));

  console.log('\n=== notification_subscriptions (push subscriptions) desses users ===');
  const sub = await c.query(`
    SELECT user_id, subscription_type,
           to_char(created_at,'YYYY-MM-DD HH24:MI') AS criado
    FROM notification_subscriptions WHERE user_id = ANY($1) ORDER BY user_id`, [uids]);
  console.log(sub.rows.length ? JSON.stringify(sub.rows, null, 2) : '(NENHUMA subscription de push pra esses users!)');

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
