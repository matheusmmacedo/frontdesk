const { Client } = require('pg');

const URL = process.env.DB_URL;
const SSL = process.env.SSL_MODE;

async function tryConnect(sslOpt, label) {
  const cfg = { connectionString: URL, connectionTimeoutMillis: 10000 };
  if (sslOpt) cfg.ssl = sslOpt;
  const c = new Client(cfg);
  try {
    await c.connect();
    const res = await c.query(`
      SELECT id, name, email,
             ui_settings->'enable_audio_alerts' AS enable_audio_alerts,
             ui_settings->'always_play_audio_alert' AS always_play,
             ui_settings->'alert_if_unread_assigned_conversation_exist' AS alert_unread,
             ui_settings->'notification_tone' AS tone
      FROM users
      WHERE LOWER(name) LIKE '%gustavo%'
         OR LOWER(name) LIKE '%marta%'
         OR LOWER(name) LIKE '%yasmin%'
         OR LOWER(email) LIKE '%gustavo%'
         OR LOWER(email) LIKE '%marta%'
         OR LOWER(email) LIKE '%yasmin%'
      ORDER BY name;
    `);
    console.log('CONNECTED via', label);
    console.log(JSON.stringify(res.rows, null, 2));
    await c.end();
    return true;
  } catch (e) {
    console.log('FAILED', label, '->', e.message);
    try { await c.end(); } catch (_) {}
    return false;
  }
}

async function main() {
  if (await tryConnect(false, 'no-ssl')) return;
  if (await tryConnect({ rejectUnauthorized: false }, 'ssl-insecure')) return;
  process.exit(1);
}
main();
