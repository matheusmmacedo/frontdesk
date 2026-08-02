# RUNBOOK DE PREPARAÇÃO — BLUE CARE EM PRODUÇÃO
**Data:** 2026-08-02 · **Alvo:** segunda-feira, 2026-08-03 · **Escopo:** Chatwoot/Frontdesk PROD conta 12 + KLaOS Supabase PROD workspace `6125b945-641c-4255-9cf5-81bbf2387ef5`

---

## 1. RESUMO

A conta 12 do Frontdesk PROD ("Blue Care Mais Saude") é uma **casca vazia**: existe desde 27/07 com 0 inboxes, 0 conversas, 0 times, 0 labels úteis, 0 canned responses, 1 único usuário (Matheus) e **nenhum agente de IA** no KLaOS. As duas campanhas de cobrança existem em `reply_mode='ai_agent'` mas estão pausadas e apontam para inbox nulo. Não há incêndio em curso — não há tráfego para perder — mas **nada funciona hoje**.

Dos 20 gaps investigados, **3 são falsos** (G02, G11, G06-parcial), **1 está mal localizado** (G20 — vive em DEV, não em PROD), **1 é higiene fora de escopo** (G17) e **15 são reais**. Desses 15, **13 podem ser executados agora, sem o número WABA**; apenas 2 dependem dele (membership de inbox e a bridge agente↔inbox).

O caminho crítico é: **corrigir código + deploy → dar acesso do Klaus à conta 12 → consertar o webhook → criar times/labels/usuários → criar a ANA pausada**. Se isso estiver feito, segunda-feira sobra: portar o número, criar a inbox, ligar a bridge, despausar. Cerca de 40 minutos de trabalho, não um dia.

O maior risco não é técnico: **12 dados comerciais da Blue Care ainda não foram homologados** (mensalidade, horários, telefone, planos, app). Sem eles a ANA transfere para humano em toda pergunta comercial. Isso precisa do Ricardo/Gustavo, não de SQL.

---

## 2. CONSTANTES — cole isto num bloco de notas antes de começar

| Nome | Valor |
|---|---|
| Workspace Blue Care **PROD** | `6125b945-641c-4255-9cf5-81bbf2387ef5` |
| Workspace Blue Care **DEV** | `b2f92f46-65cd-4f3d-b5ae-5dbf73cab0b0` |
| Workspace Mais Saúde PROD (**NÃO TOCAR**) | `9838d25b-60de-45e7-b7b7-31cc56b12ccc` |
| `frontdesk_accounts.id` da BC PROD | `9296c382-784a-404e-96fc-65b98309f83e` |
| Chatwoot account BC | `12` · Mais Saúde: `9` (**não tocar**) |
| Agent instance ANA (mesmo id DEV/PROD) | `c4ea218d-631a-45eb-a733-83409a809e1b` |
| Supabase PROD | project `ddnwemmvsuiibgbzjpwx` |
| Supabase DEV | project `szkzkyexagunvadzzaec` |
| Postgres Chatwoot PROD | `postgresql://postgres:FfRUABvClzxlUIxywIeaPzLmeGiIqsWq@ballast.proxy.rlwy.net:42985/railway` |
| Campanha boleto | `0ad47dde-d9e6-4a28-b3d8-b170e5306340` |
| Campanha cartão | `91805b50-f05f-4858-9295-99bd6d3f8d46` |
| Klaus (Chatwoot PROD) | user id `17`, `klaus@klaos.ai` |
| Matheus (Chatwoot PROD) | user id `10`, `matheus@matheus.pro.br` |

> **ARMADILHA DE NOME:** o workspace da Blue Care se chama **"Blue Care Mais Saude"** e a Mais Saúde se chama **"Mais Saúde 24h"**. **Nunca selecione workspace/conta por nome. Sempre por UUID ou por id numérico.**

> **ARMADILHA DE TOKEN (polaridade invertida):**
> | Coluna | 97 chars | 161 chars |
> |---|---|---|
> | `frontdesk_accounts.admin_access_token_encrypted` | Matheus / token próprio da conta — **errado** | Klaus — **certo** |
> | `agent_instances.frontdesk_chatwoot_bot_token` | bot token — **certo** | adminToken gravado no lugar — **errado** |
>
> A regra "161 = quebrado" vale **só** para a coluna de bot. Na tabela de contas é o inverso. Em Blue Care PROD o admin token do Matheus também dá 97 — então **o tamanho não discrimina** ali; valide pelo remetente da mensagem no smoke.

---

## 3. BLOCO A — EXECUTÁVEL AGORA (não depende do número WABA)

Ordem obrigatória. Cada passo tem gate de verificação; **não avance sem o gate verde**.

---

### A0 · Código + deploy do backend KLaOS PROD (PRÉ-REQUISITO DE TUDO)

**O que faz:** sem isto, o passo A3 (webhook) falha em silêncio ou com HTTP 422, e o `frontdesk_bot_id` da bridge nasce NULL (quebrando o kill-switch da ANA).

Três coisas precisam estar na `main` antes do deploy:

**A0.1 — Confirmar que o fix de unwrap está na main**
```bash
cd C:\dev\gmb\klaos
git fetch origin
git merge-base --is-ancestor ace3338c origin/main && echo "FIX UNWRAP OK"
```
Sem `ace3338c`, `listWebhooks` devolve `{webhooks:[...]}` em vez de array, o match por URL não acha nada e a API responde `200 {"success":true}` **sem** `webhookId` — falha silenciosa.

**A0.2 — Corrigir a lista de eventos (o mesmo commit `ace3338c` introduziu uma lista inválida)**

Arquivo: `C:\dev\gmb\klaos\server\src\services\frontdesk\frontdeskConfig.ts` (linhas 6-27). Deixar exatamente:
```ts
export const FRONTDESK_ACCOUNT_WEBHOOK_EVENTS = [
  'contact_created',
  'contact_updated',
  'conversation_created',
  'conversation_status_changed',
  'conversation_updated',
  'message_created',
  'message_updated',
];
```
Removidos: `contact_deleted`, `conversation_resolved`, `agent_bot_created/updated/deleted` — **não existem** em `Webhook::ALLOWED_WEBHOOK_EVENTS` (`app/models/webhook.rb:32-34`) nem em `KLAOS_EVENT_BRIDGE_EXTRA_EVENTS` (`custom/config/initializers/klaos_event_bridge.rb:50-54`). A validação do Chatwoot é all-or-nothing: **um evento inválido = 422 e nada é gravado**, para *todos* os workspaces, inclusive Mais Saúde no próximo reconcile.
Removidos também `inbox_*` / `team_*`: o handler de `/frontdesk-account/:id` (`frontdeskAccountController:82`) descarta tudo que não é `contact_updated` naquele caminho — assinar ali só gera entrega desperdiçada.

**A0.3 — Fazer a bridge gravar o `frontdesk_bot_id` (G24)**

1. `server/src/services/frontdesk/frontdeskBridge.service.ts`, após a linha ~619 (`botResult = await this.ensureAgentBot(...)`):
```ts
await supabase.from('agent_frontdesk_bridge')
  .update({ frontdesk_bot_id: botResult.botId, updated_at: new Date().toISOString() })
  .eq('id', config.id);
```
2. `server/src/controllers/agentInstance.controller.ts`, após o update das linhas 2238-2241 (`reprovisionChatwootBot`):
```ts
await supabase.from('agent_frontdesk_bridge')
  .update({ frontdesk_bot_id: botId, updated_at: new Date().toISOString() })
  .eq('agent_instance_id', id);
```
Sem isso, `deactivateBridge` (linha 889) não desanexa o bot da inbox — o kill-switch "desligar ANA" marca `is_active=false` no KLaOS e **deixa a ANA respondendo cliente no Frontdesk**.

**A0.4 — Corrigir o DEV de quebra (ponteiro morto 103 → 104)**
```sql
-- Supabase DEV (szkzkyexagunvadzzaec)
UPDATE agent_frontdesk_bridge
SET frontdesk_bot_id = 104, updated_at = now()
WHERE id = 'ac3cbbc0-9298-486d-8b45-cdbbfbe12663'
  AND workspace_id = 'b2f92f46-65cd-4f3d-b5ae-5dbf73cab0b0'
  AND frontdesk_bot_id = 103;
```
> **NÃO delete o agent_bot 104 em DEV.** O bot 103 **não existe** no Chatwoot; o 104 é o único bot da conta 12, o único com `access_token` e o único ligado à inbox 38. Deletá-lo derruba a ANA em DEV.

**Gate A0:** commit na `main`, deploy do backend KLaOS PROD concluído, e no Railway o deploy ativo é posterior ao commit da correção.

**Reversão:** `git revert` + redeploy. Nenhuma escrita de dados.

---

### A1 · Klaus vira admin da conta 12 e o workspace passa a apontar para ele (G01)

**O que faz:** hoje toda escrita automática do KLaOS na Blue Care carimba "Matheus" (pessoa física), violando a regra permanente de que ação automática sai como Klaus. São **duas mudanças, em dois bancos, em ordem obrigatória**.

> **PERIGO:** fazer só o passo A1.2 (repontar `frontdesk_accounts`) **sem** o A1.1 troca um problema cosmético por indisponibilidade total — o Chatwoot escopa por membership e devolve 401/404 em todo `/api/v1/accounts/12/*`.
> **NÃO** use o reprovisionamento do KLaOS: `frontdeskProvisioning.service.ts:359-362` grava `admin_email: owner.email`, e o dono do workspace BC em PROD **é o Matheus** — reprovisionar recria o gap.

**A1.0 — Snapshot obrigatório (sem ele o rollback é impossível)**
```sql
-- Supabase PROD (ddnwemmvsuiibgbzjpwx)
CREATE TABLE frontdesk_accounts_bkp_g01 AS
SELECT * FROM frontdesk_accounts
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
```

**A1.1 — Membership do Klaus na conta 12 (Chatwoot PROD). FAZER PRIMEIRO.**

Opção A (canônica, Platform API):
```bash
curl -X POST 'https://app-desk.klaos.ai/platform/api/v1/accounts/12/account_users' \
  -H "api_access_token: $FRONTDESK_PLATFORM_API_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"user_id": 17, "role": "administrator"}'
```
Opção B (SQL direto, idempotente):
```sql
-- Postgres Chatwoot PROD
INSERT INTO account_users
  (account_id, user_id, role, availability, auto_offline, active_at, created_at, updated_at)
SELECT 12, 17, 1, 0, false, NOW(), NOW(), NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM account_users WHERE account_id = 12 AND user_id = 17
);
```
`role=1` = administrator; `availability=0` / `auto_offline=false` replicam a linha id=46 (Klaus na conta 9).

**Gate A1.1 (obrigatório antes de seguir):**
```sql
SELECT account_id, user_id, role FROM account_users WHERE account_id = 12 AND user_id = 17;
-- esperado: 1 linha, role = 1
```

**A1.2 — Repontar o workspace (Supabase PROD). Só depois do gate acima.**
```sql
UPDATE frontdesk_accounts
SET chatwoot_admin_user_id       = 17,
    admin_email                  = 'klaus@klaos.ai',
    admin_access_token_encrypted = (
      SELECT admin_access_token_encrypted
      FROM frontdesk_accounts
      WHERE chatwoot_account_id = 9
      LIMIT 1
    ),
    admin_password_encrypted     = NULL,
    use_devise_auth              = false,
    updated_at                   = NOW()
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
```
- **NÃO** alterar `admin_user_id` (UUID Supabase). Nas 3 contas já migradas ela continua sendo o dono humano original. Na BC fica `8c2ed517-ff43-4909-b052-00443090ebd0`.
- Não há token novo a gerar: o ciphertext do Klaus é **byte-idêntico** nas contas 9, 10 e 11 (md5 `1dd114bedf3b498a47e3a7520d4a830e`). A subquery copia PROD→PROD, sem manipular valor em claro.
- **NUNCA** copie ciphertext de DEV para PROD — `ENCRYPTION_SECRET` é diferente por ambiente e o fallback de `getDecryptedAccessToken` (linhas 1072-1084) mascara o erro reescrevendo a coluna.

**Gate A1.2:**
```sql
SELECT chatwoot_account_id, chatwoot_admin_user_id, admin_email,
       length(admin_access_token_encrypted) AS tok_len,
       md5(admin_access_token_encrypted)    AS tok_md5
FROM frontdesk_accounts ORDER BY chatwoot_account_id;
-- esperado nas 4 linhas: user 17 / klaus@klaos.ai / 161 / 1dd114bedf3b498a47e3a7520d4a830e
```
Sem restart: `getDecryptedAccessToken` lê o Supabase a cada chamada, não há cache em processo.

**Reversão:**
```sql
UPDATE frontdesk_accounts f
SET chatwoot_admin_user_id       = b.chatwoot_admin_user_id,
    admin_email                  = b.admin_email,
    admin_access_token_encrypted = b.admin_access_token_encrypted,
    admin_password_encrypted     = b.admin_password_encrypted,
    use_devise_auth              = b.use_devise_auth
FROM frontdesk_accounts_bkp_g01 b
WHERE f.id = b.id;
-- opcional: DELETE FROM account_users WHERE account_id=12 AND user_id=17;
```

> **A partir daqui, todo token de admin da conta 12 é o do Klaus (48 chars em claro).** Obtenha-o em `access_tokens` (`owner_type='User'`, `owner_id=17`) ou pelo Profile Settings do Klaus. **Não use sessão de humano no browser para escrita.**

---

### A2 · Paridade de `custom_attributes` da conta 12 (G06 — parte real)

**O que faz:** a chave que bloqueia (`klaos_workspace_id`) **já existe e está correta** em PROD. Faltam duas flags opt-in, com default-off, que não quebram nada mas mudam o comportamento visível.

```sql
-- Postgres Chatwoot PROD
UPDATE accounts
SET custom_attributes = custom_attributes
  || '{"klaos_human_message_template": "**Atendente {FIRST_NAME_UPPER}:**\n"}'::jsonb
  || '{"klaos_auto_assignment_offline_fallback": true}'::jsonb
WHERE id = 12;
```

**Gate:**
```sql
SELECT id, name, jsonb_pretty(custom_attributes) FROM accounts WHERE id IN (9,12);
-- conta 12 esperada com 3 chaves; klaos_workspace_id = 6125b945-641c-4255-9cf5-81bbf2387ef5
```

**Reversão:** `UPDATE accounts SET custom_attributes = custom_attributes - 'klaos_human_message_template' - 'klaos_auto_assignment_offline_fallback' WHERE id = 12;`

---

### A3 · Webhook da conta 12: secret HMAC + eventos certos + matar o webhook legado (G03+G04+G05)

**O que faz:** hoje a conta 12 tem **dois** webhooks, e o assinado nos eventos certos aponta para uma rota morta:

| id | URL | subscriptions | estado |
|---|---|---|---|
| 13 | `https://api.klaos.ai/api/webhooks/frontdesk` | conversation_created/status_changed/updated, message_created/updated | **rota legada, não processa nada em PROD** |
| 14 | `https://api.klaos.ai/api/webhooks/frontdesk-account/9296c382-...` | somente `contact_updated` | rota viva, **rejeitada com 401** |

O 401 do webhook 14 **não é** falta de env var: `FRONTDESK_WEBHOOK_SECRET` **existe** no Railway KLaOS production (32 chars). É justamente a presença dele que transforma um fail-open num 401 — o middleware assina com a chave do env em vez do `secret` do próprio webhook (24 chars, `has_secure_token` do Rails). **Alinhar o env com o webhook é impossível por construção** (32 ≠ 24).

Referência correta = Mais Saúde (conta 9): **um único** webhook (id 9), na URL account-scoped, com secret por conta.

**A3.0 — Pré-check**
```sql
-- Supabase PROD
SELECT id, chatwoot_account_id, chatwoot_account_webhook_id,
       length(webhook_hmac_secret_encrypted) AS hmac_len
FROM frontdesk_accounts WHERE id = '9296c382-784a-404e-96fc-65b98309f83e';
-- esperado ANTES: webhook_id NULL, hmac_len NULL. Se já vier 14/97, alguém corrigiu — pare.
```

**A3.1 — Ensaio em DEV primeiro (regra dev-first; conserta o DEV de quebra)**

O `frontdesk_account` da BC DEV é `a7eee0c3-2a49-4255-bfae-47fc8a5bd237` (workspace `b2f92f46-...`). Rode o mesmo POST contra a API de dev e confirme que `hmac_len` sai de NULL para 97.

**A3.2 — Reconcile em PROD (um único call: subscriptions + secret + id)**
```bash
curl -X POST https://api.klaos.ai/api/frontdesk/register-contact-webhook \
  -H "Authorization: Bearer <JWT KLaOS de owner/admin do workspace Blue Care>" \
  -H "X-Workspace-Id: 6125b945-641c-4255-9cf5-81bbf2387ef5" \
  -H "Content-Type: application/json" \
  -d '{}'
```
Resposta esperada: `{"success":true,"webhookId":14}`.
Se vier `{"success":true}` **sem** `webhookId` → **PARE**: o deploy do A0 não pegou. Não aceite como sucesso.

Por dentro (`frontdeskProvisioning.service.ts:1962-2014`): `createWebhook` → 422 "URL already taken" → `listWebhooks` → casa pela URL com o webhook 14 → `updateWebhook` com os 7 eventos → grava `chatwoot_account_webhook_id=14` → encripta o `secret` devolvido e persiste.

> **NÃO use** `POST /api/admin/frontdesk/register-contact-webhooks` (rota em massa). O filtro é `status='active' AND chatwoot_account_webhook_id IS NULL`, o que hoje **também pega a Aupes Seguros (conta 11, viva, 12 conversas / 348 mensagens)** e ampliaria as subscriptions dela sem ninguém pedir.
> **NÃO** faça `UPDATE ... SET webhook_hmac_secret_encrypted = '<algo gerado>'`. A coluna guarda AES-256-CBC `ivhex:cipherhex`; texto puro faz `decrypt` lançar exceção e o 401 continua idêntico. E segredo gerado nunca casa com o `has_secure_token` do Chatwoot.

**A3.3 — Deletar o webhook legado 13 (obrigatório)**

Uma coluna de secret, dois webhooks com secrets diferentes. Depois do A3.2 a coluna guarda o secret do 14; o 13 passa a ser validado contra a chave errada e continua em 401 — só muda a mensagem. O webhook 14 já cobre os 5 eventos que o 13 cobria.

UI: `https://app-desk.klaos.ai` → conta "Blue Care Mais Saude" → Configurações → Integrações → Webhooks → localizar a linha `https://api.klaos.ai/api/webhooks/frontdesk` → (...) → Excluir.
**NÃO apague** a linha que contém `/frontdesk-account/`.

API:
```bash
curl -X DELETE "https://app-desk.klaos.ai/api/v1/accounts/12/webhooks/13" \
  -H "api_access_token: <access_token do Klaus, user 17>"
```

**Gate A3:**
```sql
-- Supabase PROD
SELECT chatwoot_account_webhook_id, length(webhook_hmac_secret_encrypted) AS hmac_len
FROM frontdesk_accounts WHERE id = '9296c382-784a-404e-96fc-65b98309f83e';
-- esperado: 14 | 97

-- Postgres Chatwoot PROD
SELECT id, url, subscriptions FROM webhooks WHERE account_id = 12;
-- esperado: 1 única linha, URL .../frontdesk-account/9296c382-784a-404e-96fc-65b98309f83e,
-- com 7 eventos: contact_created, contact_updated, conversation_created,
-- conversation_status_changed, conversation_updated, message_created, message_updated
```
Smoke (possível já): editar o nome de um contato qualquer na conta 12 e conferir no log do backend PROD `[FrontdeskAccountWebhook] received` com `frontdeskAccountId: 9296c382-...`. Se aparecer `Invalid signature`, o secret não foi gravado.

**Reversão:** `UPDATE frontdesk_accounts SET webhook_hmac_secret_encrypted=NULL, chatwoot_account_webhook_id=NULL WHERE id='9296c382-...';` (volta ao bug). Recriar o webhook 13 é desnecessário — a rota é morta.

---

### A4 · Convidar os usuários do cliente (G13) — INICIAR CEDO, tem espera humana

**O que faz:** hoje só o Matheus tem acesso. O aceite do convite é que dispara `autoProvisionFrontdeskOnAccept` → `provisionUser` com o token server-side. Começar agora porque depende de terceiros responderem.

**Dois achados que mudam a execução:**

1. **O Ricardo já existe** em `users` PROD (`ad54a439-e1c6-4e57-afb5-b089affa76e9`, criado 26/07 no mesmo microssegundo do workspace). A linha dele em `workspace_members` foi **hard-deletada** e o `invitation_token` **expirou em 02/08 13:40 UTC**. Ele é um usuário órfão, não um usuário inexistente.
2. **Existem dois Gustavos.** O da Blue Care é **`gustavopexecutivo@gmail.com`** (só existe em DEV). O `gustavooliveiranetwork@gmail.com` é outra pessoa e **já é admin ativo da Mais Saúde em PROD** — **não tocar**.

> **NÃO use o painel `/admin`** (`adminService.inviteUser` → RPC `create_user_with_invitation`) para o Ricardo. Como o user dele já existe, a RPC cai no ramo "existing user" e retorna **sem** `invitation_token`; `admin.service.ts:1547` então **não envia e-mail nenhum**. Ele seria adicionado silenciosamente com uma senha aleatória que ninguém tem.
> **NÃO use a API de agentes do Chatwoot** — dispara e-mail com marca "Chatwoot".

**A4.0 — Pré-check**
```sql
-- Supabase PROD
SELECT u.email, u.id AS user_id, u.email_verified, u.must_reset_password,
       (u.invitation_token IS NOT NULL) AS tem_token, u.invitation_expires_at,
       wm.role, wm.status
FROM users u
LEFT JOIN workspace_members wm
  ON wm.user_id = u.id AND wm.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
WHERE u.email IN ('ricardobluecare@gmail.com','gustavopexecutivo@gmail.com',
                  'lauuraclinicabaronesa@gmail.com','leticiaclinicabaronesa@gmail.com');
-- esperado hoje: 1 linha (ricardo, wm.role NULL)
```

**A4.1 — Autenticar como owner do workspace (único owner: matheus@matheus.pro.br)**
```bash
curl -s -X POST https://app.klaos.ai/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"matheus@matheus.pro.br","password":"<SENHA>"}'
export TK="<accessToken>"
```

**A4.2 — Criar os convites** (roles válidos: `viewer` | `user` | `admin`)
```bash
# Ricardo — admin (estado final validado em DEV; NÃO usar 'user' do convite antigo)
curl -s -X POST https://app.klaos.ai/api/workspaces/6125b945-641c-4255-9cf5-81bbf2387ef5/invitations \
  -H "Authorization: Bearer $TK" -H 'Content-Type: application/json' \
  -d '{"email":"ricardobluecare@gmail.com","role":"admin"}'

# Gustavo — admin. ATENÇÃO: gustavoPEXECUTIVO, não gustavooliveiranetwork.
curl -s -X POST https://app.klaos.ai/api/workspaces/6125b945-641c-4255-9cf5-81bbf2387ef5/invitations \
  -H "Authorization: Bearer $TK" -H 'Content-Type: application/json' \
  -d '{"email":"gustavopexecutivo@gmail.com","role":"admin"}'

# As duas atendentes — role user. SÓ com confirmação do Ricardo.
# (em DEV esses 2 convites estão pendentes desde sempre, nunca foram aceitos/validados)
curl -s -X POST https://app.klaos.ai/api/workspaces/6125b945-641c-4255-9cf5-81bbf2387ef5/invitations \
  -H "Authorization: Bearer $TK" -H 'Content-Type: application/json' \
  -d '{"email":"lauuraclinicabaronesa@gmail.com","role":"user"}'
curl -s -X POST https://app.klaos.ai/api/workspaces/6125b945-641c-4255-9cf5-81bbf2387ef5/invitations \
  -H "Authorization: Bearer $TK" -H 'Content-Type: application/json' \
  -d '{"email":"leticiaclinicabaronesa@gmail.com","role":"user"}'
```

**A4.3 — Se o e-mail não chegar, entregar o link na mão (não recriar o convite)**
```sql
SELECT email, role, expires_at,
       'https://app.klaos.ai/accept-invitation/' || token::text AS link
FROM workspace_invitations
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5' AND accepted_at IS NULL
ORDER BY created_at DESC;
```
Confirme antes o `APP_URL` do serviço KLaOS API em PROD no Railway. Validade: 7 dias.

**A4.4 — OBRIGATÓRIO só para o Ricardo:** depois de aceitar, ele precisa clicar **"Esqueci minha senha"**. O ramo `existingUser` do accept (`invitation.service.ts:333-448`) nunca toca `password_hash` — ele fica membro e agente, mas com o hash da senha temporária de 26/07 que ninguém conhece. `email_verified=false` não é bloqueio (`auth.service.ts:119` marca no primeiro login).

**Gate A4:**
```sql
SELECT u.email, wm.role, wm.status, fu.chatwoot_user_id, fu.chatwoot_role,
       fu.status AS fd_status, fu.frontdesk_access_enabled, fu.error_message
FROM workspace_members wm
JOIN users u ON u.id = wm.user_id
LEFT JOIN frontdesk_users fu ON fu.user_id = wm.user_id AND fu.workspace_id = wm.workspace_id
WHERE wm.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
ORDER BY wm.joined_at;
-- aceite: cada convidado com wm.status='active', fu.chatwoot_user_id NOT NULL,
-- fu.status='active', fu.error_message NULL
```
Validação visual (Playwright): logar como Ricardo em `app-desk.klaos.ai` (passa pelo SSO) e confirmar que ele cai na conta 12 e **não enxerga a conta 9**.

---

### A5 · Criar os times, popular o espelho e fechar o `handoff_team_map` (G07+G08)

**O que faz:** a conta 12 tem **zero** times no Chatwoot PROD (a Mais Saúde tem 6, ids 2..7) e `workspaces.settings.handoff_team_map` da BC PROD é **NULL**. Com 0 times, `getTeamEnumKeys` devolve enum vazio, `resolveTeamId` retorna null e **o handoff recusa 100% das transferências, em silêncio**.

> **Times vivem no Postgres do Chatwoot.** `frontdesk_teams` no Supabase é um **espelho** alimentado por webhook — e **PROD não assina `team_created`** (ver A3: a lista de 7 eventos não inclui `team_*`, e por bom motivo: o handler daquela rota os descarta). Portanto **o espelho não se preenche sozinho em PROD** e precisa de escrita explícita. Contar `frontdesk_teams` **não prova nada** sobre a existência do time.

**A5.0 — Decisões pendentes antes de executar** (ver §6)
- **7 ou 9 times?** O Chatwoot DEV tem 9 (os dois `unidade-*` foram criados em 01/08 e nunca chegaram ao espelho). O espelho DEV mostra 7. Confirmar com o Ricardo se `unidade-centro` e `unidade-sao-benedito` entram já.
- **Grafia:** `cobranca` (sem cedilha, alinhado ao `normalizeTeamKey` e ao script) **ou** `cobrança` (como a Mais Saúde)? Escolha **uma** e mantenha. As chaves do mapa são independentes do `name`, então aliases cobrem as duas.

**A5.1 — Pré-check**
```sql
-- Postgres Chatwoot PROD
SELECT id, name FROM teams WHERE account_id = 12;      -- esperado: 0 linhas
SELECT last_value FROM teams_id_seq;                    -- hoje 12 -> os novos nascem em 13..21
```
Se voltar linha, **pare** — alguém já executou.

**A5.2 — Criar os times pelo KLaOS (escreve Chatwoot + espelho no mesmo fluxo)**

UI (preferido): `app.klaos.ai` → workspace "Blue Care Mais Saude" → menu Frontdesk → Configurações → card Times → "Novo time", um a um.

API equivalente:
```bash
for T in cobranca cancelamento contratos vendas relacionamento pagamentos agendamento \
         unidade-centro unidade-sao-benedito; do
  curl -sS -X POST https://api.klaos.ai/api/frontdesk/teams \
    -H "Authorization: Bearer $KLAOS_JWT" \
    -H "X-Workspace-Id: 6125b945-641c-4255-9cf5-81bbf2387ef5" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$T\"}"; echo; sleep 1
done
```
Nome é UNIQUE por account e sofre downcase no `before_validation` — repetir dá erro claro, não duplica. Não copiar a description do DEV de `vendas` (é literalmente `vendas (DEV) — stub`).

**A5.3 — Colher os IDs REAIS (nunca chutar, nunca copiar do DEV)**
```sql
-- Postgres Chatwoot PROD
SELECT id, name, allow_auto_assign FROM teams WHERE account_id = 12 ORDER BY id;
```

**A5.4 — Conferir o espelho; se ficou para trás, popular à mão**
```sql
-- Supabase PROD
SELECT chatwoot_team_id, name, agent_count FROM frontdesk_teams
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5' ORDER BY chatwoot_team_id;
```
Se faltar linha, **descubra primeiro qual é a unique key real** — há relato conflitante:
```sql
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint WHERE conrelid = 'frontdesk_teams'::regclass AND contype = 'u';
```
e só então use o `ON CONFLICT` correspondente (`(frontdesk_account_id, chatwoot_team_id)` **ou** `(workspace_id, chatwoot_team_id)`; usar o errado estoura 42P10):
```sql
INSERT INTO frontdesk_teams
  (workspace_id, frontdesk_account_id, chatwoot_team_id, name, agent_count, created_at, updated_at)
VALUES
  ('6125b945-641c-4255-9cf5-81bbf2387ef5','9296c382-784a-404e-96fc-65b98309f83e',<ID_REAL>,'cobranca',0,now(),now())
  -- uma linha por time, com os IDs colhidos em A5.3
ON CONFLICT (<a constraint que existir>) DO UPDATE SET name = EXCLUDED.name, updated_at = now();
```

**A5.5 — Escrever o `handoff_team_map`**

Confirme a rota real antes (há divergência entre `/api/workspace/handoff-map` e `/api/workspaces/handoff-team-map`):
```bash
grep -rn "handoff.team.map\|handoff-map" C:/dev/gmb/klaos/server/src/routes/
```
Depois:
```bash
curl -sS -X PUT https://api.klaos.ai/api/<ROTA_CONFIRMADA> \
  -H "Authorization: Bearer $KLAOS_JWT" \
  -H "X-Workspace-Id: 6125b945-641c-4255-9cf5-81bbf2387ef5" \
  -H "Content-Type: application/json" \
  -d '{"handoff_team_map":{
    "cobranca":<ID>,"cobrancas":<ID>,"regularizacao":<ID_cobranca>,
    "cancelamento":<ID>,"cancelamentos":<ID>,
    "contratos":<ID>,"contrato":<ID>,"dependentes":<ID_contratos>,"cadastro-inativo":<ID_contratos>,
    "vendas":<ID>,"plano":<ID_vendas>,
    "relacionamento":<ID>,"suporte":<ID_relacionamento>,"default":<ID_relacionamento>,
    "pagamentos":<ID>,"boletos":<ID_pagamentos>,
    "agendamento":<ID>,"consultas":<ID_agendamento>,"exames":<ID_agendamento>,
    "consultas-e-exames":<ID_agendamento>
  }}'
```
O PUT é **replace total**; hoje o mapa é NULL, então não há o que preservar. Ele valida cada `team_id` contra `frontdesk_teams` — por isso A5.4 vem antes (senão: 400 "team_id(s) inválidos ou fora deste workspace").

> **O ERRO MAIS PROVÁVEL DA SEGUNDA:** copiar o mapa do DEV (ids 16..24). Em PROD os times nascem em 13..21 — os ids 16..21 **existem** mas apontam para times **diferentes**. O mapa ficaria silenciosamente trocado (ex.: "cobranca" mandando para "vendas") e a validação **não pegaria**, porque são ids válidos do mesmo tenant. Só o gate V3 pega isso. **Monte sempre por nome, a partir do A5.3.**

**Gate A5:**
```sql
-- Chatwoot PROD: 7 ou 9 linhas
SELECT id, name FROM teams WHERE account_id = 12 ORDER BY id;
-- Supabase PROD: mesmo count
SELECT count(*) FROM frontdesk_teams WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
-- Supabase PROD: todo valor tem que existir na primeira query
SELECT jsonb_pretty(settings->'handoff_team_map') FROM workspaces
WHERE id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
```
Playwright: `app-desk.klaos.ai` → conta Blue Care → Settings → Teams → ver os times na tela. Não aceitar só o SQL.

**Reversão:** apagar os times pela UI do KLaOS (o delete remove nos dois lados), `DELETE FROM frontdesk_teams WHERE workspace_id='6125b945-...'`, e `UPDATE workspaces SET settings = settings - 'handoff_team_map' WHERE id='6125b945-...'`. Como a conta 12 tem 0 conversas, não há `conversation.team_id` para orfanar. O cache `teamEnumCache` tem TTL de alguns minutos.

---

### A6 · Vincular os agentes aos times (G09a)

**Depende de:** A4 (usuários aceitos) + A5 (times criados).

UI: `/frontdesk` → Configurações → Times → em cada time, "Gerenciar agentes".
API (idempotente — faz GET atual, diff, POST adiciona / DELETE remove; passe a lista **completa** desejada):
```bash
curl -sS -X PUT https://api.klaos.ai/api/frontdesk/teams/<UUID_frontdesk_teams>/agents \
  -H "Authorization: Bearer $KLAOS_JWT" \
  -H "X-Workspace-Id: 6125b945-641c-4255-9cf5-81bbf2387ef5" \
  -H "Content-Type: application/json" \
  -d '{"agentIds":[<chatwoot_user_id_1>,<chatwoot_user_id_2>]}'
```
Espelho de intenção vindo do DEV — **mapear pelos e-mails, nunca pelos user_ids do DEV**:

| Time | Membros |
|---|---|
| cobranca | ricardobluecare@gmail.com |
| cancelamento | gustavopexecutivo@gmail.com |
| contratos | gustavooliveiranetwork@gmail.com + gustavopexecutivo@gmail.com |
| vendas | gustavopexecutivo@gmail.com |
| relacionamento | gustavooliveiranetwork@gmail.com + ricardobluecare@gmail.com |
| pagamentos | gustavooliveiranetwork@gmail.com + ricardobluecare@gmail.com |
| agendamento | gustavooliveiranetwork@gmail.com |

> Atenção: `gustavooliveiranetwork@gmail.com` aparece nesse mapa de DEV, mas em **PROD** ele já é admin da Mais Saúde. Confirmar com o Ricardo se ele deve mesmo entrar na Blue Care antes de convidá-lo (A4 não o inclui de propósito).

**Gate A6:**
```sql
SELECT t.id, t.name, count(tm.user_id) AS membros
FROM teams t LEFT JOIN team_members tm ON tm.team_id = t.id
WHERE t.account_id = 12 GROUP BY t.id, t.name ORDER BY t.id;
-- membros >= 1 em cobranca e cancelamento no mínimo
```

---

### A7 · Criar as 28 labels da conta 12 (G10)

**O que faz:** a conta 12 tem **1** label (`auto-resolvida-inatividade`, id 79, criada pelo job de auto-resolve). As 28 que campanhas, steps e código referenciam **não existem** — o que significa que os 12 `HUMAN_STOP_LABELS` estão inalcançáveis pelo humano e o gatilho `cobrar-agora` está morto.

Premissa técnica confirmada: `Labelable` usa `update!(label_list:)` = acts_as_taggable_on, que grava em `tags`/`taggings`. Label aplicada por automação **não aparece** na sidebar nem no filtro se o registro `Label` não existir.

**Três correções sobre a versão original desta tarefa:**
1. Falta `cobrar-agora` na lista original (`klaosDesk.service.ts:27`). São **28**, não 27.
2. `convenio-cancelado` **com hífen**. `humanStopLabels.ts:16` declara com hífen e o match é `.includes()` exato. DEV e a Mais Saúde têm `convenio_cancelado` com **underscore** — esse stop label já está morto nos dois. **Não copiar o bug.**
3. Não usar o bloco §5.8 do SDD da Mais Saúde: tem `cobranca_1d` com underscore, `cobranca-d21` (a BC usa `transbordo-humano`) e **nenhuma** das 6 labels `cartao-*`.

**Caminho A (recomendado — via API, invalida o cache do front corretamente)**
```bash
export FD_URL='https://app-desk.klaos.ai'
export FD_TOKEN='<access_token do Klaus, user 17>'

cat > /tmp/labels_bc12.txt <<'EOF'
blue-care|#1F73B7
pagamento-realizado|#BBF7D0
pagamento-em-verificacao|#FFA500
transbordo-humano|#F6AD75
cobrar-agora|#FF6B6B
lembrete-5d|#A78BFA
cobranca-0d|#BFDBFE
cobranca-1d|#DDD6FE
cobranca-7d|#FBCFE8
cobranca-15d|#FDBA74
cartao-lembrete-5d|#A78BFA
cartao-cobranca-0d|#BFDBFE
cartao-recusado-1d|#FCA5A5
cartao-cobranca-7d|#FBCFE8
cartao-cobranca-15d|#FDBA74
cartao-transbordo|#F6AD75
cancelado|#1F2937
quer-cancelar|#FCD356
cancelamento-pendente|#E9E593
convenio-cancelado|#1F2937
enviado-ao-spc|#F97316
cobranca-promessa|#908262
cobranca-promessa-hoje|#CCEFC4
cobranca-negociacao|#816C25
cobranca-segunda-via|#DFF3DF
cobranca-cartao-recusado|#FCA5A5
cobranca-cartao-pendente|#FCD34D
cobranca-boleto-pendente|#FCD34D
EOF

while IFS='|' read -r title color; do
  [ -z "$title" ] && continue
  code=$(curl -s -o /tmp/lbl_out.json -w '%{http_code}' \
    -X POST "$FD_URL/api/v1/accounts/12/labels" \
    -H "api_access_token: $FD_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"label\":{\"title\":\"$title\",\"color\":\"$color\",\"show_on_sidebar\":true}}")
  echo "$title -> HTTP $code"
  [ "$code" != "200" ] && cat /tmp/lbl_out.json && echo
done < /tmp/labels_bc12.txt
```
`422` = já existe (idempotente, seguir). `401` = token errado — pegar de novo, não insistir.

**Caminho B (fallback SQL)** — mesmo conjunto via `INSERT ... ON CONFLICT (title, account_id) DO NOTHING` dentro de `BEGIN/COMMIT`. **Obrigatório depois:** bumpar o cache, senão as labels não aparecem na tela. `Label` inclui `AccountCacheRevalidator` (`after_commit`) que reescreve `idb-cache-key-account-12-label` no Redis; INSERT direto pula o callback e o navegador continua servindo a lista velha. Jeito sem código: editar a cor de qualquer label da conta 12 pela UI e salvar. Com acesso ao app: `Account.find(12).reset_cache_keys`.

**Gate A7 (as duas queries):**
```sql
SELECT count(*) AS total, count(*) FILTER (WHERE show_on_sidebar) AS na_sidebar
FROM labels WHERE account_id = 12;
-- esperado: total = 29, na_sidebar = 29

-- esta TEM que voltar 0 linhas:
SELECT t.title FROM (VALUES
  ('blue-care'),('pagamento-realizado'),('pagamento-em-verificacao'),('transbordo-humano'),
  ('cobrar-agora'),('lembrete-5d'),('cobranca-0d'),('cobranca-1d'),('cobranca-7d'),('cobranca-15d'),
  ('cartao-lembrete-5d'),('cartao-cobranca-0d'),('cartao-recusado-1d'),('cartao-cobranca-7d'),
  ('cartao-cobranca-15d'),('cartao-transbordo'),('cancelado'),('quer-cancelar'),
  ('cancelamento-pendente'),('convenio-cancelado'),('enviado-ao-spc'),('cobranca-promessa'),
  ('cobranca-promessa-hoje'),('cobranca-negociacao'),('cobranca-segunda-via'),
  ('cobranca-cartao-recusado'),('cobranca-cartao-pendente'),('cobranca-boleto-pendente')
) AS t(title)
LEFT JOIN labels l ON l.account_id = 12 AND l.title = t.title
WHERE l.id IS NULL;
```
Playwright: Settings → Labels lista 29; o filtro de conversas mostra `cobrar-agora` e `cancelado` no dropdown.

> **NÃO** replicar as 48 labels do DEV em massa — arrasta lixo do Qualizap (`bomba`, `orcamento_caro`, `enviado_convênio` com acento) e o `convenio_cancelado` bugado.

**Reversão:** `DELETE FROM labels WHERE account_id=12 AND title <> 'auto-resolvida-inatividade';` + bump de cache. Não há dependent destroy e a conta tem 0 conversas — rollback limpo.

---

### A8 · Canned response `confirmacao_pagamento` (G12 — não bloqueia, mas é barato)

A conta 12 tem **zero** canned responses. O conteúdo canônico está na conta 9 (id=1), byte-idêntico ao de DEV: 162 chars / 174 bytes / md5 `c2c66c6641c09a58a01e48a2b4151204`.

```sql
-- Postgres Chatwoot PROD
SELECT count(*) FROM canned_responses WHERE account_id = 12;   -- pré-check: 0

INSERT INTO canned_responses (account_id, short_code, content, created_at, updated_at)
SELECT 12, src.short_code, src.content, NOW(), NOW()
FROM canned_responses src
WHERE src.id = 1 AND src.account_id = 9 AND src.short_code = 'confirmacao_pagamento'
  AND NOT EXISTS (SELECT 1 FROM canned_responses x
                  WHERE x.account_id = 12 AND x.short_code = 'confirmacao_pagamento');

-- opcional, paridade com BC DEV:
INSERT INTO canned_responses (account_id, short_code, content, created_at, updated_at)
SELECT 12, 'saudacao', 'Ola {{contact.name}} , como podemos ajudar?', NOW(), NOW()
WHERE NOT EXISTS (SELECT 1 FROM canned_responses WHERE account_id=12 AND short_code='saudacao');
```
O `INSERT ... SELECT` copia da própria linha para eliminar risco de mojibake — o texto tem acentos e emoji.

**Gate A8:**
```sql
SELECT id, account_id, short_code, length(content) AS chars,
       octet_length(content) AS bytes, md5(content)
FROM canned_responses WHERE account_id IN (9,12) AND short_code='confirmacao_pagamento'
ORDER BY account_id;
-- esperado: 2 linhas, ambas chars=162, bytes=174, md5=c2c66c6641c09a58a01e48a2b4151204
```
Se `bytes != 174`, o texto foi remontado com encoding quebrado — rollback e refazer.

> **NÃO copie as 31 canned responses da conta 9.** Várias são branded Mais Saúde (`+CANCELADO` cita "CARTAO MAIS SAUDE" e "Clínica Médica ATEND MED BH"). O `WHERE src.id = 1` fixa isso.

**Reversão:** `DELETE FROM canned_responses WHERE account_id=12 AND short_code IN ('confirmacao_pagamento','saudacao');`

---

### A9 · Homologar os 12 dados comerciais e sanear o prompt EM DEV (G16)

**Este é o único item que depende de terceiros e o único que pode atrasar a segunda.** Faça em paralelo com todo o resto.

**A9.1 — Coletar (não é SQL).** Mandar para o Ricardo/Gustavo e exigir resposta por escrito:

| # | Dado | Ocorrências no prompt |
|---|---|---|
| 1 | Horário de atendimento (setor de regularização) | 5 |
| 2 | Telefone de atendimento ao cliente (SAC) | 5 |
| 3 | Valor da mensalidade | 2 |
| 4 | Domínio do portal de boleto (ex.: `bluecaremaissaude.tenex.com.br`) | 1 |
| 5 | Horário comercial | 1 |
| 6 | Horário de contato permitido (janela legal de cobrança) | 1 |
| 7 | Horário do setor de agendamentos | 1 |
| 8 | Link do app Android | 1 |
| 9 | Link do app iPhone | 1 |
| 10 | Nome do app oficial | 1 |
| 11 | Nomes/tiers dos planos | 1 |
| 12 | Região/abrangência da rede credenciada | 1 |
| 13 | WhatsApp de agendamento (E.164) — está em `fixed_messages` | 1 |

O prompt tem **24 ocorrências** de `PENDENTE BLUE CARE`, das quais **3 são a meta-referência** dentro do bloco de guardrail e **devem ser preservadas**. Buracos reais: 21 ocorrências / 12 dados no `system_prompt` + 2 ocorrências / 1 dado novo em `fixed_messages.service_booking_redirect`.

**Não é urgente-crítico hoje:** o topo do prompt tem um bloco "DADOS COMERCIAIS PENDENTES DE HOMOLOGAÇÃO — PRECEDÊNCIA MÁXIMA" proibindo preencher, adivinhar ou enviar o marcador, mandando `transferir_para_time`. E os `fixed_messages` estão todos `enabled:false`. Não há caminho determinístico de vazamento. **O risco é: (a) o LLM desobedecer, (b) alguém ligar `enabled:true` sem sanear.**

**A9.2 — Sanear em DEV** (Supabase `szkzkyexagunvadzzaec`), em uma transação, com `replace()` **literal** por marcador — nunca `regexp_replace` genérico, que destruiria o bloco de guardrail. Gate obrigatório antes do commit:
```sql
SELECT (length(system_prompt)-length(replace(system_prompt,'PENDENTE BLUE CARE','')))/18 AS deve_ser_3,
       (length(fixed_messages::text)-length(replace(fixed_messages::text,'PENDENTE','')))/8 AS deve_ser_0,
       length(system_prompt) AS len_novo
FROM agent_instances WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b';
```
`deve_ser_3 <> 3` ou `deve_ser_0 <> 0` → **ROLLBACK** (algum literal foi digitado errado, tipicamente acento). Depois registrar como `v5` em `agent_prompt_versions` com `is_active=true` e desativar a v4.

**A9.3 — Smoke em DEV** (`app-desk-dev.klaos.ai`, contato de teste, **nunca devedor real**): "quanto custa o plano?", "qual o telefone de vocês?", "quero marcar uma consulta", "qual a diferença entre os planos?", "tem app?". Critério: nenhuma resposta contém `[` + `PENDENTE`; os valores citados são os do A9.1; a ANA não inventa preço.

> **CONSEQUÊNCIA IMPORTANTE PARA O A10:** se você sanear, o `system_prompt` **deixa de ter 91.705 chars e md5 `ecff1f087c565bbca9ae135c6618da02`**. Recalcule o par (length, md5) em DEV depois do saneamento e **use os valores novos** como gate no A10. Os números antigos só valem se A9 não for executado.

---

### A10 · Criar a ANA em PROD, pausada (G14+G15+G18+G19+G21+G22+G23)

**O que faz:** hoje `agent_instances` do workspace BC PROD tem **0 linhas**. Isso é o gap-pai de seis itens que foram catalogados como independentes e não são: `agent_config`, `fixed_messages`, tools, handoff config, guardrail e agent_bot **não podem existir antes da instância** (FK / `agent_instance_id NOT NULL`).

O agente nasce `status='paused'` e sem bot token — não responde ninguém. Isso é a válvula de segurança que permite fazer tudo isso antes do número.

**A10.1 — Replicar a instância DEV → PROD**

Script pronto, idempotente, com `DRY_RUN` por padrão:
`C:\Users\mathe\AppData\Local\Temp\claude\C--dev-gmb-frontdesk\92e4e7b0-d71c-4853-854b-c38f6c7dccc1\scratchpad\golive-ana-bluecare.ts` (verificado, existe).

```bash
cd C:\dev\gmb\klaos\server
SOURCE_SUPABASE_URL=https://szkzkyexagunvadzzaec.supabase.co \
SOURCE_SUPABASE_SERVICE_KEY=<service_role DEV> \
TARGET_SUPABASE_URL=https://ddnwemmvsuiibgbzjpwx.supabase.co \
TARGET_SUPABASE_SERVICE_KEY=<service_role PROD> \
DRY_RUN=1 npx ts-node "C:\Users\...\scratchpad\golive-ana-bluecare.ts"
```
Conferir os números impressos, então repetir com `DRY_RUN=0`.

O script já: remapeia `workspace_id` → `6125b945-...`; preserva o id `c4ea218d-...`; força `status='paused'`; zera `frontdesk_chatwoot_bot_id`, `frontdesk_chatwoot_bot_token`, `avatar_url`, `openai_api_key_encrypted` e contadores; grava o `system_prompt` na instância **e** a v1 ativa em `agent_prompt_versions`.

> **O `workspace_id` da Blue Care MUDA entre ambientes** (`b2f92f46...` em DEV, `6125b945...` em PROD). A Mais Saúde usa o mesmo UUID nos dois — por isso `golive-prod-lara.ts` assume igualdade. Qualquer cópia crua da BC **estoura FK ou some da UI**.
> **Grave a versão ativa, não só a coluna.** `agentBufferProcessor.service.ts:1036` resolve `resolveActivePrompt()` **antes** de cair em `agent.system_prompt`. Prova viva: em PROD, a coluna da Lara tem 33.141 chars (v51 defasada) e o que roda de verdade é a v55 com 88.276. Foi exatamente esse o bug que originou `copy-lara-prompt-versions.ts`.
> **NÃO copiar do DEV:** `frontdesk_chatwoot_bot_id=104` e o bot token (são do Chatwoot DEV — 401 ou postagem na conta errada); `avatar_url` (bucket do Supabase DEV); os `assign_team_id` 20/17 dentro de `fixed_messages` (times do Chatwoot DEV).

**A10.2 — Satélites, na mesma transação**

```sql
-- Supabase PROD. TUDO escopado por workspace_id da BC.
BEGIN;

-- tools: resolve por tool_name. Os UUIDs de agent_tool_definitions DIFEREM entre
-- DEV e PROD (ex.: consultar_debito = 355d9d27... em DEV vs d42123a4... em PROD).
-- ATENÇÃO: agent_instance_tools NÃO TEM FK em agent_instance_id — um INSERT com
-- UUID chutado cria 8 linhas órfãs COM SUCESSO e o checklist fica verde à toa.
INSERT INTO agent_instance_tools (workspace_id, agent_instance_id, tool_definition_id, is_enabled, config)
SELECT ai.workspace_id, ai.id, atd.id,
       (atd.tool_name <> 'gerar_link_pagamento'),   -- espelha o DEV: 7 on, 1 off
       '{}'::jsonb
FROM agent_instances ai
JOIN agent_tool_definitions atd
  ON atd.tool_name IN ('consultar_debito','confirmar_pagamento','registrar_promessa_pagamento',
                       'adicionar_label','transferir_para_time','marcar_resolvida',
                       'salvar_nome_contato','gerar_link_pagamento')
 AND atd.is_active = true
WHERE ai.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND ai.deleted_at IS NULL
ON CONFLICT (agent_instance_id, tool_definition_id)
DO UPDATE SET is_enabled = EXCLUDED.is_enabled, updated_at = now();

-- handoff config: UPSERT, não INSERT. createAgentInstance JÁ cria essa linha
-- com auto_handoff_enabled DEFAULT TRUE, que é justamente o valor perigoso,
-- e há UNIQUE (agent_instance_id) -> INSERT cego estoura 23505.
INSERT INTO agent_handoff_config (
  workspace_id, agent_instance_id, timeout_seconds, buffer_seconds,
  auto_handoff_enabled, trigger_keywords, confidence_threshold,
  frustration_detection, timeout_minutes, reopen_window_minutes,
  handoff_triggers, notification_config)
SELECT ai.workspace_id, ai.id, 900, 3,
       false,                                              -- O CAMPO QUE IMPORTA
       ARRAY['falar com humano','atendente','falar com alguém','pessoa real','reclamação']::text[],
       0.70, true, NULL, 1440,
       '{"keywords":[],"sensitive_topics":[],"detect_frustration":true,"low_confidence_threshold":0.6}'::jsonb,
       '{"notify_users":[],"notification_channel":"in_app"}'::jsonb
FROM agent_instances ai
WHERE ai.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5' AND ai.deleted_at IS NULL
ON CONFLICT (agent_instance_id) DO UPDATE SET
  auto_handoff_enabled = EXCLUDED.auto_handoff_enabled,
  timeout_seconds = EXCLUDED.timeout_seconds,
  reopen_window_minutes = EXCLUDED.reopen_window_minutes,
  updated_at = now();

-- guardrail: OPCIONAL, comprovadamente inerte hoje (a flag pii_guardrail_enabled
-- não existe em workspace_feature_flags para NENHUM workspace de PROD, e
-- input/output_guardrails_enabled só são testados com === false).
INSERT INTO agent_guardrail_configs (workspace_id, agent_instance_id,
  additional_blocked_topics, additional_blocked_keywords, allowed_topics,
  custom_blocked_response, output_guardrails_enabled, input_guardrails_enabled, pii_exceptions)
SELECT ai.workspace_id, ai.id, '{}','{}','{}', NULL, true, true, ARRAY['cpf','cnpj']::text[]
FROM agent_instances ai
WHERE ai.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5' AND ai.deleted_at IS NULL
ON CONFLICT (agent_instance_id) DO NOTHING;

COMMIT;
```

**Por que `auto_handoff_enabled=false` é obrigatório:** `getTimeoutConfig` (`agentBufferProcessor.service.ts:2967-2988`) retorna `900` quando a config é null e `POSITIVE_INFINITY` quando `auto_handoff_enabled=false`. Com o valor errado, após 15 min de inatividade o buffer processor dispara `triggerHandoff` **silencioso**, sem mensagem para o cliente, rodando lógica de SDR (`advanceDealStage 'leads_qualificados'`) num agente de cobrança. Regressão já vista em produção (caso DANIEL cw 1196, comentado no próprio código). Agentes que usam `transferir_para_time` — como a ANA — **devem** ter isso false.

**A10.3 — Criar o agent_bot no Chatwoot PROD (NUNCA copiar do DEV)**
```bash
curl -X POST https://api.klaos.ai/api/agents/instances/c4ea218d-631a-45eb-a733-83409a809e1b/reprovision-chatwoot-bot \
  -H "Authorization: Bearer <JWT_KLAOS_PROD>" \
  -H "X-Workspace-Id: 6125b945-641c-4255-9cf5-81bbf2387ef5" \
  -H "Content-Type: application/json"
```
O `outgoing_url` é montado pelo backend a partir de `FRONTDESK_WEBHOOK_BASE_URL`/`PUBLIC_BACKEND_URL` — ninguém digita. Path correto: **`/api/webhooks/agent-bot/<uuid>`** (não `chatwoot-bot`, que é alias legado).

> Alternativa de UI: `app.klaos.ai` → Agentes → "Sincronizar bots". **Confirme o seletor de workspace antes de clicar** — com "Mais Saúde" selecionado, o botão renomeia os bots da Mais Saúde em produção viva. Prefira o curl com `X-Workspace-Id` explícito.
> O provisionamento é fire-and-forget (`.catch(() => {})`, linha 212): **falha em silêncio**. O gate abaixo não é opcional.

**Gate A10:**
```sql
-- Supabase PROD
SELECT (SELECT count(*) FROM agent_instances       WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b') AS inst,
       (SELECT count(*) FROM agent_instance_tools  WHERE agent_instance_id='c4ea218d-631a-45eb-a733-83409a809e1b') AS tools,
       (SELECT count(*) FROM agent_handoff_config  WHERE agent_instance_id='c4ea218d-631a-45eb-a733-83409a809e1b') AS ho,
       (SELECT bool_and(auto_handoff_enabled) FROM agent_handoff_config WHERE agent_instance_id='c4ea218d-631a-45eb-a733-83409a809e1b') AS auto_ho,
       (SELECT status FROM agent_instances WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b') AS st,
       (SELECT length(system_prompt) FROM agent_instances WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b') AS sp_len,
       (SELECT frontdesk_chatwoot_bot_id FROM agent_instances WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b') AS bot_id;
-- esperado: 1 | 8 | 1 | false | paused | <len do prompt saneado> | <bot novo, != 104>

-- controle: a Mais Saúde não pode ter mudado
SELECT count(*) FROM agent_instances WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc';  -- 1 (Lara)
SELECT count(*) FROM agent_instance_tools WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc'; -- 8
```
```sql
-- Postgres Chatwoot PROD
SELECT b.id, b.account_id, b.name, b.outgoing_url,
       (SELECT count(*) FROM access_tokens t WHERE t.owner_type='AgentBot' AND t.owner_id=b.id) AS tem_token
FROM agent_bots b WHERE b.account_id = 12;
-- esperado: 1 linha, outgoing_url = https://api.klaos.ai/api/webhooks/agent-bot/c4ea218d-...,
-- tem_token = 1. Se tem_token = 0, o bot está quebrado: refazer A10.3.

-- controle: Mais Saúde intacta
SELECT id, name, outgoing_url FROM agent_bots WHERE account_id = 9;  -- bot 14 'Lara'
```

**Reversão:**
```sql
DELETE FROM waba_number_assignments WHERE agent_instance_id='c4ea218d-631a-45eb-a733-83409a809e1b'; -- FK sem cascade
DELETE FROM agent_instances WHERE id='c4ea218d-631a-45eb-a733-83409a809e1b';
```
O DELETE cascateia para tools, guardrail, handoff, bridge, widget e mais ~15 tabelas. As únicas FKs sem cascade são `waba_number_assignments` e `linkedin_accounts.default_agent_id`. O agent_bot fica órfão no Chatwoot — apagar pela UI ou deixar (sem bridge e sem inbox ele não recebe nada).
Parada de emergência sem desmontar nada: `UPDATE agent_instances SET status='paused' WHERE id='c4ea218d-...';`

---

## 4. BLOCO B — SEGUNDA-FEIRA, DEPOIS DO NÚMERO PORTADO

Estes passos **só podem existir depois que a inbox WhatsApp da conta 12 for criada**. Tempo estimado com o Bloco A pronto: ~40 minutos.

---

### B1 · Criar o canal / inbox WhatsApp na conta 12

Fora do escopo desta investigação (depende da decisão de arquitetura da WABA — ver §6). Ao final, anote o `inbox_id` real:
```sql
SELECT id, name, channel_type FROM inboxes WHERE account_id = 12;
```

> **ATENÇÃO CRÍTICA — WABA compartilhada.** Se a fase 1 reusar a WABA da Mais Saúde: um `phone_number_id` entrega em **um único callback**. Confirme a configuração de webhook **por número** no Meta (`POST /<phone_number_id>` com `webhook_configuration`, que tem precedência sobre o nível WABA) antes de mexer. E confirme que os filtros de template por prefixo (`before_save` guard, commits `9e099996a` / `55c079a75`) cobrem o canal novo — senão a Blue Care enxerga templates da Mais Saúde e vice-versa.

---

### B2 · Membership de inbox (G09b)

`custom/config/initializers/klaos_auto_assign_on_template.rb:58` exige `inbox.member_ids.include?(sender_id)`. Sem isso o auto-assign de template é fail-closed em 100% dos casos.

UI: `/frontdesk` → aba Canais → inbox → Agentes → adicionar os mesmos usuários do A6.

**Gate:**
```sql
SELECT i.id, i.name, (SELECT count(*) FROM inbox_members im WHERE im.inbox_id = i.id) AS membros
FROM inboxes i WHERE i.account_id = 12;
-- membros >= 1
```

---

### B3 · Ligar a bridge agente ↔ inbox e apontar as campanhas

**Por que é obrigatório:** `collectionEngine.service.ts:4030-4037` resolve o bot por
`agent_frontdesk_bridge.frontdesk_inbox_id = campaign.frontdesk_inbox_id`. Hoje a bridge tem 0 linhas e as duas campanhas têm `frontdesk_inbox_id = NULL` → o lookup volta vazio e o dispatch **cai no fallback admin token, enviando como HUMANO, silenciosamente, sem erro**. Criar a `agent_instance` não corrige isso.

Preferir a UI/API (`activateBridge`), que com o fix do A0.3 já grava o `frontdesk_bot_id`. Se for por SQL:
```sql
-- Supabase PROD. <INBOX_ID> = inbox WhatsApp da conta 12 (CONFERIR que é da account 12).
INSERT INTO agent_frontdesk_bridge
  (workspace_id, agent_instance_id, frontdesk_inbox_id, frontdesk_inbox_name,
   frontdesk_bot_id, is_active, mirror_all_messages, channel_type)
SELECT '6125b945-641c-4255-9cf5-81bbf2387ef5',
       'c4ea218d-631a-45eb-a733-83409a809e1b',
       <INBOX_ID>, '<nome da inbox>',
       frontdesk_chatwoot_bot_id, true, false, 'whatsapp'
FROM agent_instances WHERE id = 'c4ea218d-631a-45eb-a733-83409a809e1b';

UPDATE collection_campaigns
SET frontdesk_inbox_id = <INBOX_ID>, frontdesk_inbox_name = '<nome da inbox>'
WHERE id IN ('0ad47dde-d9e6-4a28-b3d8-b170e5306340','91805b50-f05f-4858-9295-99bd6d3f8d46');

UPDATE frontdesk_accounts SET default_inbox_id = <INBOX_ID>
WHERE workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';
```

**B3.1 — Backfill do ponteiro do bot (G24), caso a bridge tenha nascido com NULL**
```sql
-- dry-run: guarde o valor_atual, é o rollback
SELECT b.id AS bridge_id, b.frontdesk_inbox_id, b.frontdesk_bot_id AS valor_atual,
       ai.frontdesk_chatwoot_bot_id AS valor_novo
FROM agent_frontdesk_bridge b JOIN agent_instances ai ON ai.id = b.agent_instance_id
WHERE b.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5';

UPDATE agent_frontdesk_bridge b
SET frontdesk_bot_id = ai.frontdesk_chatwoot_bot_id, updated_at = now()
FROM agent_instances ai
WHERE ai.id = b.agent_instance_id
  AND b.workspace_id  = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND ai.workspace_id = '6125b945-641c-4255-9cf5-81bbf2387ef5'
  AND ai.frontdesk_chatwoot_bot_id IS NOT NULL
  AND (b.frontdesk_bot_id IS NULL OR b.frontdesk_bot_id <> ai.frontdesk_chatwoot_bot_id);
```
A **fonte da verdade é o Chatwoot**, não a instância:
```sql
SELECT abi.agent_bot_id, abi.inbox_id, i.name, ab.name, ab.outgoing_url
FROM agent_bot_inboxes abi
JOIN inboxes i ON i.id = abi.inbox_id
JOIN agent_bots ab ON ab.id = abi.agent_bot_id
WHERE abi.account_id = 12;
```
Se os números divergirem, use o do Chatwoot.
> **Nunca rode esse UPDATE sem o filtro de `workspace_id`** — alteraria a bridge da Mais Saúde (hoje corretamente 14).

---

### B4 · Ativar a ANA (só após homologação comercial do A9)

```sql
UPDATE agent_instances SET status = 'active'
WHERE id = 'c4ea218d-631a-45eb-a733-83409a809e1b';
```

**Smoke obrigatório antes de despausar qualquer campanha:** mandar mensagem **de um número seu** para a inbox e confirmar:
1. a resposta sai com autoria do **bot ANA**, não "Klaus" nem "Matheus";
2. o log traz `[CollectionEngine] reply_mode=ai_agent -> using bot token`;
3. não aparece `[FrontdeskAccountWebhook] Invalid signature`;
4. deixar a conversa parada 20 min e confirmar que ela **não** foi para `waiting_human` sozinha (prova o `auto_handoff_enabled=false`);
5. pedir "quero falar com cobrança" e confirmar que a conversa recebe `team_id`, sem o log `[ToolExecutor] handoff_team_map VAZIO`.

---

### B5 · Decidir e ligar os `fixed_messages` (G19-c / G20)

Os 6 blocos estão `enabled:false`, e é assim que devem ir para PROD. Ligar cada um é **decisão de produto**, item a item:

| Bloco | Depende de | Time destino |
|---|---|---|
| `human_request_handoff` | decisão | relacionamento |
| `product_inquiry_handoff` | decisão | relacionamento |
| `cancellation_immediate_handoff` | decisão | cancelamento |
| `service_booking_redirect` | **wa.me real + horário (A9)** | — (ou virar handoff para o time `agendamento`) |
| `out_of_office` | horário comercial (A9) | — |
| `intent_classifier_config.payment_claim` | decisão | — |

Para ligar, **use a API** (merge não-destrutivo por chave de topo), não SQL:
```
PUT https://api.klaos.ai/api/agent-instances/c4ea218d-631a-45eb-a733-83409a809e1b/fixed-messages
Body: {"human_request_handoff": { ...bloco COMPLETO com enabled:true... }}
```
> `payment_claimed_keywords` e `intent_classifier_config` **não têm rota nem UI** — só SQL. Isso é um gap de produto por si só.
> **Armadilha permanente:** a tela `AgentConfigure.tsx:401` monta `agent_config` só com 8 chaves e `agentInstance.service.ts:332` faz `.update({...updates})` **sem merge**. Um único "Salvar" na UI **apaga `sanitizer` e `auto_handoff`** em silêncio. Reconfira por SQL depois de qualquer edição na tela.

---

### B6 · Despausar as campanhas

Só depois de B4 verde e da decisão do B5. As duas campanhas (`0ad47dde...` boleto, `91805b50...` cartão) estão `status='paused'` com `permanent_labels={blue-care}`.

---

## 5. VERIFICAÇÃO FINAL — a bateria que prova paridade com a Mais Saúde

Rode tudo em sequência. Todos os valores esperados são literais.

### 5.1 Identidade e credenciais
```sql
-- Supabase PROD
SELECT chatwoot_account_id, chatwoot_admin_user_id, admin_email,
       length(admin_access_token_encrypted) AS tok_len,
       md5(admin_access_token_encrypted) AS tok_md5,
       chatwoot_account_webhook_id,
       length(webhook_hmac_secret_encrypted) AS hmac_len
FROM frontdesk_accounts ORDER BY chatwoot_account_id;
```
| esperado | valor |
|---|---|
| linhas | 4 (contas 9, 10, 11, 12) |
| `chatwoot_admin_user_id` | 17 nas 4 |
| `admin_email` | `klaus@klaos.ai` nas 4 |
| `tok_len` | 161 nas 4 |
| `tok_md5` | `1dd114bedf3b498a47e3a7520d4a830e` nas 4 |
| conta 12: `chatwoot_account_webhook_id` / `hmac_len` | `14` / `97` |

```sql
-- Chatwoot PROD
SELECT account_id, user_id, role FROM account_users WHERE account_id = 12 ORDER BY user_id;
-- tem que conter user 17 com role = 1
```

### 5.2 Webhook
```sql
-- Chatwoot PROD
SELECT id, url, jsonb_array_length(subscriptions) AS n, subscriptions
FROM webhooks WHERE account_id = 12;
```
Esperado: **1 única linha**, id 14, URL `https://api.klaos.ai/api/webhooks/frontdesk-account/9296c382-784a-404e-96fc-65b98309f83e`, `n = 7`, com `contact_created, contact_updated, conversation_created, conversation_status_changed, conversation_updated, message_created, message_updated`.

### 5.3 Estrutura da conta
```sql
-- Chatwoot PROD
SELECT a.id, a.name,
  (SELECT count(*) FROM account_users au WHERE au.account_id=a.id) AS usuarios,
  (SELECT count(*) FROM inboxes  i  WHERE i.account_id=a.id)       AS inboxes,
  (SELECT count(*) FROM teams    t  WHERE t.account_id=a.id)       AS times,
  (SELECT count(*) FROM labels   l  WHERE l.account_id=a.id)       AS labels,
  (SELECT count(*) FROM canned_responses c WHERE c.account_id=a.id) AS canned,
  (SELECT count(*) FROM agent_bots b WHERE b.account_id=a.id)      AS bots
FROM accounts a WHERE a.id IN (9,12) ORDER BY a.id;
```
| métrica | conta 9 (referência) | conta 12 esperada (fim do Bloco B) |
|---|---|---|
| usuarios | 7 | 4 a 6 (Klaus + Matheus + convidados) |
| inboxes | 2 | 1 |
| times | 6 | 7 ou 9 (decisão A5.0) |
| labels | 53 | 29 |
| canned | 31 | 1 ou 2 |
| bots | 1 | 1 |

Fim do **Bloco A** (antes do número): tudo igual, mas `inboxes = 0` e `bots = 1`.

### 5.4 Times, espelho e mapa
```sql
-- Chatwoot PROD
SELECT t.id, t.name, count(tm.user_id) AS membros
FROM teams t LEFT JOIN team_members tm ON tm.team_id=t.id
WHERE t.account_id=12 GROUP BY t.id, t.name ORDER BY t.id;

-- Supabase PROD
SELECT chatwoot_team_id, name, agent_count FROM frontdesk_teams
WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' ORDER BY chatwoot_team_id;

SELECT jsonb_pretty(settings->'handoff_team_map') FROM workspaces
WHERE id='6125b945-641c-4255-9cf5-81bbf2387ef5';
```
Critério: os três batem id a id; **todo valor do mapa existe na primeira query**; ids na faixa 13..21 (**nunca** 16..24 do DEV).

### 5.5 Agente
```sql
-- Supabase PROD
SELECT ai.agent_name, ai.status,
       length(ai.system_prompt)              AS sp_len,
       md5(ai.system_prompt)                 AS sp_md5,
       length(ai.collection_system_prompt)   AS csp_len,
       md5(ai.collection_system_prompt)      AS csp_md5,
       ai.frontdesk_chatwoot_bot_id,
       ai.avatar_url,
       (length(ai.system_prompt)-length(replace(ai.system_prompt,'PENDENTE','')))/8 AS pendentes,
       (SELECT count(*) FROM agent_instance_tools t WHERE t.agent_instance_id=ai.id) AS tools,
       (SELECT bool_and(h.auto_handoff_enabled) FROM agent_handoff_config h WHERE h.agent_instance_id=ai.id) AS auto_ho,
       (SELECT count(*) FROM agent_prompt_versions v WHERE v.agent_instance_id=ai.id AND v.is_active) AS versao_ativa
FROM agent_instances ai
WHERE ai.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5' AND ai.deleted_at IS NULL;
```
| campo | esperado |
|---|---|
| linhas | 1 |
| `status` | `paused` no fim do Bloco A; `active` no fim do B |
| `csp_len` / `csp_md5` | `919` / `bc28a980a172871dca593c882e4d9ab1` |
| `sp_len` / `sp_md5` | **sem A9:** `91705` / `ecff1f087c565bbca9ae135c6618da02` · **com A9:** o par recalculado em DEV |
| `pendentes` | `3` (só a meta-referência do guardrail) se A9 foi feito; `25` se não |
| `avatar_url` | `NULL` |
| `frontdesk_chatwoot_bot_id` | preenchido e **diferente de 104** |
| `tools` | `8` (7 `is_enabled=true`, `gerar_link_pagamento=false`) |
| `auto_ho` | **`false`** |
| `versao_ativa` | `1` |

```sql
-- controle Mais Saúde — NADA pode ter mudado
SELECT count(*) FROM agent_instances       WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc'; -- 1
SELECT count(*) FROM agent_instance_tools  WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc'; -- 8
SELECT version_number, is_active FROM agent_prompt_versions
WHERE agent_instance_id='1b092e03-9418-4352-956c-db0a560d904a' AND is_active;                          -- v55
SELECT frontdesk_bot_id FROM agent_frontdesk_bridge
WHERE workspace_id='9838d25b-60de-45e7-b7b7-31cc56b12ccc';                                             -- 14
```

### 5.6 Bridge e campanhas (só fim do Bloco B)
```sql
SELECT b.frontdesk_inbox_id, b.frontdesk_bot_id, b.is_active, b.channel_type,
       ai.frontdesk_chatwoot_bot_id
FROM agent_frontdesk_bridge b JOIN agent_instances ai ON ai.id = b.agent_instance_id
WHERE b.workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';
-- frontdesk_bot_id == frontdesk_chatwoot_bot_id, is_active = true, inbox_id preenchido

SELECT id, name, status, reply_mode, frontdesk_inbox_id, permanent_labels
FROM collection_campaigns WHERE workspace_id='6125b945-641c-4255-9cf5-81bbf2387ef5';
-- 2 linhas, frontdesk_inbox_id preenchido nas duas
```

### 5.7 Validação visual obrigatória (Playwright, com clique real)
1. `app-desk.klaos.ai` → conta "Blue Care Mais Saude" → Settings → Teams: os times aparecem.
2. Settings → Labels: 29 linhas; o dropdown de filtro de conversas lista `cobrar-agora` e `cancelado`.
3. Settings → Integrações → Webhooks: **uma única** linha, com `/frontdesk-account/`.
4. Settings → Respostas prontas: `confirmacao_pagamento` presente.
5. Login como Ricardo (via SSO): cai na conta 12 e **não enxerga a conta 9**.
6. Uma ação automática (label/assign) numa conversa de teste da BC aparece como **"Klaus"**.

---

## 6. RISCOS E ARMADILHAS

### 6.1 O que pode afetar a Mais Saúde (produção real, cobrança rodando)

| Risco | Probabilidade | Como evita |
|---|---|---|
| **Rota bulk de webhook** `POST /api/admin/frontdesk/register-contact-webhooks` — o filtro `chatwoot_account_webhook_id IS NULL` pega **a Aupes Seguros (conta 11, 12 conversas / 348 msgs, viva)** e amplia as subscriptions dela | Alta se alguém tiver pressa | Usar **só** a rota escopada com `X-Workspace-Id` |
| **"Sincronizar bots" com workspace errado selecionado** — `reconcileBots` percorre todos os agentes do workspace e renomeia o bot 14 de `Lara` para `Lara \| lara` em produção | Média | Usar o curl com `X-Workspace-Id` explícito; reversível pela UI (só nome de exibição) |
| **UPDATE sem `WHERE workspace_id`** em `frontdesk_accounts`, `agent_frontdesk_bridge` ou `agent_prompt_versions` | Média | Todo SQL deste runbook carrega o filtro; **nunca** remova |
| **Reconcile em massa com a lista de eventos inválida** (pré-A0.2) — o 422 não corrompe (o Chatwoot valida antes de gravar), mas o caminho de recuperação pode sobrescrever `chatwoot_account_webhook_id` / `webhook_hmac_secret_encrypted` da MS com valores parciais | Média sem o A0.2 | A0.2 antes de qualquer reconcile |
| **Selecionar conta/workspace por nome** — "Blue Care Mais Saude" vs "Mais Saúde 24h" | Média | Só por UUID / id numérico |
| Times, labels, canned responses, webhooks, `agent_instance_tools`, `agent_handoff_config` | **Nula** | Todos escopados por `account_id`/`workspace_id`; objetos distintos, sem constraint compartilhada |

### 6.2 WABA compartilhada MS ↔ Blue Care

Nada no **Bloco A** toca Meta, WABA, `phone_number_id` ou templates. Webhook do Chatwoot é HTTP interno; times e labels são locais; `agent_config` não passa por canal. **O risco de WABA mora inteiramente no Bloco B.**

Pontos de atenção quando o número entrar:
- **Um `phone_number_id` entrega em UM callback só.** Se a fase 1 reusar a WABA da Mais Saúde, a configuração de webhook **por número** no Meta (`POST /<phone_number_id>` com `webhook_configuration`, precedência sobre o nível WABA) é o único mecanismo que permite isolamento. Confirme antes de portar.
- **Templates:** o filtro por prefixo no `before_save` (commits `9e099996a`, `55c079a75`) tem que cobrir o canal novo. Sem isso, a Blue Care enxerga templates da Mais Saúde na UI e o job upstream de 3/3h repovoa a lista.
- **Decisão de arquitetura não confirmada:** se a fase 1 for reusar a inbox da conta 9, as conversas da Blue Care caem na **conta 9** e os times/labels/ANA criados na conta 12 **nunca serão usados**. Isso tornaria boa parte do Bloco A inútil. **Confirme com o Ricardo/Gustavo antes de executar o A5.**

### 6.3 Armadilhas que já derrubaram trabalho antes

1. **Copiar IDs entre ambientes.** Times (DEV 16..24 vs PROD 13..21), `agent_tool_definitions` (UUIDs diferentes), `frontdesk_chatwoot_bot_id` (104 é do Chatwoot DEV), `workspace_id` da Blue Care (muda entre ambientes, ao contrário da Mais Saúde). O caso mais insidioso: **ids 16..21 existem em PROD e apontam para times diferentes** — o mapa fica silenciosamente trocado e **nenhuma validação pega**.
2. **`agent_instance_tools` não tem FK em `agent_instance_id`.** Um INSERT com UUID errado **executa com sucesso**, cria 8 linhas órfãs e o checklist fica verde enquanto a ANA continua sem tools.
3. **`INSERT ... SELECT` que não encontra nada retorna 0 linhas sem erro.** Todo passo que depende de outro tem um gate contando linhas por isso.
4. **`agent_prompt_versions` é a autoridade, não `agent_instances.system_prompt`.** Provado em produção: a coluna da Lara tem 33.141 chars e o que roda é a v55 com 88.276.
5. **Um "Salvar" na tela de configuração do agente apaga `sanitizer` e `auto_handoff`.** Sem merge no servidor. Reconfira por SQL após qualquer edição na UI.
6. **`webhook_hmac_secret_encrypted` gerado à mão nunca funciona.** É AES `ivhex:cipherhex` e tem que casar com o `has_secure_token` do Chatwoot — só lendo o Chatwoot de volta.
7. **Copiar ciphertext de DEV para PROD.** `ENCRYPTION_SECRET` difere; o decrypt lança e o fallback **reescreve a coluna**, mascarando o erro.
8. **Ciphertext do Matheus se perde no A1.2.** Sem `frontdesk_accounts_bkp_g01` o rollback vira trabalho manual (gerar token novo pelo Chatwoot). O `CREATE TABLE` é obrigatório.
9. **`convenio_cancelado` com underscore** (DEV e Mais Saúde) vs `convenio-cancelado` com hífen (código). O match é `.includes()` exato. Copiar de qualquer um dos dois propaga o bug.
10. **Deletar o webhook errado no A3.3.** Apagar só o que termina em `/api/webhooks/frontdesk`, nunca o que contém `/frontdesk-account/`.
11. **Deletar o agent_bot 104 em DEV.** É o único da conta 12, o único com token e o único na inbox 38.
12. **Encoding.** O prompt (~91k chars) e a canned response têm acentos e emoji. Cliente SQL/HTTP truncando ou transcodificando é falha silenciosa — por isso todos os gates são por `length` + `md5` + `octet_length`.

### 6.4 Janela de execução

O Bloco A pode ser feito **em horário comercial**: a conta 12 tem 0 inboxes, 0 conversas e 0 mensagens — não há evento a perder e nenhum estado a corromper. As duas exceções são o A0 (deploy do backend, que afeta todos os workspaces) e qualquer coisa que toque `agent_prompt_versions` da Lara (§6.5), que exigem janela de baixo volume.

### 6.5 Item que NÃO deve entrar na segunda (G17)

A string `https://app-dev.klaos.ai/pay/` está no bloco "❌ ERRADO" do Exemplo 3 (Fluxo G) do prompt-mestre. Ela **não existe na Blue Care PROD** (não há agente lá) — existe na **Lara v55, ativa em produção há ~2 meses sem incidente**, e no clone ANA DEV v4. O literal `/pay/xxx` (3 chars) nem casa com a regex `{6,32}` do guard anti-alucinação, então a cópia literal é inerte. O residual é que o guard valida o **code**, não o **host**.

Corrigir exige **ativar uma versão nova da Lara em produção**, o que troca o prompt de todas as conversas ativas da Mais Saúde no próximo turno, sem rollout gradual. **Não fazer na segunda.** Agendar como higiene do prompt-mestre em janela própria (DEV primeiro, depois PROD), com gate de `length` caindo **exatamente 4 chars** (88276→88272 em PROD, 91705→91701 em DEV) e `INSERT + activate`, **nunca UPDATE** na versão ativa (reescreveria retroativamente um prompt já entregue e mataria o rollback).

---

## 7. O QUE NÃO FOI COBERTO — precisa de olho humano

### 7.1 Decisões de negócio bloqueantes (ninguém pode decidir por SQL)

1. **Os 12 dados comerciais do A9.1.** Sem eles a ANA transfere para humano em toda pergunta de preço/horário/plano/app. É o único item que pode fazer o go-live "funcionar tecnicamente e falhar comercialmente".
2. **A arquitetura da WABA na fase 1.** Se as conversas da Blue Care caírem na conta 9 (inbox compartilhada), boa parte do Bloco A (times, labels, ANA na conta 12) **não será usada**. Confirmar antes de executar o A5.
3. **Quais `fixed_messages` ligar** (B5) — 6 decisões independentes.
4. **7 ou 9 times** e **grafia com ou sem cedilha** (A5.0).
5. **`gustavooliveiranetwork@gmail.com` entra na Blue Care?** Ele aparece no mapa de times do DEV mas em PROD já é admin da Mais Saúde. O A4 não o convida de propósito.
6. **Laura e Letícia** — em DEV os convites nunca foram aceitos; ninguém validou esses e-mails/unidades.

### 7.2 Verificações que este runbook manda fazer mas não pôde resolver

- **Rota real do `handoff_team_map`.** Duas referências conflitantes (`/api/workspace/handoff-map` vs `/api/workspaces/handoff-team-map`). Grep antes de usar.
- **Unique constraint real de `frontdesk_teams`.** Um relato diz `(workspace_id, chatwoot_team_id)`, outro afirma que essa não existe e a real é `(frontdesk_account_id, chatwoot_team_id)` — usar a errada estoura 42P10. Query de `pg_constraint` incluída no A5.4.
- **Contagem de eventos em `FRONTDESK_ACCOUNT_WEBHOOK_EVENTS`.** Três leituras diferentes do mesmo arquivo (7, 9 e 18 eventos). A análise que cruzou com `Webhook::ALLOWED_WEBHOOK_EVENTS` + o prepend do fork aponta 7 e é a única que explica o 422. **Abra o arquivo e confirme antes de commitar o A0.2.**
- **`FRONTDESK_PLATFORM_API_TOKEN`** — não foi verificado se está disponível/válido. O A1.1 tem caminho SQL alternativo.
- **`APP_URL` do serviço KLaOS API em PROD** — necessário para montar o link de convite manual (A4.3).
- **Token do Klaus em claro** — depois do A1, todas as chamadas de API precisam dele. Não foi obtido nem verificado nesta investigação (deliberadamente: nenhum segredo foi lido ou transcrito).

### 7.3 Bugs latentes encontrados de passagem, fora do escopo

- **`agentBufferProcessor.service.ts:2857` lê `dbHandoffConfig.sensitive_topics`, coluna que não existe** em `agent_handoff_config` — sempre `undefined`.
- **`convenio_cancelado` com underscore na conta 9 (Mais Saúde)** — esse stop label está morto em produção hoje. Não mexer agora, mas registrar.
- **`payment_claimed_keywords` e `intent_classifier_config` não têm rota nem UI** em lugar nenhum do server. Só SQL. Gap de produto.
- **`agent_config` sobrescrito pela UI** (`AgentConfigure.tsx:401` + `agentInstance.service.ts:332` sem merge) — apaga `sanitizer` e `auto_handoff` a cada "Salvar". Merece fix no servidor.
- **Contas 10 (GMB) e 11 (Aupes) também estão com `webhook_hmac_secret_encrypted` NULL** e a Aupes com `chatwoot_account_webhook_id` NULL. A Aupes tem tráfego real. Fora do escopo Blue Care, mas é o mesmo defeito.
- **Nenhum webhook de PROD assina `team_*`**, então o espelho `frontdesk_teams` nunca se reconcilia sozinho — nem para a Mais Saúde. Enquanto isso for verdade, todo time criado fora do KLaOS fica invisível para a validação do `handoff_team_map`.

### 7.4 Não verificado nesta investigação

- Estado do canal/inbox WhatsApp e do processo de portabilidade do número (Bloco B1 inteiro).
- Configuração de webhook por número no Meta para a WABA compartilhada.
- Se a base de devedores da Blue Care já está sincronizada da Tenex, se `tenex_multi_meio_enabled` está ligada e se há enrollments nas duas réguas — **sem isso as campanhas despausam e não cobram ninguém, sem erro**.
- Conteúdo e aprovação dos templates Meta da Blue Care.
- Knowledge base / documentos RAG da ANA em PROD (o script do A10.1 copia `agent_documents`, mas o `KB_ID` precisa ser confirmado em DEV antes de rodar).