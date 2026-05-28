# ✅ RESOLVIDO: URL de mídia com host do worker (502) → corrigido em DEV+PROD

**Resposta ao** `docs/para-frontdesk-agent/INVESTIGAR_MEDIA_URL_HOST.md` (agente KLaOS, 25/05/2026).
**Status:** corrigido e **validado ao vivo em produção** (25/05/2026).

## Causa raiz (mais funda que o spec supôs)
Não era bug no `attachment_url_strategy.rb`. Era o **ENV `FRONTEND_URL` do processo worker** apontando pro próprio domínio do worker:

| Serviço | FRONTEND_URL (antes) |
|---|---|
| web | `https://app-desk.klaos.ai` ✅ |
| **worker** | `https://chatwoot-worker-production-abc0.up.railway.app` ❌ |

`config/environments/production.rb` faz `default_url_options = { host: ENV['FRONTEND_URL'] }`. Como o `klaos_media_url` usa esse host, **toda URL gerada no worker** (webhook do bot + broadcast pro front) saía com o domínio do worker → 502 por fora.

> ⚠️ Nota pro fix proposto no spec: usar `GlobalConfigService.load('FRONTEND_URL')` **não resolveria**, porque **não há row `FRONTEND_URL` em `installation_configs`** → o GlobalConfigService cai pro mesmo ENV errado no worker.

## O que foi feito
Corrigido o ENV `FRONTEND_URL` do **worker** (dev e prod) pro host público:
- dev worker → `https://app-desk-dev.klaos.ai`
- prod worker → `https://app-desk.klaos.ai`

Conserta **globalmente** (mídia + e-mails + qualquer URL gerada no worker), zero mudança de código.

## Validação em prod (ao vivo)
1. Áudio real enviado pra Mais Saúde (conta 9, conv #868).
2. **Worker gerou URL com host `app-desk.klaos.ai`** (confirmado no log do `AgentBots::WebhookJob`).
3. **Lara leu o áudio** — respondeu ao conteúdo ("Tudo bem sim!"), não mais "não veio o áudio".
4. Proxy serve `200 · audio/mpeg · Content-Length · Accept-Ranges` (Range `bytes=0-1` → 206). Range/seek OK.

## Do lado de vocês
- O band-aid (`agentMediaProcessor.fixAttachmentUrl`, reescreve worker→`FRONTDESK_PLATFORM_URL`) ficou **redundante** — agora a URL já vem com host público. Pode manter como defesa; não terá o que reescrever.
- **Áudios antigos:** o bot **não** relê o histórico sozinho (já tinham falhado na hora). Daqui pra frente, lê normal.
- Podem **revalidar o áudio do bot ao vivo** quando quiserem.

## ⚠️ Gotcha de infra (pra não regredir)
Se o serviço worker for **recriado** no Railway, o `FRONTEND_URL` pode voltar a ser auto-setado pro domínio do próprio worker (foi assim que quebrou). Manter `FRONTEND_URL = <host público>` no worker é requisito.
