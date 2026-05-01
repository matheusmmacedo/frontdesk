# SDD — Go-Live Mais Saúde 24h em PRODUÇÃO

> **Versão:** 1.0 — 2026-04-30
> **Cliente:** Atend Med BH ("Mais Saúde 24 HORAS")
> **Owner Frontdesk:** Matheus Macedo
> **Owner KLaOS:** agente KLaOS (separar)
> **Status:** Pronto pra executar (após migração WABA)
> **Aprovação Gustavo:** ✅ obtida em 2026-04-30

---

## 0. Sumário executivo

Esse documento descreve o go-live em produção da operação Mais Saúde 24h, que hoje roda em DEV (`account_id=10` no Frontdesk + workspace `9838d25b-60de-45e7-b7b7-31cc56b12ccc` no KLaOS).

A produção tem todas as estruturas vazias / não configuradas. O número de WhatsApp em PROD será **+55 31 8422-6006** (hoje em outra WABA da mesma Business Manager Atend Med BH — vai migrar pra WABA Klaus `735467396201142`). DEV continua com o `+55 31 9728-6773` indefinidamente.

**Escopo do SDD**:
- Migração de número WhatsApp entre WABAs (lado Meta)
- Setup do Frontdesk account `id=9` (conta Mais Saúde em PROD)
- Setup do KLaOS workspace `9838d25b-…` em produção (Lara, tools, knowledge base, tenex, bridge)
- Importação de 59.715 contatos do CSV `addressbook (1).csv` com de/para de tags numéricas
- Validação end-to-end + rollback

**Premissas**:
- Templates `cobr_*` e `cobr_card_*` (incluindo os 2 v2) já estão APPROVED na WABA Klaus
- KLaOS DEV → PROD são duas instâncias separadas hospedadas em CloudPanel/Hostinger (deploy manual via ZIP)
- Frontdesk DEV → PROD são dois ambientes Railway independentes

**Críticos a observar**:
- Não disparar nada (zero broadcasts) durante setup
- ENCRYPTION_SECRET do KLaOS deve ser tratado como variável compartilhada DEV/PROD ou recriar credentials encriptadas
- UTF-8 guard em todo POST pra Meta (já implementado)
- Sequência: WABA migration → Frontdesk inbox creation → KLaOS bot creation → Lara instance → tools binding → docs migration → contact import → validation

---

## 1. Estado atual (snapshot 2026-04-30)

### 1.1 Frontdesk

| Item | DEV `acct=10` | PROD `acct=9` | Ação |
|---|---|---|---|
| Account name | "Mais Saúde 24h" | "Mais Saúde" | **Renomear PROD pra "Mais Saúde 24h"** |
| `custom_attributes` | `{klaos_workspace_id, klaos_human_message_template, klaos_auto_assignment_offline_fallback}` | `{}` | Copiar 3 keys |
| Custom attribute defs (CRM) | 10 keys | 10 keys ✅ | OK |
| Inbox WhatsApp | "KLaOS Cobranca" channel_id=5 (+5531 9728-6773) | (sem WhatsApp; tem `SAC` Channel::Api id=16 — deletar) | Criar inbox WhatsApp +5531 8422-6006 |
| `channel_whatsapp` | 1 row, 14 templates synced | (vazio) | Criado via Embedded Signup |
| Agent bots | 4 ativos (Lara, Vendas, FAQ, Teste) | 0 | Criar **só Lara** com URL `api.klaos.ai` |
| `agent_bot_inboxes` | Lara → KLaOS Cobranca | 0 | Vincular após criar bot+inbox |
| Teams | 3 (cobrança, cancelamento, contratos) | 0 | Criar 3 |
| `automation_rules` | 2 (active=false) | 0 | Criar 2 (active=false) |
| Labels | 19 | 0 | Criar **mais** que 19 (planos do Qualizap) |
| Canned responses | 2 (`confirmacao_pagamento`, `teste 1`) | 0 | Criar `confirmacao_pagamento` |
| Webhooks | 2 (api-dev.klaos.ai) | 2 (api.klaos.ai já existe) | ✅ OK |
| Contacts | 297 | 0 | Importar 59.715 do CSV |
| Conversations 30d | 10 | 0 | (orgânicas após go-live) |
| Users (agents) | 7 | 5 | Convites manuais via UI conforme cliente pedir |

### 1.2 KLaOS (Supabase)

| Item | DEV (`szkzkyexagunvadzzaec`) | PROD (`ddnwemmvsuiibgbzjpwx`) | Ação |
|---|---|---|---|
| Workspace `9838d25b-…` | ✅ existe ("Mais Saúde") | ✅ existe ("Mais Saúde") | Renomear pra "Mais Saúde 24h" (parity) |
| `agent_instances` ativos | 4 (Lara incluso) | **0** | Criar Lara com mesma config (model gpt-5.2, prompt 42KB, temp 0.7, rag_enabled, bridge_enabled, channels=['web']) |
| `agent_instance_tools` (Lara) | 6 enabled | 0 | Bind 6 tools (definitions globais já existem em PROD) |
| `agent_prompt_versions` | 8 | 0 | Migrar versões ou só a current |
| `agent_documents` (knowledge base) | 12 | 0 | Migrar metadados + blobs Supabase Storage |
| `agent_connector_credentials` (tenex) | 1 | 0 | Recriar (provavelmente pelo cuidado com ENCRYPTION_SECRET) |
| `agent_frontdesk_bridge` | 4 | 0 | Recriar bindings após bot Frontdesk PROD existir |
| `crm_workspace_tags` | 4 | 0 | Migrar 4 (prioridade-alta, teste, e2e-funcional, prioritário) |
| `workspace_invitations` | 8 | 0 | Cliente convida manualmente via UI |
| `workspace_feature_flags` | 3 | 1 | Replicar 2 que faltam |
| `workspace_members` | 6 | 5 | Já parcial; usuário faz invites |
| Tool definitions globais (6 nomes) | ✅ todas em DEV | ✅ todas em PROD ✅ | OK |

### 1.3 Meta WABA

| WABA | ID | Phone | phone_number_id | Quality | name_status | Status |
|---|---|---|---|---|---|---|
| Klaus (destino) | `735467396201142` | +5531 9728-6773 (DEV) | `1088056767715946` | GREEN | APPROVED | ATIVO, 14 templates APPROVED UTILITY |
| Origem (do 8422-6006) | `1370921667450261` | +5531 8422-6006 | `687476517774592` | GREEN | **DECLINED ⚠️** | A migrar pra Klaus |

- **Business Manager**: Atend Med BH (`1670699556853947`)
- **App Meta**: IA AtendMed - BH (`991500862837654`)
- **System User**: Klaos (`122101620662947057`) — token atual já tem acesso a ambas WABAs (após assignment de assets em 2026-04-30 ✅)
- **Subscribed app callback** (Klaus hoje): `https://app-desk-dev.klaos.ai/webhooks/whatsapp/+553197286773` — pós-migração precisa ADICIONAR `/webhooks/whatsapp/+553184226006` apontando pra `app-desk.klaos.ai` (PROD)
- **Templates da WABA origem** (4, todos UTILITY APPROVED — **sem conflito de nome com Klaus**): `lembrete_agendamento`, `responda_ok`, `protesto`, `hello_world`

⚠️ **`name_status=DECLINED` na WABA origem**: o display name "Mais Saúde" não foi aprovado pela Meta. **Resolver ANTES da migração** (resubmeter display name no painel BM ou via API), senão pós-migração o número fica na Klaus mas continua com display name não aprovado — clientes podem ver problema na exibição.

---

## 2. Decisões já tomadas

1. **Conta PROD** = `account_id=9` (existente). Renomear pra "Mais Saúde 24h".
2. **Workspace KLaOS** = mesmo UUID `9838d25b-60de-45e7-b7b7-31cc56b12ccc` que DEV (já existe em PROD com 5 members).
3. **Bots em PROD** = só Lara. Não migrar Vendas, FAQ, Teste.
4. **Users PROD** = via convite manual pelo cliente (não migrar de DEV).
5. **Inbox SAC** (id=16, Channel::Api) em PROD acct=9 = **deletar**.
6. **Número PROD** = +5531 8422-6006 (migrar da WABA `1370921667450261` pra Klaus `735467396201142`).
7. **Templates** = manter 14 atuais APPROVED na Klaus. Reusados imediato pelo número novo após migração.
8. **WABA migration timing** = ANTES do go-live (caminho recomendado).
9. **Token Meta** = reusar token Klaus existente (System User Klaos), com asset access estendido pra WABA `1370921667450261`.

---

## 3. Pré-requisitos (antes de começar a executar)

- [x] Cliente confirma que tem acesso admin ao Business Manager Atend Med BH (pra desabilitar 2FA + iniciar migração de número)
- [x] System User Klaos atribuído como admin na WABA `1370921667450261` (concluído 2026-04-30 ✅ — token Klaus enxerga ambas WABAs)
- [x] Templates da WABA origem listados — sem conflito com `cobr_*`/`cobr_card_*` ✅
- [ ] **`name_status=DECLINED` resolvido na WABA origem** (BLOCKER) — display name "Mais Saúde" precisa ser APPROVED antes da migração. Caminho: BM UI → WhatsApp Manager → +5531 8422-6006 → "Display Name" → resubmeter. Aguarda review Meta (~24h)
- [ ] Janela de manutenção combinada com cliente (ideal: madrugada / sábado de manhã, baixo volume)
- [ ] Backup atual do PIN 2FA do +5531 8422-6006 (caso precise reverter)
- [ ] **`ENCRYPTION_SECRET` do KLaOS PROD definido** (decisão: copiar do DEV ou usar valor próprio? Ver §6.3)
- [ ] **`FRONTDESK_BRIDGE_SECRET` PROD gerado** (`openssl rand -base64 48`) — único valor, replicado em Frontdesk Railway PROD env + KLaOS PROD env
- [ ] **`FRONTDESK_WEBHOOK_SECRET` PROD gerado** (idem)
- [ ] **`FRONTDESK_PLATFORM_API_TOKEN` PROD** = token de API admin do Frontdesk PROD acct=9 (gerar via Settings → Profile → Access Token)
- [ ] OPENAI_API_KEY PROD validado (não pode ser dev)
- [ ] Backup do CSV `maissaude/addressbook (1).csv` em local seguro

---

## 4. Fase 0.5 — Port de templates da WABA origem → Klaus (PRÉ-MIGRAÇÃO)

**Owner**: Matheus
**Duração**: 1-2h (incluindo aprovação Meta dos templates novos)
**Quando**: D-3 (antes da Fase 1)

A WABA origem tem 4 templates. **Decisão**:
- ✅ **Portar 2** pra Klaus: `lembrete_agendamento`, `responda_ok` (úteis pra ops Mais Saúde)
- ⚠️ **Avaliar com cliente** o `protesto` (texto pesado pode ser reclassificado MARKETING — se Mais Saúde realmente usa, portar com adaptação)
- ❌ **Descartar** `hello_world` (sample Meta, não tem uso)

**Por quê portar antes**: templates são por-WABA. Quando o número migra de uma WABA pra outra, **templates não migram**. Se o cliente continuar usando `lembrete_agendamento` no fluxo de agendamento, precisa estar disponível na Klaus.

**Sem conflito de nome com `cobr_*`/`cobr_card_*`** já confirmado.

### 0.5.1 Script de port

```ruby
# C:/tmp/port-templates-origem-to-klaus.rb
require 'json'
require 'net/http'
require 'uri'

TOKEN = 'EAAOFw8i5U5YBR...'
WABA_KLAUS = '735467396201142'
ENDPOINT = "https://graph.facebook.com/v22.0/#{WABA_KLAUS}/message_templates"

# Guard UTF-8 (igual produção)
MOJIBAKE = /[ÂÃâ][ -¿]/
QMARK_LETTER = /\p{L}\?\p{L}|(?<=\s|^)\?\p{L}/

def scan(node, path, bad)
  case node
  when String
    bad << "#{path} (invalid encoding)" if !node.valid_encoding?
    bad << "#{path} (mojibake)" if node.match?(MOJIBAKE)
    bad << "#{path} (? mid-word)" if node.match?(QMARK_LETTER)
  when Hash  then node.each { |k,v| scan(v, "#{path}.#{k}", bad) }
  when Array then node.each_with_index { |v,i| scan(v, "#{path}[#{i}]", bad) }
  end
end

TEMPLATES = [
  {
    name: 'lembrete_agendamento',
    language: 'pt_BR',
    category: 'UTILITY',
    components: [
      { type: 'HEADER', format: 'TEXT', text: 'Lembrete de agendamento' },
      { type: 'BODY', text: "Lembrete de consulta.\n\nVocê tem uma consulta agendada na clínica *Atend Med BH* amanhã.\n\nNão falte!" }
    ]
  },
  {
    name: 'responda_ok',
    language: 'pt_BR',
    category: 'UTILITY',
    components: [
      { type: 'BODY', text: 'Confirme o recebimento desta mensagem respondendo OK!' },
      { type: 'BUTTONS', buttons: [{ type: 'QUICK_REPLY', text: 'OK' }] }
    ]
  }
  # protesto pendente decisão
]

# Pre-flight
TEMPLATES.each do |tpl|
  bad = []
  scan(tpl, tpl[:name], bad)
  abort "BLOCKED #{tpl[:name]}: #{bad.join(', ')}" if bad.any?
  puts "OK preflight: #{tpl[:name]}"
end

# Submit
TEMPLATES.each do |tpl|
  uri = URI.parse(ENDPOINT)
  http = Net::HTTP.new(uri.host, uri.port); http.use_ssl = true
  req = Net::HTTP::Post.new(uri.request_uri,
                            'Content-Type' => 'application/json; charset=utf-8',
                            'Authorization' => "Bearer #{TOKEN}")
  req.body = JSON.generate(tpl, ascii_only: true)
  resp = http.request(req)
  puts "#{tpl[:name]}: #{resp.code} #{resp.body[0,200]}"
end
```

### 0.5.2 Validação

Aguardar APPROVED (~minutos). Confirmar:
```bash
curl -s "https://graph.facebook.com/v22.0/735467396201142/message_templates?fields=name,status,category&limit=50&access_token=$TOKEN_KLAUS" | jq '.data[] | select(.name == "lembrete_agendamento" or .name == "responda_ok")'
```

Se algum cair em REJECTED — investigar antes de prosseguir pra Fase 1.

---

## 4.1 Fase 1 — WABA migration (Meta side)

**Owner**: cliente (admin BM) + Matheus (operador script)
**Duração estimada**: 30min – 2h
**Janela**: madrugada (baixo volume mensagens)

### 4.1.1 Pre-flight

```bash
# Confirmar que System User Klaus já tem visibility na WABA origem
TOKEN_KLAUS='EAAOFw8i5U5YBR...'

curl -s "https://graph.facebook.com/v22.0/1370921667450261?fields=id,name,phone_numbers{display_phone_number,verified_name,quality_rating,messaging_limit_tier,name_status,status}&access_token=$TOKEN_KLAUS"
```
Esperado: ver +5531 8422-6006 listado com qualidade GREEN/YELLOW.

### 4.2 Listar templates da WABA origem (auditoria conflitos)

```bash
curl -s "https://graph.facebook.com/v22.0/1370921667450261/message_templates?fields=name,status,category,language&limit=100&access_token=$TOKEN_KLAUS" | jq '.data[] | "\(.name) [\(.status) \(.category) \(.language)]"'
```
Anotar nomes — se algum bate com `cobr_*` ou `cobr_card_*`, sinalizar (improvável, mas cuidar).

### 4.3 Desativar 2FA no número (cliente, painel BM UI)

1. `business.facebook.com` → WhatsApp Manager → WABA `1370921667450261` → Settings phone +5531 8422-6006
2. **Two-step verification** → desativar
3. Aguardar email Meta confirmando

### 4.4 Iniciar migração

**Caminho recomendado: UI BM**

1. WhatsApp Manager → WABA origem → Phone Numbers → menu do +5531 8422-6006 → **Move phone number**
2. Selecionar WABA Klaus (`735467396201142`) como destino
3. OTP via SMS/voz no número → digitar
4. Aguardar confirmação ("número movido")

**Caminho alternativo: Cloud API** (se UI não permitir):

```bash
# 1. Pedir migration code na origem
curl -X POST "https://graph.facebook.com/v22.0/{phone_number_id}/request_code" \
  -d "code_method=SMS" -d "language=pt_BR" -d "access_token=$TOKEN_KLAUS"

# 2. Migrar pra destino
curl -X POST "https://graph.facebook.com/v22.0/735467396201142/phone_numbers" \
  -d "cc=55" -d "phone_number=3184226006" -d "verified_name=Atend Med BH" \
  -d "migrate_phone_number=true" -d "access_token=$TOKEN_KLAUS"
# → retorna NEW_PHONE_NUMBER_ID

# 3. Verify code
curl -X POST "https://graph.facebook.com/v22.0/{NEW_PHONE_NUMBER_ID}/verify_code" \
  -d "code=123456" -d "access_token=$TOKEN_KLAUS"

# 4. Register no Cloud API
curl -X POST "https://graph.facebook.com/v22.0/{NEW_PHONE_NUMBER_ID}/register" \
  -d "messaging_product=whatsapp" -d "pin=000000" -d "access_token=$TOKEN_KLAUS"
```

### 4.5 Pós-migração: re-subscribe app na Klaus pro novo número

```bash
# Adiciona override callback per-phone do número novo apontando pra app-desk.klaos.ai (PROD)
curl -X POST "https://graph.facebook.com/v22.0/735467396201142/subscribed_apps" \
  -d "override_callback_uri=https://app-desk.klaos.ai/webhooks/whatsapp/+553184226006" \
  -d "verify_token=<verify_token_app>" \
  -d "access_token=$TOKEN_KLAUS"
```

(`verify_token` pega-se do app config do Frontdesk; consultar `WHATSAPP_VERIFY_TOKEN` no Railway env do Frontdesk PROD.)

### 4.6 Validação Fase 1

```bash
# Confirmar que Klaus agora tem 2 phones (DEV + PROD)
curl -s "https://graph.facebook.com/v22.0/735467396201142/phone_numbers?fields=id,display_phone_number,verified_name,quality_rating,status&access_token=$TOKEN_KLAUS" | jq
```
Esperado: 2 entries (`+55 31 9728-6773` e `+55 31 8422-6006`), ambas `status=CONNECTED`.

### 4.7 Reativar 2FA no número novo

Painel BM → Phone Numbers → +5531 8422-6006 (agora na Klaus) → 2FA → ativar com PIN novo (anotar em local seguro).

---

## 5. Fase 2 — Frontdesk PROD setup (account=9)

**Owner**: Matheus + Frontdesk agent automation
**Pré-req**: Fase 1 completa (número na Klaus, novo phone_number_id em mãos)

### 5.1 Renomear conta + custom_attributes

```sql
-- ⚠️ EXECUTAR EM PROD POSTGRES
UPDATE accounts
SET name = 'Mais Saúde 24h',
    custom_attributes = jsonb_build_object(
      'klaos_workspace_id', '9838d25b-60de-45e7-b7b7-31cc56b12ccc',
      'klaos_human_message_template', E'**Atendente {FIRST_NAME_UPPER}:**\n',
      'klaos_auto_assignment_offline_fallback', true
    )
WHERE id = 9;
```

### 5.2 Deletar inbox SAC

```sql
-- Identificar SAC primeiro
SELECT id, name, channel_type, channel_id FROM inboxes WHERE account_id = 9 AND name = 'SAC';
-- Backup
CREATE TABLE _backup_inbox_sac_2026_04_30 AS SELECT * FROM inboxes WHERE account_id = 9 AND name = 'SAC';
-- Delete (cascata: agent_bot_inboxes, channel_api, etc — verificar antes)
DELETE FROM inboxes WHERE account_id = 9 AND name = 'SAC';
```

### 5.3 Criar WhatsappConnection + Inbox WhatsApp

**Via UI (recomendado)**: Settings → WhatsApp → +Adicionar conexão → Embedded Signup com System User Klaos token.

**Via CLI (alternativa, console Rails)**:

```ruby
account = Account.find(9)
conn = WhatsappConnection.create!(
  account: account,
  name: 'Mais Saúde 24h - WhatsApp',
  business_id: '1670699556853947',
  business_account_id: '735467396201142',  # WABA Klaus
  connection_type: 'meta_cloud',
  status: 'active',
  credentials: { 'access_token' => 'EAAOFw8i5U5YBR...' }  # token Klaus
)

# Sync phone numbers automaticamente
WhatsappConnections::Meta::PhoneSyncService.new(conn).perform
# Esperado: 2 phones aparecem (9728-6773 e 8422-6006)

# Linkar phone +5531 8422-6006 ao Channel::Whatsapp + Inbox "KLaOS Cobranca"
phone = WhatsappPhoneNumber.find_by(phone_number_id: '<NEW_PHONE_NUMBER_ID>')
WhatsappConnections::Meta::PhoneLinkerService.new(
  phone: phone,
  inbox_name: 'KLaOS Cobranca'
).perform

# Sync templates
WhatsappConnections::Meta::TemplateSyncService.new(conn).perform
# Esperado: 14 templates (cobr_* + cobr_card_*) populados em conn.message_templates
```

### 5.4 Criar agent_bot Lara

```sql
-- ⚠️ Atenção: outgoing_url APONTA PRA api.klaos.ai (PROD), NÃO -dev
INSERT INTO agent_bots (id, account_id, name, description, outgoing_url, bot_type, created_at, updated_at)
VALUES (
  DEFAULT, 9, 'Lara | lara', 'Agente de cobrança Mais Saúde 24h',
  'https://api.klaos.ai/api/webhooks/chatwoot-bot/1b092e03-9418-4352-956c-db0a560d904a',  -- mesmo UUID que DEV (linked a Lara em KLaOS)
  0, NOW(), NOW()
) RETURNING id;  -- anotar BOT_ID_PROD
```

### 5.5 Vincular Lara ao Inbox

```sql
INSERT INTO agent_bot_inboxes (account_id, inbox_id, agent_bot_id, status, created_at, updated_at)
VALUES (9, <INBOX_ID_PROD>, <BOT_ID_PROD>, 0, NOW(), NOW());
```

### 5.6 Criar Teams

```sql
INSERT INTO teams (account_id, name, description, allow_auto_assign, created_at, updated_at) VALUES
  (9, 'cobrança', NULL, false, NOW(), NOW()),
  (9, 'cancelamento', NULL, false, NOW(), NOW()),
  (9, 'contratos', NULL, false, NOW(), NOW());
```
**Membros**: cliente atribui depois de convidar agentes.

### 5.7 Criar automation_rules (active=false)

Replicar 2 rules de DEV via SQL ou via UI Settings → Automation. Manter `active=false` até validar manualmente.

### 5.8 Criar labels (PRO PROD)

Conjunto consolidado: 19 cobranca-* do DEV + planos novos do Qualizap.

```sql
INSERT INTO labels (account_id, title, description, color, show_on_sidebar, created_at, updated_at) VALUES
  -- Bloco cobrança (do DEV)
  (9, 'pendente', NULL, '#FEF08A', true, NOW(), NOW()),
  (9, 'cobranca-7d', NULL, '#FBCFE8', true, NOW(), NOW()),
  (9, 'cobranca-15d', NULL, '#FDBA74', true, NOW(), NOW()),
  (9, 'cobranca-d21', NULL, '#3B82F6', true, NOW(), NOW()),
  (9, 'cobranca_1d', NULL, '#DDD6FE', true, NOW(), NOW()),
  (9, 'cobranca-0d', NULL, '#BFDBFE', true, NOW(), NOW()),
  (9, 'pagamento-realizado', NULL, '#BBF7D0', true, NOW(), NOW()),
  (9, 'cobranca-promessa', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cobranca-promessa-hoje', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cobranca-negociacao', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cobranca-segunda-via', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cobranca-cartao-recusado', NULL, '#FCA5A5', true, NOW(), NOW()),
  (9, 'cobranca-cartao-pendente', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cobranca-boleto-pendente', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'cancelamento-pendente', NULL, '#FCD34D', true, NOW(), NOW()),
  (9, 'mais-saude', NULL, '#22C55E', true, NOW(), NOW()),
  (9, 'enviado-ao-spc', NULL, '#F97316', true, NOW(), NOW()),
  (9, 'cancelado', NULL, '#1F2937', true, NOW(), NOW()),
  (9, 'quer-cancelar', NULL, '#EAB308', true, NOW(), NOW()),
  -- Bloco do Qualizap (mapeamento das 47 tags) — ver Anexo A
  (9, 'enviado-convenio', NULL, '#CE007F', true, NOW(), NOW()),
  (9, 'blue-care', NULL, '#1458EA', true, NOW(), NOW()),
  (9, 'plano-ouro', NULL, '#CE9B00', true, NOW(), NOW()),
  (9, 'plano-prata', NULL, '#25615F', true, NOW(), NOW()),
  (9, 'plano-diamante', NULL, '#25615F', true, NOW(), NOW()),
  (9, 'cadastro', NULL, '#86F5F1', true, NOW(), NOW()),
  (9, 'interesse-mais-saude', NULL, '#1458EA', true, NOW(), NOW())
  -- ... (lista completa em Anexo A)
;
```

### 5.9 Canned response

```sql
INSERT INTO canned_responses (account_id, short_code, content, created_at, updated_at)
VALUES (9, 'confirmacao_pagamento', 'Obrigado pelo pagamento! ...', NOW(), NOW());
```

(Conteúdo exato copiar de DEV.)

### 5.10 Validação Fase 2

- `acct=9` agora se chama "Mais Saúde 24h" e tem `custom_attributes.klaos_workspace_id` populado
- 1 inbox WhatsApp "KLaOS Cobranca" linked ao novo phone_number_id
- `channel_whatsapp.message_templates` array tem 14 entries
- Lara existe com `outgoing_url=https://api.klaos.ai/...` (NÃO `-dev`)
- Lara → Inbox via `agent_bot_inboxes`
- 3 teams, 2 automation_rules, 26+ labels, 1 canned response

---

## 6. Fase 3 — KLaOS PROD setup (workspace 9838d25b-…)

**Owner**: agente KLaOS — esta fase é executada do lado deles.

**Doc completa**: `docs/para-klaos-agent/SDD_GOLIVE_PROD_MAISSAUDE.md` (lista detalhada do que KLaOS faz: criar Lara, bind 6 tools, migrar 12 docs, recriar tenex credential, replicar feature_flags, criar régua paused).

**Inputs que eu (Frontdesk) entrego pra KLaOS antes**:
- `FRONTDESK_BRIDGE_SECRET` PROD (gerado por mim, mesmo valor nos 2 envs)
- `FRONTDESK_WEBHOOK_SECRET` PROD (idem)
- `FRONTDESK_PLATFORM_API_TOKEN` PROD (gerado no Frontdesk admin)
- Bot ID (`agent_bots.id`) que crio em PROD acct=9 → entra em `agent_instances.frontdesk_chatwoot_bot_id`
- Inbox ID (`inboxes.id`) que crio em PROD acct=9 → entra em `agent_instances.desk_inbox_id`

**Outputs que KLaOS me entrega depois**:
- Confirmação Lara `agent_instances.id = 1b092e03-9418-4352-956c-db0a560d904a` ativa
- Régua boleto + cartão criada com `status='paused'`
- Smoke test bridge OK (X-Bridge-Secret aceito)

Esta fase pode rodar **em paralelo** com a Fase 2 do meu lado (Frontdesk PROD setup) — só precisa esperar bot_id + inbox_id antes do passo final de Lara.

[Restante desta seção movido pra `docs/para-klaos-agent/SDD_GOLIVE_PROD_MAISSAUDE.md`]

### 6.1 Env vars que EU configuro no Frontdesk Railway (klaos-production)

```env
KLAOS_BRIDGE_WEBHOOK_URL=https://api.klaos.ai/api/webhooks/klaos/bridge-event
FRONTDESK_BRIDGE_SECRET=<MESMO valor que KLaOS PROD env, gerado por mim>
WHATSAPP_VERIFY_TOKEN=<token único pro webhook subscription Meta>
WHATSAPP_API_VERSION=v22.0
```

### 6.2 Resto das ações KLaOS

Movido pra `docs/para-klaos-agent/SDD_GOLIVE_PROD_MAISSAUDE.md` — esse doc lista item-por-item: criar Lara, bind 6 tools, migrar 12 docs (Storage + embeddings), recriar tenex credential via admin panel, replicar workspace_feature_flags + crm_workspace_tags, criar régua boleto+cartão com `status=paused`, smoke test bridge.

⚠️ **Decisão crítica que afeta KLaOS**: `ENCRYPTION_SECRET` PROD = secret novo (não copiar de DEV). Implica recriar `agent_connector_credentials` (tenex) manualmente em PROD via admin panel. Se KLaOS preferir cenário A (compartilhar secret DEV/PROD), avisar.

---

## 7. Fase 4 — Importação de contatos (CSV → Frontdesk acct=9)

**Owner**: Matheus (Frontdesk)
**Pré-req**: Fases 2 e 3 completas, labels todas criadas.

### 7.1 Mapping definitivo Qualizap tag_id → Frontdesk label

Ver **Anexo A** (47 tags). Resumo decisões importantes:
- Tags 5 e 10 (SPC + ENVIADOS SPC) → ambas mapeiam pra `enviado-ao-spc`
- Tags 32 e 38 (OURO + OURO ENVIADO) → `plano-ouro` (consolidar) ou `plano-ouro` + `plano-ouro-enviado` (separar)? Decidir com cliente.
- Tags `42, 4, 6, 7, 8, 17, 22, 23, 24` que aparecem no CSV mas não na API → **tags deletadas** no Qualizap. Decidir: ignorar ou criar label `_legacy_<id>` pra preservar audit.

### 7.2 Script de import idempotente

Estrutura sugerida (Ruby, rake task em `custom/lib/tasks/import_maissaude_contacts.rake`):

```ruby
namespace :import do
  desc 'Importa contatos do CSV maissaude pra account 9'
  task maissaude: :environment do
    account = Account.find(9)
    csv_path = Rails.root.join('maissaude/addressbook (1).csv')

    tag_map = {  # Anexo A
      1 => 'mais-saude', 3 => 'pendente', 5 => 'enviado-ao-spc',
      9 => 'enviado-convenio', 10 => 'enviado-ao-spc',
      # ... (lista completa)
    }

    CSV.foreach(csv_path, headers: true, col_sep: ';') do |row|
      next if row['number'].blank?
      phone = normalize_phone(row['number'])
      contact = Contact.find_or_create_by!(account: account, phone_number: phone) do |c|
        c.name = row['name']
        c.email = row['email'] if row['email'].present?
      end

      # Custom attributes
      contact.update!(custom_attributes: {
        'document'     => row['document'],
        'donotdisturb' => row['donotdisturb'] == '1',
        'block_marketing' => row['blockmarketingcampaigns'] == '1',
        'block_utility'   => row['blockutilitiescampaigns'] == '1',
        'fk_company'   => row['fk_company'],
        'qualizap_id'  => row['id'],  # auditoria
        'birthdate'    => row['birthdate']
      }.compact)

      # Tags → labels
      tag_ids = row['tags'].to_s.split(',').map(&:strip).map(&:to_i)
      labels = tag_ids.map { |tid| tag_map[tid] }.compact.uniq
      contact.update!(label_list: labels) if labels.any?
    end
  end
end
```

⚠️ Antes de rodar em PROD: testar primeiro num **subconjunto de 100 linhas** (`head -101 addressbook.csv`).

### 7.3 Validação Fase 4

```sql
SELECT COUNT(*) AS total_contacts, COUNT(*) FILTER (WHERE custom_attributes ? 'qualizap_id') AS imported_via_csv
FROM contacts WHERE account_id = 9;

SELECT label_id, label_count FROM (
  SELECT unnest(string_to_array(custom_attributes->>'labels', ',')) AS label_id, COUNT(*) AS label_count
  FROM contacts WHERE account_id = 9 GROUP BY 1
) ORDER BY label_count DESC LIMIT 10;
```

Esperado: ~59.700 contatos importados, top label ~40.000 com `enviado-convenio`.

---

## 8. Fase 5 — Validação end-to-end

### 8.1 Smoke tests

1. **Webhook bridge**: testar `POST /api/webhooks/klaos/bridge-event` com `X-Bridge-Secret` correto:
   ```bash
   curl -X POST "https://api.klaos.ai/api/webhooks/klaos/bridge-event" \
     -H "X-Bridge-Secret: $FRONTDESK_BRIDGE_SECRET_PROD" \
     -H "Content-Type: application/json" \
     -d '{"type":"manual_transfer_to_bot","conv_display_id":1,"workspace_id":"9838d25b-60de-45e7-b7b7-31cc56b12ccc","reason":"smoke-test"}'
   ```
   Esperado: 200 OK ou erro semântico (não 401/403).

2. **Templates sincronizam**: rodar `WhatsappConnections::Meta::TemplateSyncService.new(conn).perform` no Rails console PROD; ver 14 templates em `conn.message_templates`.

3. **Phone number sync**: rodar `WhatsappConnections::Meta::PhoneSyncService.new(conn).perform`; ver `+5531 8422-6006` linked ao Channel.

4. **Agent bot URL apontando pra api.klaos.ai (não dev)**:
   ```sql
   SELECT name, outgoing_url FROM agent_bots WHERE account_id = 9;
   -- Não pode aparecer 'api-dev'
   ```

5. **Régua paused**: KLaOS dashboard → cobranca campaigns → status=paused.

6. **Lara responde via web widget**: criar conversation teste no PROD, ver Lara responder.

7. **Tools de Lara**: testar `consultar_debito` via Lara num CPF de teste — ver chamada no Tenex prod (logs).

### 8.2 Canary release

- Selecionar **5 clientes de teste** (CPFs reais, telefone do staff Atend Med BH) em estado de cobrança
- Adicionar como `enrollment` na régua Cartão (1 cliente) e Boleto (4 clientes)
- Status régua: `active` apenas pra esses 5
- Monitorar 48h antes de liberar pra base completa

### 8.3 Métricas de sucesso

| Métrica | Threshold |
|---|---|
| Templates dispatch success rate | > 99% |
| Webhook bridge p95 latency | < 500ms |
| Quality rating do +5531 8422-6006 | mantém GREEN |
| Lara error_count (24h) | < 10 |
| `consultar_debito` timeout rate | < 2% |

---

## 9. Rollback plans

### 9.1 Rollback WABA migration (Fase 1)

Migrar de volta o número da Klaus pra WABA original via mesmo fluxo (`POST /1370921667450261/phone_numbers` com `migrate_phone_number=true`). Custo: ~30min, sem perda de quality rating.

### 9.2 Rollback Frontdesk PROD

- `accounts.custom_attributes` revert: clear keys
- Inbox WhatsApp: `inbox.update(deleted_at: NOW())` ou `DELETE` se nada operou ainda
- Lara: `agent_bot_inbox` DELETE → bot fica disconnected mas não deletado
- Backups SQL: tabela `_backup_*_2026_04_30` criada antes de cada DELETE/UPDATE crítico

### 9.3 Rollback KLaOS PROD

- Lara: `UPDATE agent_instances SET deleted_at = NOW() WHERE id = '1b092e03-...';`
- agent_instance_tools: `DELETE WHERE agent_instance_id = '1b092e03-...';`
- Knowledge base: documents soft-delete + storage bytes mantidos

### 9.4 Rollback contact import

- Identificar contatos importados via `custom_attributes->>'qualizap_id' IS NOT NULL`
- `UPDATE contacts SET deleted_at = NOW() WHERE account_id = 9 AND custom_attributes ? 'qualizap_id';` (se schema tem soft delete)
- Ou `DELETE` em batch — ⚠️ só se ZERO conversations atreladas

---

## 10. Risk matrix

| # | Risco | Prob | Impacto | Mitigação |
|---|---|---|---|---|
| 1 | Bridge secrets desincronizados Frontdesk ↔ KLaOS | M | Alto | Smoke test §8.1 antes de habilitar régua |
| 2 | Tenex credential ausente em PROD | M | Alto | Criar via admin panel ANTES de habilitar régua; teste `consultar_debito` |
| 3 | `ENCRYPTION_SECRET` mismatch → credentials não decriptam | B | Alto | Decisão clara em §6.3 (cenário B + recriação manual) |
| 4 | `phone_number_id` não atualiza no banco pós-migração | M | Médio | Rodar `PhoneSyncService` manual logo após Fase 1 |
| 5 | Webhook subscription não foi feita na Klaus pro novo número | M | Crítico | Curl POST §4.5 + verificar logs Meta App |
| 6 | Templates locked 30d se algum tiver de ser deletado | B | Médio | Já mitigado (resubmission usa `_v2` quando necessário) |
| 7 | Quality rating cai após mudança de número | B | Médio | Migration entre WABAs preserva quality (Meta docs) |
| 8 | Régua dispara antes de validar canary | B | **Crítico** | Status `paused` em todas as campaigns até canary OK |
| 9 | Import duplica contatos (telefones com formato diferente) | M | Médio | `find_or_create_by` em `phone_number` normalizado (E.164) |
| 10 | Lara responde com URL `api-dev.klaos.ai` em PROD (bot mudo) | B | Alto | Validação §8.1.4 — query SQL falha se aparecer `dev` |
| 11 | Schedule cron não roda em KLaOS PROD | B | Crítico | Logs + smoke test `collectionDispatch` |
| 12 | DELETE inbox SAC em cascata derruba conversations órfãs | B | Médio | Backup `_backup_inbox_sac_*` antes do DELETE |
| 13 | Import bate em rate limit do Frontdesk API | B | Baixo | Batch size 100 + sleep 1s entre batches |
| 14 | Tags numéricas do CSV não mapeadas (gaps 4, 6, 7, ...) | M | Baixo | Anexo A: tags deletadas → label `_legacy_<id>` ou ignorar (decisão cliente) |

---

## 11. Owners (quem faz o quê)

| Fase | Frontdesk (Matheus) | KLaOS agente | Cliente (admin BM) | Ops |
|---|---|---|---|---|
| 0 — Pré-req | Gerar secrets, validar tokens | Setar env vars KLaOS PROD | Atribuir Klaus à WABA origem | — |
| 1 — WABA migration | Rodar pre-flight + monitorar | — | Desativar 2FA, executar move via UI | Standby |
| 2 — Frontdesk PROD | Tudo (renomear acct, criar WhatsApp connection, bot, teams, labels, canned, deletar SAC) | — | — | Validar smoke |
| 3 — KLaOS PROD | — | Tudo (Lara, tools, docs migration, tenex cred, frontdesk_bridge, feature_flags, régua estrutura paused) | Fornecer Tenex prod URL+token | Standby |
| 4 — Import contatos | Rake task + validação | — | — | Monitorar Sentry |
| 5 — Validação | Smoke + canary 5 clientes | Validar régua + Lara responde | Confirma 5 clientes de teste | Métricas 48h |

---

## 12. Cronograma sugerido

| Dia | Atividade |
|---|---|
| **D-7** | Pré-reqs: gerar secrets, validar Klaus → WABA origem, listar templates origem |
| **D-3** | Janela combinada com cliente, backup snapshots |
| **D-1** | Renomear PROD acct=9, criar labels (sem WhatsApp ainda — pode preparar) |
| **D-0 madrugada** | Fase 1 (WABA migration) — janela de 2h |
| **D-0 manhã** | Fase 2 (Frontdesk inbox + bot) |
| **D-0 tarde** | Fase 3 (KLaOS Lara + tools + docs + tenex cred) |
| **D+1** | Fase 4 (import contatos em batches) + Fase 5 smoke |
| **D+2 a D+3** | Canary 5 clientes, monitorar métricas |
| **D+4** | Liberação régua active pra base completa |

---

## Anexo A — De/para completo das 47 tags Qualizap → labels Frontdesk

| ID | Nome Qualizap | Volume CSV | Label Frontdesk | Status label |
|---|---|---|---|---|
| 1 | MAIS SAÚDE | 3.657 | `mais-saude` | já existe DEV |
| 3 | PENDENTE | 1.156 | `pendente` | já existe DEV |
| 5 | SPC | 831 | `enviado-ao-spc` | já existe DEV (consolida c/ 10) |
| 9 | ENVIADO CONVÊNIO | 40.793 | `enviado-convenio` | CRIAR |
| 10 | ENVIADOS SPC | 772 | `enviado-ao-spc` | consolida c/ 5 |
| 11 | PARCERIA DESCONTO | <100 | `parceria-desconto` | CRIAR |
| 12 | FORNECEDOR | <100 | `fornecedor` | CRIAR |
| 13 | PSQUIATRA ON-LINE | <100 | `psiquiatra-online` | CRIAR (corrigir typo) |
| 14 | SEM RENOVAÇÃO DE CONTRATO | <100 | `sem-renovacao` | CRIAR |
| 15 | BOMBA | <100 | `bomba` | CRIAR (?) — confirmar com cliente |
| 16 | NAO LIDA | <100 | `nao-lida` | CRIAR |
| 18 | COLETA DOMICILAIR | <100 | `coleta-domiciliar` | CRIAR (corrigir typo) |
| 19 | SAAEMG | <100 | `saaemg` | CRIAR |
| 20 | SAUDE 24 | <100 | `saude-24` | CRIAR |
| 21 | CLIENTE DIFICIL | <100 | `cliente-dificil` | CRIAR |
| 25 | GOOGLE | <100 | `origem-google` | CRIAR |
| 26 | CONVENIO CANCELADO | 712 | `cancelado` | já existe DEV |
| 27 | QUER CANCELAR | <100 | `quer-cancelar` | já existe DEV |
| 28 | SAO LUCAS | <100 | `sao-lucas` | CRIAR |
| 29 | QUER MAIS SAÚDE | 251 | `interesse-mais-saude` | CRIAR |
| 30 | CADASTRO | 500 | `cadastro` | CRIAR |
| 31 | PRATA | <100 | `plano-prata` | CRIAR |
| 32 | OURO | 350 | `plano-ouro` | CRIAR (consolida c/ 38?) |
| 33 | RECEBER PAGAMENTO | <100 | `receber-pagamento` | CRIAR (≠ pagamento-realizado) |
| 34 | AUDIO | <100 | `audio` | CRIAR (?) |
| 35 | INCLUIR DEPENDENTES | <100 | `incluir-dependentes` | CRIAR |
| 36 | ORCAMENTO CARO | <100 | `orcamento-caro` | CRIAR |
| 37 | HEMATO ONLINE | <100 | `hemato-online` | CRIAR |
| 38 | OURO ENVIADO | <100 | `plano-ouro-enviado` | CRIAR (ou consolida c/ 32) |
| 39 | NAO ENVIAR BOLETO | <100 | `nao-enviar-boleto` | CRIAR |
| 40 | CARNE | <100 | `carne` | CRIAR |
| 41 | META | <100 | `meta-vendas` | CRIAR |
| 43 | VENCIDO CONTARTO | <100 | `vencido-contrato` | CRIAR (corrigir typo) |
| 44 | CONCURSO | <100 | `concurso` | CRIAR |
| 45 | PORTAL | <100 | `portal` | CRIAR |
| 46 | FEITO ORCAMENTO | <100 | `feito-orcamento` | CRIAR |
| 47 | SEM CONTRATO | <100 | `sem-contrato` | CRIAR |
| 48 | INDICOU GANHOU | <100 | `indicou-ganhou` | CRIAR |
| 49 | EMPRESA | <100 | `empresa` | CRIAR |
| 50 | NAO AGENDAR | <100 | `nao-agendar` | CRIAR |
| 51 | FUNERAL ZELO | <100 | `funeral-zelo` | CRIAR |
| 52 | sem whatsapp | <100 | `sem-whatsapp` | CRIAR |
| 53 | BLUE CARE | 2.309 | `blue-care` | CRIAR |
| 54 | ADVOGADA | <100 | `advogada` | CRIAR |
| 55 | APP | <100 | `origem-app` | CRIAR |
| 56 | tetse | <100 | (descartar, é teste) | — |
| 57 | DIAMANTE | <100 | `plano-diamante` | CRIAR |

**Tags em CSV mas não na API (deletadas no Qualizap)**: 2, 4, 6, 7, 8, 17, 22, 23, 24, 42 — decisão: ignorar (não criar label) ou `_legacy_<id>` se cliente quer audit.

**Decisões pendentes pra cliente**:
- Tag 15 (BOMBA): que significa? Importar?
- Tag 32 vs 38 (OURO vs OURO ENVIADO): consolidar ou separar?
- Tag 56 (tetse — typo de "teste"): descartar.
- Tags 3, 5, 10 com status SPC mistura: confirmar fluxo.

---

## Anexo B — Secrets checklist

| Var | Onde mora | Origem | Compartilhado? |
|---|---|---|---|
| `FRONTDESK_BRIDGE_SECRET` | KLaOS PROD env + Frontdesk Railway PROD env | gerar `openssl rand -base64 48` | mesmo valor nos 2 |
| `FRONTDESK_WEBHOOK_SECRET` | KLaOS PROD env + Frontdesk Railway PROD env | gerar `openssl rand -base64 48` | mesmo valor nos 2 |
| `FRONTDESK_PLATFORM_API_TOKEN` | KLaOS PROD env | Frontdesk PROD admin → Settings → Profile → Access Tokens | só KLaOS |
| `KLAOS_BRIDGE_WEBHOOK_URL` | Frontdesk Railway PROD env | hardcoded `https://api.klaos.ai/api/webhooks/klaos/bridge-event` | só Frontdesk |
| `WHATSAPP_VERIFY_TOKEN` | Frontdesk Railway PROD env + Meta App | gerar único, configurar no Meta App webhook subscription | mesmo valor nos 2 |
| `OPENAI_API_KEY` | KLaOS PROD env | OpenAI dashboard prod | só KLaOS |
| `ENCRYPTION_SECRET` | KLaOS PROD env | gerar 32 chars hex (ou copiar DEV se cenário A) | KLaOS interno |
| `JWT_SECRET`, `JWT_REFRESH_SECRET`, `COOKIE_SECRET` | KLaOS PROD env | gerar 3 valores únicos `openssl rand -base64 48` | KLaOS interno |
| Token Klaus Meta Graph | já existe; armazenar em `whatsapp_connections.credentials.access_token` | reusar atual após asset assignment | só Frontdesk |
| Tenex API key prod | KLaOS DB `agent_connector_credentials` | cliente fornece | só KLaOS |

---

## Anexo C — SQL de validação pós-go-live

```sql
-- Frontdesk PROD
SELECT
  (SELECT name FROM accounts WHERE id = 9) AS account_name,
  (SELECT custom_attributes ? 'klaos_workspace_id' FROM accounts WHERE id = 9) AS has_workspace_id,
  (SELECT COUNT(*) FROM inboxes WHERE account_id = 9 AND channel_type = 'Channel::Whatsapp') AS whatsapp_inboxes,
  (SELECT COUNT(*) FROM agent_bots WHERE account_id = 9) AS bots,
  (SELECT COUNT(*) FROM agent_bots WHERE account_id = 9 AND outgoing_url LIKE '%api-dev%') AS bots_with_dev_url,
  (SELECT COUNT(*) FROM teams WHERE account_id = 9) AS teams,
  (SELECT COUNT(*) FROM labels WHERE account_id = 9) AS labels,
  (SELECT COUNT(*) FROM contacts WHERE account_id = 9) AS contacts;

-- Esperado: name='Mais Saúde 24h', has_workspace_id=true, whatsapp_inboxes=1, bots=1, bots_with_dev_url=0, teams=3, labels >= 26, contacts ~= 59700
```

```sql
-- KLaOS PROD (Supabase)
SELECT
  (SELECT name FROM workspaces WHERE id = '9838d25b-60de-45e7-b7b7-31cc56b12ccc') AS workspace_name,
  (SELECT COUNT(*) FROM agent_instances WHERE workspace_id = '9838d25b-...' AND deleted_at IS NULL) AS agents,
  (SELECT COUNT(*) FROM agent_instance_tools WHERE agent_instance_id = '1b092e03-9418-4352-956c-db0a560d904a') AS lara_tools,
  (SELECT COUNT(*) FROM agent_documents WHERE workspace_id = '9838d25b-...') AS docs,
  (SELECT COUNT(*) FROM agent_connector_credentials WHERE workspace_id = '9838d25b-...') AS connectors,
  (SELECT COUNT(*) FROM agent_frontdesk_bridge WHERE workspace_id = '9838d25b-...') AS bridges;

-- Esperado: 'Mais Saúde 24h', agents=1, lara_tools=6, docs=12, connectors=1, bridges=4
```

---

## Histórico

- **2026-04-30** — v1.0. Levantamento completo via 4 agentes paralelos (Frontdesk codebase, KLaOS codebase, Frontdesk DB drift, Meta WABA discovery, Qualizap login + tag extraction).
