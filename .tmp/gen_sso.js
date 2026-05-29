const https = require('https');
const net = require('net');
const crypto = require('crypto');

const RW_TOKEN = '0d392ab4-0de0-4a4a-a73b-4bb03fc5c8bb';
const PROD_REDIS_SVC = 'cdd1490c-4e3d-4472-93d0-31807cd8ce51';
const PROD_ENV = '4071f2be-9abe-4b7e-a20d-f9783725b993';
const PROJECT = 'ab30ff6b-0598-4abd-9e3f-f6ffcba0636e';
const REDIS_HOST = 'nozomi.proxy.rlwy.net';
const REDIS_PORT = 38206;
const USER_ID = 12; // Gustavo prod
const EMAIL = 'gustavooliveiranetwork@gmail.com';

function gql(query, variables) {
  return new Promise((res, rej) => {
    const payload = JSON.stringify({ query, variables });
    const req = https.request({ hostname: 'backboard.railway.app', path: '/graphql/v2', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload), Authorization: `Bearer ${RW_TOKEN}` } },
      r => { let b=''; r.on('data',d=>b+=d); r.on('end',()=>res(b)); });
    req.on('error', rej); req.write(payload); req.end();
  });
}

async function main() {
  // 1. senha do redis prod
  const q = 'query($pid:String!,$eid:String!,$sid:String!){variables(projectId:$pid,environmentId:$eid,serviceId:$sid)}';
  const raw = await gql(q, { pid: PROJECT, eid: PROD_ENV, sid: PROD_REDIS_SVC });
  const vars = JSON.parse(raw).data.variables;
  const url = vars.REDIS_URL || vars.REDIS_PUBLIC_URL || '';
  const pw = (String(url).match(/default:([^@]+)@/) || [])[1];
  if (!pw) { console.log('sem senha redis. vars:', Object.keys(vars).join(',')); process.exit(1); }
  console.log('senha redis prod:', pw.slice(0, 4) + '***');

  const token = crypto.randomBytes(32).toString('hex');
  const key = `alfred:USER_SSO_AUTH_TOKEN::${USER_ID}::${token}`;

  // 2. conecta, AUTH, SCAN (confirma namespace), SETEX
  const s = net.connect(REDIS_PORT, REDIS_HOST);
  let buf = '';
  s.setTimeout(10000);
  s.on('connect', () => {
    s.write(`AUTH default ${pw}\r\n`);
    s.write('SCAN 0 MATCH alfred:* COUNT 15\r\n');
    s.write(`SETEX ${key} 300 true\r\n`);
    s.write(`GET ${key}\r\n`);
  });
  s.on('data', d => {
    buf += d.toString();
    // espera ver a resposta do GET (último comando). Heurística: 4 respostas.
    if (buf.includes('true') && buf.match(/\+OK/g) && buf.match(/\+OK/g).length >= 2) {
      console.log('--- RESP cru ---');
      console.log(buf);
      console.log('--- TOKEN ---');
      console.log(token);
      console.log('--- LOGIN URL ---');
      console.log(`https://app-desk.klaos.ai/app/login?email=${encodeURIComponent(EMAIL)}&sso_auth_token=${token}`);
      s.end();
    }
  });
  s.on('timeout', () => { console.log('timeout. buf parcial:', buf); s.destroy(); });
  s.on('error', e => console.log('redis err:', e.message));
  s.on('close', () => process.exit(0));
}
main().catch(e => { console.error(e.message); process.exit(1); });
