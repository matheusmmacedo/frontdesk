const { Client } = require('pg');
const URL = process.env.DB_URL;
async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('=== AGENT BOT LARA (id 14) config completa ===');
  console.log(JSON.stringify((await c.query(`SELECT * FROM agent_bots WHERE id=14`)).rows, null, 2));

  console.log('\n=== INBOX 19 (conta 9) — qual bot/canal ===');
  console.log(JSON.stringify((await c.query(`SELECT id, name, channel_type, channel_id, enable_auto_assignment FROM inboxes WHERE id=19`)).rows, null, 2));

  console.log('\n=== agent_bot_inboxes (qual bot atende qual inbox na conta 9) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT abi.id, abi.inbox_id, abi.agent_bot_id, ab.name bot, i.name inbox
    FROM agent_bot_inboxes abi
    JOIN agent_bots ab ON ab.id=abi.agent_bot_id
    JOIN inboxes i ON i.id=abi.inbox_id
    WHERE i.account_id=9`)).rows, null, 2));

  console.log('\n=== STATUS das conversas testadas (908, 910) e a que respondeu (494) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT display_id, id, status, contact_id, assignee_id, inbox_id,
           to_char(updated_at,'HH24:MI:SS') u_utc
    FROM conversations WHERE id IN (908,910) OR display_id IN (494,908,910) ORDER BY id`)).rows, null, 2));

  console.log('\n=== conv 908: ultimas msgs ===');
  console.log(JSON.stringify((await c.query(`
    SELECT id, message_type, sender_type, to_char(((created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'HH24:MI:SS') sp, left(content,40) t
    FROM messages WHERE conversation_id=908 ORDER BY id DESC LIMIT 6`)).rows, null, 2));

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
