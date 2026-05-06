# HANDOFF — Ativação da Lara em PROD (Mais Saúde 24h)

**Data**: 2026-05-06
**Origem**: agente Claude Code rodando em `C:\dev\gmb\frontdesk` (lado Frontdesk/Chatwoot)
**Destino**: agente Claude Code rodando no repo do **KLaOS** (lado api.klaos.ai)

---

## TL;DR

Lado Frontdesk PROD está **100% configurado**. Falta apenas o lado KLaOS rodar `DRY_RUN=0 npm run golive:lara` com as variáveis abaixo pra ativar a Lara em PROD acct=9 inbox=19. Webhooks já funcionam, outbound já funciona, inbound chega no Frontdesk e é encaminhado pro KLaOS. KLaOS PROD recebe POST e responde 200 OK silencioso (no-op) — porque o `bot_uuid` ainda não está mapeado no banco do KLaOS PROD.

---

## Estado atual (validado em 2026-05-06)

### ✅ Frontdesk PROD (este agente cuidou)

| Item | Estado |
|---|---|
| `account_id=9` Mais Saúde 24h | OK (58.223 contatos importados, 60 labels, 3 teams, 2 automation_rules desativadas) |
| `channel_whatsapp.id=1` | Criado (`+553184226006`, `whatsapp_cloud`, `source: whatsapp_pool`) |
| `inbox.id=19` "KLaOS Cobranca" | Criado (Channel::Whatsapp, timezone America/Sao_Paulo, working_hours 24h seg-dom) |
| `agent_bot.id=14` "Lara" | Linkado à inbox via `agent_bot_inboxes` |
| `inbox_members` | Gustavo (user_id=12) atribuído |
| Templates da WABA Klaus (17) | Sincronizados em `channel_whatsapp.message_templates` |
| Webhook Meta per-phone | `https://app-desk.klaos.ai/webhooks/whatsapp/+553184226006` |
| Webhook subscribe + verify_token | Funcionando (HTTP 200 + echo do challenge) |
| Cloud API register | OK (PIN 2FA `789123` aceito, `quality_rating=GREEN`) |
| Outbound smoke test | ✅ template `at_confirma_recebimento` entregue em `+5521964798660` |
| Inbound smoke test | ✅ "Oi" e "OK" recebidos, conversation 40 criada, Frontdesk POSTou pra Lara KLaOS PROD (200) |
| BRIDGE_SECRET alinhado | `JFve5UU5r7rGEBp/X8hJ+Aml+v2y1wKb+a022tvYUQR3rLVTEMOQyp/ukxKLj464` igual nos dois lados |
| Labels alinhados com DEV | 19 labels DEV todos existem em PROD com nomes idênticos (renames feitos: `mais_saúde→mais-saude`, `enviado_ao_spc→enviado-ao-spc`, `quer_cancelar→quer-cancelar`; criado `cancelado`) |

### ❌ KLaOS PROD (você precisa fazer)

| Item | Pendente |
|---|---|
| Mapping `bot_uuid → frontdesk_account_id, inbox_id, bot_token` | rodar `golive:lara` |
| Prompts da Lara em PROD | mesmo script |
| Validação rota SSO POST→GET | confirmar no código KLaOS (cosmético, não bloqueia mensagens) |
| Smoke E2E final | Matheus manda WhatsApp → Lara responde |

---

## IDs / tokens / variáveis — PROD

```bash
# Frontdesk PROD
ACCOUNT_ID_PROD=9
INBOX_ID_PROD=19
CHANNEL_WHATSAPP_ID_PROD=1
BOT_ID_PROD=14
BOT_UUID=1b092e03-9418-4352-956c-db0a560d904a              # mesmo UUID que DEV
BOT_TOKEN_PROD=HcugPKH5qZs8UF2Jng2iZfVt                     # access_tokens.token (owner_type=AgentBot, owner_id=14)
GUSTAVO_USER_ID_PROD=12

# Meta WhatsApp Cloud API (WABA Klaus, compartilhada DEV/PROD)
WABA_ID=735467396201142
PHONE_NUMBER_ID_PROD=1111100338751985
PHONE_NUMBER_PROD=+553184226006
PIN_2FA=789123                                              # já registrado via Cloud API

# Bridge / URLs PROD
FRONTDESK_PLATFORM_URL=https://app-desk.klaos.ai
KLAOS_BRIDGE_WEBHOOK_URL=https://api.klaos.ai/api/webhooks/klaos/bridge-event
LARA_OUTGOING_URL=https://api.klaos.ai/api/webhooks/agent-bot/1b092e03-9418-4352-956c-db0a560d904a

# Secrets bridge (alinhados em ambos os lados)
FRONTDESK_BRIDGE_SECRET=JFve5UU5r7rGEBp/X8hJ+Aml+v2y1wKb+a022tvYUQR3rLVTEMOQyp/ukxKLj464
FRONTDESK_WEBHOOK_SECRET=fIIPiPviJF5bPADrv87+yJf44FdcX1TSRpQ+aw8UTH8IuV5vA1QTYFfeP2Vqjjhr
WHATSAPP_VERIFY_TOKEN=10a96bba0053fd5938bdc6712e4827f4ea3b9e7c44931c465f0d5f0d61132a2d
PLATFORM_API_TOKEN=RKtVkDhrefSqLh5e1UQeZ7Kz

# Postgres Frontdesk PROD (read-only se quiser inspeção)
DATABASE_URL_PROD=postgresql://postgres:FfRUABvClzxlUIxywIeaPzLmeGiIqsWq@ballast.proxy.rlwy.net:42985/railway

# System User WhatsApp Cloud API (Daniel Limeira, full read+write em ambas WABAs do BM Atend Med BH)
META_TOKEN=EAAOFw8i5U5YBRHSZCIutGm4mpkHiZBuNr9XS71IqsQlJKQPs0FcK9KB5TCDIQPRCbCeRtfk1nCiafDjni0xNBQ2g10h50Wqv9YQtlOhkdYPsmMzaUqronCw7ZCMcsZB0XWkmv6i3JsWJ5wZADqfy49XhkhyHS3eEOmFEXCeGfvJiBVVNEkPN1hNwKraDZAMAZDZD
```

## IDs DEV (referência — NÃO modificar)

```bash
ACCOUNT_ID_DEV=10
INBOX_ID_DEV=30
CHANNEL_WHATSAPP_ID_DEV=5
BOT_ID_DEV=15                                               # nome "Lara | lara"
BOT_UUID=1b092e03-9418-4352-956c-db0a560d904a               # IDÊNTICO ao PROD (mesmo agent)
PHONE_NUMBER_ID_DEV=1088056767715946                        # +5531 9728-6773 Atend Med BH (DEV)
LARA_OUTGOING_URL_DEV=https://api-dev.klaos.ai/api/webhooks/chatwoot-bot/1b092e03-9418-4352-956c-db0a560d904a
```

⚠️ Nota: rota webhook em **DEV usa `chatwoot-bot`**, em **PROD usa `agent-bot`** (convenção moderna confirmada com o stakeholder, "Frontdesk" não menciona Chatwoot na UI).

---

## O que rodar — `golive:lara`

```bash
cd <repo-klaos>

DRY_RUN=0 \
ACCOUNT_ID_PROD=9 \
INBOX_ID_PROD=19 \
BOT_ID_PROD=14 \
BOT_UUID=1b092e03-9418-4352-956c-db0a560d904a \
BOT_TOKEN_PROD=HcugPKH5qZs8UF2Jng2iZfVt \
WABA_ID=735467396201142 \
PHONE_NUMBER_ID_PROD=1111100338751985 \
PHONE_NUMBER_PROD=+553184226006 \
FRONTDESK_PLATFORM_URL=https://app-desk.klaos.ai \
npm run golive:lara
```

Esse script deve popular o banco do KLaOS PROD com:

1. **Mapping** `bot_uuid → frontdesk_account_id, frontdesk_inbox_id, frontdesk_bot_token`
2. **Prompts da Lara** em PROD (clonar de DEV ou conteúdo padrão)
3. **Templates `waba_templates`** (17 templates já estão em `channel_whatsapp.message_templates` no Frontdesk PROD; o KLaOS pode puxar daí ou re-sincronizar)

---

## Validação esperada (smoke E2E)

### Outbound — já validado ✅
```
Template at_confirma_recebimento entregue de +553184226006 → +5521964798660
wamid: wamid.HBgNNTUyMTk2NDc5ODY2MBUCABEYEkJFMTg1RjgxQzUwNENENjQ2QgA=
```

### Inbound — parcial, **falta a Lara responder** ❌
```
conv 40 inbox=19 acct=9 (PROD)
  msg 8241 "OK"  ← incoming Contact (botão do template)
  msg 8242 "Oi"  ← incoming Contact

Frontdesk POSTou pra LARA_OUTGOING_URL:
  [2026-05-06T17:10:19Z] msg=8241 bot=Lara -> 200 (158ms)
  [2026-05-06T17:11:17Z] msg=8242 bot=Lara -> 200 (66ms)
  [2026-05-06T17:49:37Z] msg=8243 bot=Lara -> 200 (99ms)

Lara não respondeu (KLaOS PROD não tem mapping).
```

### Pós-`golive:lara` — esperado
1. Matheus manda nova msg pra `+553184226006`
2. Em ~5–10s, Lara envia mensagem outgoing prefixada com `**Atendente LARA:**\n...`
3. Verificar em `https://app-desk.klaos.ai` → conta Mais Saúde 24h → inbox KLaOS Cobranca → conversation
4. Verificar via SQL:
   ```sql
   SELECT id, message_type, sender_type, sender_id, content, created_at
   FROM messages WHERE conversation_id=40 AND account_id=9
   ORDER BY id;
   ```
   Esperado: aparecer linhas com `message_type=1` `sender_type='AgentBot'` `sender_id=14`

---

## Diferenças DEV vs PROD que importam pra Lara

### 1. Labels — alinhados ✅
Os 19 labels que Lara DEV emite (`mais-saude`, `cobranca-7d`, `pagamento-realizado`, etc) **TODOS existem em PROD com nomes idênticos**. Foram feitos renames hoje:
- `mais_saúde → mais-saude` (3665 taggings preservados)
- `enviado_ao_spc → enviado-ao-spc` (765 taggings)
- `quer_cancelar → quer-cancelar` (31 taggings)
- Criado `cancelado` (id=67, novo)

### 2. Automation rules — DESATIVADAS dos 2 lados (intencional)
```
"10 - Pagamento Realizado" — active=false (DEV e PROD)
"15 - Transbordo Humano"   — active=false (DEV e PROD)
```
Lara aplica labels via Frontdesk Platform API, não depende de automation rules.

### 3. canned_responses — paridade
DEV tem `confirmacao_pagamento` + `teste 1`. PROD tem `confirmacao_pagamento`. O "teste 1" é só placeholder do dev e não foi replicado.

### 4. Custom attributes — paridade
10 custom_attribute_definitions em ambos os lados, mesmos `attribute_key`s.

### 5. Members — Gustavo em ambos
- DEV: user_id=13 (Gustavo Henrique, `gustavooliveiranetwork@gmail.com`)
- PROD: user_id=12 (Gustavo Oliveira, `gustavooliveiranetwork@gmail.com`)

---

## Webhook arquitetura — IMPORTANTE

A WABA Klaus (`735467396201142`) é **compartilhada** entre DEV e PROD. Pra cada ambiente receber webhooks isoladamente, foi configurado **webhook per-phone-number** (feature da Cloud API descoberta hoje):

```
POST /{phone_number_id}
Authorization: Bearer {META_TOKEN}
Content-Type: application/json

{
  "webhook_configuration": {
    "override_callback_uri": "<URL>",
    "verify_token": "<TOKEN>"
  }
}
```

A hierarquia de precedência é:
1. **`phone_number`** (per-number, definido via endpoint acima) ← TEM PRECEDÊNCIA
2. **`whatsapp_business_account`** (WABA-level via `subscribed_apps`) ← fallback
3. **`application`** (app-level no developers.facebook.com) ← último fallback

Estado atual:
| phone_number_id | Número | Ambiente | URL |
|---|---|---|---|
| `1088056767715946` | +5531 9728-6773 Atend Med BH | **DEV** | `https://app-desk-dev.klaos.ai/webhooks/whatsapp/+553197286773` |
| `1111100338751985` | +5531 8422-6006 Mais Saúde | **PROD** | `https://app-desk.klaos.ai/webhooks/whatsapp/+553184226006` |

**NÃO MEXER** no per-phone do número DEV (vai quebrar DEV).

GET pra inspeção:
```bash
curl "https://graph.facebook.com/v22.0/1111100338751985?fields=webhook_configuration&access_token=$META_TOKEN"
```

---

## Pendências cosméticas (NÃO bloqueiam launch)

- **`name_status` do display "Mais Saúde"** está em `PENDING_REVIEW`. Meta analisa em 24-48h. Cliente vê o número até aprovar — não impacta envio/recepção de mensagens nem templates.
- Antes era "Mais Saúde24" REJECTED; foi simplificado pra "Mais Saúde" no re-cadastro.
- `quality_rating=GREEN` (subiu sozinho após `register`).

---

## Cuidados / Don'ts

- ❌ **NÃO mover de WABA outra vez** sem necessidade extrema (perde tier/qualidade do número, foi traumático demais hoje).
- ❌ **NÃO sobrescrever WABA-level subscribed_apps** sem antes verificar per-phone do outro número (vai quebrar DEV).
- ❌ **NÃO ativar `working_hours_enabled` com horário comercial restrito** sem alinhar — atualmente está 24h seg-dom (igual DEV).
- ❌ **NÃO confiar em `process.env.NODE_ENV` no KLaOS** pra distinguir DEV vs PROD nos disparos da Lara. Use account_id ou bot_id explícitos no script `golive:lara`.

---

## Histórico do que aconteceu hoje (cronológico, pra contexto)

1. Investigamos templates Mais Saúde (DEV) vs Klaus (PROD) — 3 equivalentes (`lembrete_agendamento↔agend_lembrete_24h`, `responda_ok↔at_confirma_recebimento`, `protesto↔cobr_aviso_protesto`).
2. Conclusão: cliente quer usar **templates da Klaus** no fluxo Mais Saúde — então mover o número físico pra WABA Klaus.
3. Tentei **migração entre WABAs via UI** — não existe. Meta só oferece "Excluir" + "Adicionar telefone" (perde qualidade/tier mas mantém posse do número).
4. Excluí `+5531 8422-6006` da WABA Mais Saúde, re-cadastrei na WABA Klaus, fiz OTP, registrei na Cloud API com PIN 789123.
5. Stakeholder achou que webhook só pode ser por WABA — investigamos a fundo e descobrimos que **per-phone** existe (POST `/{pnid}` com `webhook_configuration`) e tem precedência. Restauramos isolamento DEV/PROD.
6. Criamos canal/inbox/agent_bot_inbox em PROD.
7. Sincronizamos 17 templates. Fizemos outbound smoke test.
8. Fizemos inbound smoke test — Frontdesk PROD recebeu, encaminhou pra Lara KLaOS PROD, KLaOS retornou 200 mas no-op.
9. Alinhamos BRIDGE_SECRET (estava `3f23...` em PROD vs `JFve5...` em KLaOS — aplicamos `JFve5...` em PROD).
10. Renomeamos labels PROD pra bater com nomes DEV (3 renames + 1 criação).
11. Escrevi este handoff.

---

## Comandos úteis pra debug

```bash
# Conferir webhook per-phone configurado pra +5531 8422-6006
curl "https://graph.facebook.com/v22.0/1111100338751985?fields=webhook_configuration,verified_name,name_status,quality_rating,code_verification_status&access_token=$META_TOKEN" | jq

# Testar verify_token do Frontdesk
curl -i "https://app-desk.klaos.ai/webhooks/whatsapp/+553184226006?hub.mode=subscribe&hub.verify_token=10a96bba0053fd5938bdc6712e4827f4ea3b9e7c44931c465f0d5f0d61132a2d&hub.challenge=test123"
# Esperado: HTTP/2 200 + body 'test123'

# Disparar template manual (Cloud API direto)
curl -X POST "https://graph.facebook.com/v22.0/1111100338751985/messages" \
  -H "Authorization: Bearer $META_TOKEN" -H "Content-Type: application/json" \
  -d '{"messaging_product":"whatsapp","to":"5521964798660","type":"template","template":{"name":"at_confirma_recebimento","language":{"code":"pt_BR"}}}'

# Ver mensagens da conv 40 PROD
psql "$DATABASE_URL_PROD" -c "
  SELECT id, message_type, sender_type, sender_id, LEFT(content, 80), created_at
  FROM messages WHERE conversation_id=40 AND account_id=9 ORDER BY id;
"

# Ver agent_bot_guard_log (logs da chamada Frontdesk → KLaOS)
psql "$DATABASE_URL_PROD" -c "
  SELECT additional_attributes->'agent_bot_guard_log' FROM conversations WHERE id=40;
"

# Probe direto no endpoint Lara KLaOS PROD
curl -i -X POST https://api.klaos.ai/api/webhooks/agent-bot/1b092e03-9418-4352-956c-db0a560d904a \
  -H "Content-Type: application/json" -d '{"event":"test"}'
# Esperado hoje: HTTP/2 200 {"status":"ok"} (no-op até golive:lara rodar)
# Esperado pós-golive: ainda 200, mas vai disparar resposta via Frontdesk Platform API
```
