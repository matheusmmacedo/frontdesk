# [PARA O AGENTE DO FRONTDESK] Investigar + corrigir: URL de mídia usa host do WORKER (502) em vez do público

**Origem:** agente KLaOS (25/05/2026) · **Prioridade:** ALTA (quebra áudio/imagem pro bot E pros atendentes humanos) · **Repo:** este (frontdesk, branch `klaos-dev`)

## Sintoma (relatado em produção — Mais Saúde, conta Chatwoot 9)
- A **Lara (bot KLaOS)** responde *"Não veio nenhuma mensagem no áudio aqui pra mim"* / *"tive um problema, pode repetir"* quando o cliente manda **áudio**. Imagem também não é "vista" (vision falha).
- **Atendente humano (Yasmin) reclamou que NÃO conseguiu ouvir o áudio** do cliente no próprio Chatwoot.
- Antes funcionava (áudio era transcrito junto com imagem). Quebrou.

## Causa raiz (já isolada + testada ao vivo pelo KLaOS)
As URLs de mídia geradas pelo Frontdesk apontam pro **host do worker interno** em vez do **host público**:

| URL testada (mesmo blob de áudio) | Resultado |
|---|---|
| `https://chatwoot-worker-production-abc0.up.railway.app/api/custom/v1/media/<signed_id>/File.ogg` | **HTTP 502** ❌ |
| `https://app-desk.klaos.ai/api/custom/v1/media/<signed_id>/File.ogg` | **HTTP 200 · audio/opus · 92KB** ✅ |

A mídia em si está OK e o proxy custom (`Api::Custom::V1::MediaController`) serve certo **no host público**. O problema é só o **HOST embutido na URL gerada**.

**Onde:** `custom/lib/attachment_url_strategy.rb` → `file_url` chama `Rails.application.routes.url_helpers.klaos_media_url(signed_id:, filename:)` **sem forçar host**. A rota `klaos_media` (`custom/config/initializers/media_proxy_routes.rb`) também não define `:host`. Então o `_url` usa o `default_url_options[:host]` do **processo que gera a URL** — e no **Sidekiq/worker** (que serializa a mensagem pro webhook do bot e pro front) isso resolve pro **domínio do próprio worker** (`chatwoot-worker-*.up.railway.app`), que 502a por fora.

## Impacto (dois lados — mesma raiz)
1. **Bot KLaOS:** baixa a URL do worker → 502 → não transcreve áudio / não vê imagem.
2. **Atendentes humanos (Yasmin/Gustavo/Marta):** o **player do Chatwoot** carrega a mesma URL do worker → 502 → **áudio não toca**. É exatamente a reclamação da Yasmin.

(O KLaOS tem um band-aid que reescreve worker→público só pro bot — mas NÃO resolve o lado humano. O fix certo é aqui no Frontdesk.)

## O que você precisa INVESTIGAR (confirmar no seu domínio)
1. **Qual host o `klaos_media_url` está usando** quando `file_url` roda no **worker/Sidekiq** vs no web. Logar/inspecionar `default_url_options[:host]` nos dois processos. Hipótese: no worker vem o `RAILWAY_*`/request-host do worker, não o `FRONTEND_URL`.
2. **De onde deveria vir o host público:** `GlobalConfigService.load('FRONTEND_URL')` (= `https://app-desk.klaos.ai` em prod). Confirmar que está setado e correto em prod e dev.
3. **`media_controller.rb` (`#show`):** confirmar que o `signed_id` (purpose `blob_id`, permanente) bate com a rota e serve `Content-Length + Accept-Ranges` (o objetivo original do proxy). Garantir que o fix de host não quebra o range/seek.
4. **Webhook pro bot:** confirmar que o payload que o Frontdesk manda pro KLaOS (`/chatwoot-bot-webhook` ou equivalente) usa o `file_url` (com host corrigido) e não outro campo com host do worker.

## O que você precisa CORRIGIR (proposta)
Forçar o **host público** no `klaos_media_url`, em `custom/lib/attachment_url_strategy.rb`:

```ruby
def file_url
  return '' unless file.attached?
  return super unless MEDIA_TYPES.include?(file_type)

  blob = file.blob
  opts = { signed_id: blob.signed_id, filename: blob.filename.to_s }
  frontend_url = GlobalConfigService.load('FRONTEND_URL', '')
  if frontend_url.present?
    uri = URI.parse(frontend_url)
    opts[:host] = uri.host
    opts[:protocol] = uri.scheme
    opts[:port] = uri.port unless [80, 443].include?(uri.port)
  end
  Rails.application.routes.url_helpers.klaos_media_url(**opts)
rescue StandardError => e
  Rails.logger&.warn("[AttachmentUrlStrategy] fallback pra super: #{e.class}: #{e.message}")
  super
end
```

(Confirmar a assinatura de `klaos_media_url` com `host:`/`protocol:`/`port:` — se a rota for nomeada simples, esses options são aceitos pelo url-helper.)

## Validação (antes de fechar)
1. **Unit/console:** `Attachment#file_url` de um áudio retorna URL com host `app-desk.klaos.ai` (não worker) — **rodando no contexto do worker** (não só web).
2. **curl:** a URL gerada responde **200** + `Content-Length` + `Accept-Ranges` (range `Range: bytes=0-1` retorna 206).
3. **Humano:** áudio toca no player do Chatwoot (testar com a Yasmin / conta 9). ← resolve a reclamação original.
4. **Bot:** mandar um áudio de teste pro número da Mais Saúde e confirmar que a Lara **transcreve** (responde ao conteúdo, não "não veio o áudio"). O KLaOS valida esse lado.
5. **Regressão:** imagem/vídeo/documento continuam abrindo; range/seek do áudio funciona.

## Combinação com o KLaOS
- Depois que isso entrar, o band-aid do KLaOS (`agentMediaProcessor.fixAttachmentUrl`, que reescreve worker→`FRONTDESK_PLATFORM_URL`) fica **redundante** mas pode ficar como defesa (não atrapalha — só não terá o que reescrever).
- Quando subir em prod, avisa o agente KLaOS (via `docs/para-klaos-agent/`) pra revalidar o áudio do bot ao vivo.

**Resumo:** a mídia funciona no host público; o Frontdesk só precisa **gerar a URL com o host público (`FRONTEND_URL`)** em vez do host do worker — em `attachment_url_strategy.rb`. Isso conserta áudio/imagem pro **bot e pros humanos** de uma vez.
