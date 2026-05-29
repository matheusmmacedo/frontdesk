const { Client } = require('pg');
const URL = process.env.DB_URL;
const NUM = '964798660'; // fragmento estável do +5521964798660
const SP = `to_char(((created_at AT TIME ZONE 'UTC') AT TIME ZONE 'America/Sao_Paulo'),'MM-DD HH24:MI:SS')`;

async function main() {
  const c = new Client({ connectionString: URL, connectionTimeoutMillis: 15000 });
  await c.connect();

  console.log('AGORA SP:', (await c.query(`SELECT to_char(now() AT TIME ZONE 'America/Sao_Paulo','MM-DD HH24:MI:SS') t`)).rows[0].t);

  console.log('\n=== CONTATO com esse numero (qualquer conta) ===');
  const ct = await c.query(`
    SELECT id, account_id, name, phone_number, identifier,
           to_char(created_at,'YYYY-MM-DD HH24:MI') AS criado_utc
    FROM contacts
    WHERE phone_number LIKE '%${NUM}%' OR identifier LIKE '%${NUM}%' OR name LIKE '%${NUM}%'
    ORDER BY id DESC;`);
  console.log(JSON.stringify(ct.rows, null, 2));

  let contactIds = ct.rows.map(r => r.id);

  console.log('\n=== ÚLTIMAS 20 MENSAGENS conta 9 (qualquer, pra ver se o ola chegou) ===');
  console.log(JSON.stringify((await c.query(`
    SELECT id, conversation_id, message_type, sender_type, ${SP} sp, left(content,50) trecho
    FROM messages WHERE account_id=9 ORDER BY id DESC LIMIT 20`)).rows, null, 2));

  if (contactIds.length) {
    console.log('\n=== CONVERSAS desse(s) contato(s) ===');
    console.log(JSON.stringify((await c.query(`
      SELECT id, display_id, account_id, inbox_id, status, contact_id, assignee_id,
             to_char(created_at,'MM-DD HH24:MI') c_utc, to_char(updated_at,'MM-DD HH24:MI') u_utc
      FROM conversations WHERE contact_id = ANY($1) ORDER BY id DESC`, [contactIds])).rows, null, 2));

    console.log('\n=== MENSAGENS desse(s) contato(s) (via conversation) ===');
    console.log(JSON.stringify((await c.query(`
      SELECT m.id, m.conversation_id, m.message_type, m.sender_type, ${SP.replace(/created_at/g,'m.created_at')} sp, left(m.content,60) trecho
      FROM messages m
      JOIN conversations cv ON cv.id=m.conversation_id
      WHERE cv.contact_id = ANY($1) ORDER BY m.id DESC LIMIT 20`, [contactIds])).rows, null, 2));
  }

  await c.end();
}
main().catch(e => { console.error(e.message); process.exit(1); });
