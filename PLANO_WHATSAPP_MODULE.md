# Plano Completo — Modulo WhatsApp (WABA + Evolution)

## Estado Atual (Diagnostico 2026-04-11)

### Arquitetura do Ecossistema
```
Meta Cloud API (WABA)     Evolution API (Baileys)
        |                         |
        v                         v
   Frontdesk (Chatwoot)  <--- WhatsApp Connection Pool
        |                         |
        +----------+--------------+
                   |
              Webhooks / Bot API
                   |
                   v
            KLaOS (Cerebro)
               - Agentes IA
               - Campanhas
               - CRM Bridge
```

**Regra**: Frontdesk = source of truth para canais e templates WABA.
KLaOS consome templates do Frontdesk e orquestra disparos.

---

## PROBLEMAS ENCONTRADOS

### P1. Templates WABA — Editor incompleto (CRITICO)
- [ ] Header media (IMAGE/VIDEO/DOCUMENT) tem opcao no UI mas NAO tem upload
- [ ] Sem validacao server-side de components (usa `components: {}` wildcard)
- [ ] Sem validacao de tamanho: body (1024), footer (60), button text (25)
- [ ] Formato de examples pode nao bater com o que Meta espera
- [ ] Substituicao de variaveis quebrada no preview (key mismatch)
- [ ] Linguas hardcoded (6 vs 100+ da Meta)
- [ ] Categorias hardcoded (falta TRANSACTIONAL)
- [ ] Tipos de botao faltando: OTP, COPY_CODE, CATALOG, FLOW
- [ ] Sem preview de media no TemplatePreview.vue
- [ ] allow_category_change hardcoded true, sem toggle

### P2. Evolution — Templates nao existem (MEDIO)
- [ ] Evolution nao usa templates Meta — usa mensagens livres
- [ ] Mas KLaOS pode querer enviar mensagens formatadas via Evolution
- [ ] Nao existe CRUD de "templates locais" para Evolution
- [ ] Nao existe interface de envio de mensagem ad-hoc

### P3. Conexao de Numero WABA — Webhook confuso (BAIXO)
- [ ] Comentario no code diz "NAO configurar webhooks" mas Channel::Whatsapp auto-configura via after_commit
- [ ] Funciona mas codigo confuso — corrigir comentario

### P4. Evolution Unlink — Inbox orfao (MEDIO)
- [ ] Evolution unlink so destroi channel, nao destroi inbox explicitamente
- [ ] Depende de cascade delete que pode falhar
- [ ] Meta unlink destroi inbox + channel corretamente

### P5. Evolution Link — Sem transaction (MEDIO)
- [ ] Se configure_evolution_chatwoot_integration falhar, channel fica criado mas sem integracao
- [ ] Inbox existe mas nao recebe mensagens
- [ ] Precisa transaction com rollback

### P6. Admin Token — Side effect na linkagem Evolution (BAIXO)
- [ ] find_or_create_api_token cria token se nao existe
- [ ] Side effect inesperado durante linking

### P7. Audio TTS falhando no WhatsApp (RESOLVIDO)
- [x] Fix aplicado: upload direto via Meta Media API com MIME correto

### P8. Webhook na criacao de instancia Evolution (RESOLVIDO)
- [x] configure_webhook() adicionado ao create_instance

---

## PLANO DE IMPLEMENTACAO

### FASE 1 — Fixes criticos (WABA Templates) [Prioridade ALTA]

#### 1.1 Backend: Validacao de components no controller
**Arquivo**: `custom/app/controllers/api/v1/accounts/whatsapp_connections/templates_controller.rb`

- Substituir `components: {}` por validacao explicita
- Validar tipos: HEADER, BODY, FOOTER, BUTTONS
- Validar formatos de header: TEXT, IMAGE, VIDEO, DOCUMENT
- Validar tamanhos: body <= 1024, footer <= 60, button text <= 25
- Validar tipos de botao: QUICK_REPLY, URL, PHONE_NUMBER
- Validar formato de URL (https)
- Validar formato de telefone (internacional)
- Validar contagem de variaveis

#### 1.2 Backend: Upload de media para header de template
**Arquivo**: `custom/app/services/whatsapp_connections/meta/template_crud_service.rb`

- Antes de criar template com header media, fazer upload do arquivo para Meta
- Endpoint Meta: `POST /{app-id}/uploads` → retorna handle
- Usar handle no component HEADER como `example.header_handle`
- Ou aceitar URL publica e deixar Meta baixar

#### 1.3 Frontend: TemplateEditor com suporte completo
**Arquivo**: `app/javascript/dashboard/routes/dashboard/settings/whatsappConnections/components/TemplateEditor.vue`

- Adicionar upload de arquivo para header IMAGE/VIDEO/DOCUMENT
- Adicionar validacao de tamanho em tempo real
- Expandir lista de linguas (buscar da Meta API ou lista completa)
- Expandir lista de categorias
- Adicionar toggle allow_category_change
- Corrigir formato de examples ({body_text: [[...]]})
- Adicionar validacao de URL para botoes URL
- Adicionar validacao de telefone para botoes PHONE_NUMBER

#### 1.4 Frontend: TemplatePreview corrigido
**Arquivo**: `app/javascript/dashboard/routes/dashboard/settings/whatsappConnections/components/TemplatePreview.vue`

- Corrigir substituicao de variaveis (key mismatch body_N vs N)
- Adicionar preview de imagem/video/documento no header
- Melhorar estilizacao para parecer com WhatsApp real
- Footer em cinza/menor como no WhatsApp

### FASE 2 — Fixes de estabilidade (Evolution) [Prioridade MEDIA]

#### 2.1 Evolution Unlink: destruir inbox explicitamente
**Arquivo**: `custom/app/services/whatsapp_connections/evolution/phone_linker_service.rb`

```ruby
def unlink
  raise 'Phone number is not linked' unless @phone_number_record.linked?
  channel = @phone_number_record.channel_whatsapp
  inbox = @phone_number_record.inbox
  @phone_number_record.mark_available!
  inbox&.destroy!
  channel&.destroy!
  true
end
```

#### 2.2 Evolution Link: transaction com rollback
**Arquivo**: `custom/app/services/whatsapp_connections/evolution/phone_linker_service.rb`

```ruby
def link
  validate_link!
  ActiveRecord::Base.transaction do
    channel, inbox = create_channel_and_inbox
    configure_evolution_chatwoot_integration(channel, inbox)
    @phone_number_record.mark_linked!(inbox: inbox, channel: channel)
    { channel: channel, inbox: inbox }
  end
end
```

Remover rescue do configure_evolution_chatwoot_integration para que erro faca rollback.

#### 2.3 Corrigir comentario de webhook no Meta linker
**Arquivo**: `custom/app/services/whatsapp_connections/meta/phone_linker_service.rb`

Atualizar comentario para refletir comportamento real (Channel::Whatsapp auto-configura via after_commit).

### FASE 3 — Templates Evolution (templates locais) [Prioridade MEDIA]

#### 3.1 Modelo: template local para Evolution
Evolution nao tem templates Meta, mas pode ter "mensagens salvas" que o KLaOS usa.

**Opcao A**: Usar o campo `message_templates` da WhatsappConnection para armazenar templates locais (formato livre, sem sync com Meta).

**Opcao B**: Criar tabela separada `evolution_message_templates` com:
- name, body, media_url, media_type, buttons (JSON)
- Sem aprovacao da Meta — envio livre

**Recomendacao**: Opcao A (reusar campo existente) com flag `provider: 'evolution'` para diferenciar.

#### 3.2 Frontend: editor de templates Evolution
- Form simples: nome, corpo da mensagem, media (opcional)
- Sem restricoes de categoria/aprovacao (Evolution e livre)
- Preview do WhatsApp

### FASE 4 — Integracao KLaOS aprimorada [Prioridade MEDIA]

#### 4.1 Sync de templates Frontdesk → KLaOS
- KLaOS ja le templates do Frontdesk via API
- Garantir que templates criados/editados no Frontdesk refletem no KLaOS
- Webhook de notificacao quando template muda (opcional)

#### 4.2 Evolution message dispatch via KLaOS
- KLaOS pode enviar mensagens via Evolution diretamente (ja tem evolutionApi.service.ts)
- Frontdesk deve saber que Evolution e gerenciado pelo KLaOS para campanhas
- Nao duplicar lógica — KLaOS orquestra, Frontdesk entrega

---

## PLANO DE TESTES COMPLETO

### T1. WABA — Conexao Meta Cloud

| # | Teste | Esperado | Status |
|---|-------|----------|--------|
| T1.1 | Criar conexao Meta via OAuth (Embedded Signup) | Conexao criada, numeros sincronizados | A testar |
| T1.2 | Criar conexao Meta via Direct Token | Conexao criada, numeros sincronizados | A testar |
| T1.3 | Sync de numeros (POST /sync_numbers) | Numeros atualizados da WABA | A testar |
| T1.4 | Listar numeros da conexao | Todos os numeros com status correto | A testar |
| T1.5 | Linkar numero a inbox | Channel::Whatsapp criado, inbox criado, webhook configurado | A testar |
| T1.6 | Enviar mensagem de texto pelo inbox linkado | Mensagem chega no WhatsApp do destinatario | A testar |
| T1.7 | Receber mensagem no inbox linkado | Mensagem aparece na conversa do Frontdesk | A testar |
| T1.8 | Unlinkar numero | Inbox e channel destruidos, numero volta a 'available' | A testar |
| T1.9 | Re-linkar numero depois de unlink | Funciona sem erro | A testar |
| T1.10 | Deletar conexao Meta | Todos numeros unlinkados, conexao removida | A testar |

### T2. WABA — Templates

| # | Teste | Esperado | Status |
|---|-------|----------|--------|
| T2.1 | Sync templates da Meta (POST /sync_templates) | Templates atualizados do WABA | A testar |
| T2.2 | Listar templates (GET /templates) | Lista completa com status | A testar |
| T2.3 | Criar template UTILITY com body texto simples | Template criado na Meta, status PENDING | A testar |
| T2.4 | Criar template com header TEXT + variaveis | Funciona, variaveis substituidas | A testar |
| T2.5 | Criar template com header IMAGE | Upload de imagem funciona, template criado | A testar |
| T2.6 | Criar template com header VIDEO | Upload de video funciona | A testar |
| T2.7 | Criar template com header DOCUMENT | Upload de documento funciona | A testar |
| T2.8 | Criar template com botao URL | Botao URL valido aceito | A testar |
| T2.9 | Criar template com botao PHONE_NUMBER | Botao telefone valido aceito | A testar |
| T2.10 | Criar template com botao QUICK_REPLY | Botao quick reply aceito | A testar |
| T2.11 | Criar template com 2+ botoes | Multiplos botoes aceitos | A testar |
| T2.12 | Criar template com footer | Footer aceito (max 60 chars) | A testar |
| T2.13 | Criar template com variaveis no body ({{1}}, {{2}}) | Variaveis aceitas com examples | A testar |
| T2.14 | Editar template APPROVED (mudar body) | Edicao enviada para Meta, status muda para PENDING | A testar |
| T2.15 | Editar template — mudar botoes | Botoes atualizados | A testar |
| T2.16 | Deletar template | Template removido da Meta e do Frontdesk | A testar |
| T2.17 | Preview de template com variaveis | Variaveis substituidas por examples no preview | A testar |
| T2.18 | Preview de template com imagem no header | Imagem aparece no preview | A testar |
| T2.19 | Validacao: body > 1024 chars | Erro de validacao no frontend | A testar |
| T2.20 | Validacao: footer > 60 chars | Erro de validacao | A testar |
| T2.21 | Validacao: button text > 25 chars | Erro de validacao | A testar |
| T2.22 | Validacao: nome invalido (com espacos/maiusculas) | Erro de validacao | A testar |
| T2.23 | Validacao: URL de botao sem https | Erro de validacao | A testar |
| T2.24 | Template com categoria MARKETING | Aceito | A testar |
| T2.25 | Template com categoria UTILITY | Aceito | A testar |
| T2.26 | Template com categoria AUTHENTICATION | Aceito | A testar |
| T2.27 | Sync apos criar/editar template | Templates atualizados automaticamente | A testar |

### T3. Evolution — Conexao e Instancias

| # | Teste | Esperado | Status |
|---|-------|----------|--------|
| T3.1 | Criar conexao Evolution | Conexao criada com status active | A testar |
| T3.2 | Criar instancia Evolution | Instancia criada, webhook configurado | A testar |
| T3.3 | Obter QR code da instancia | QR code base64 retornado | A testar |
| T3.4 | QR code auto-refresh apos 45s | Novo QR gerado automaticamente | A testar |
| T3.5 | Polling de status (4s interval) | Status atualizado em tempo real | A testar |
| T3.6 | Escanear QR e conectar | Status muda para 'open', telefone detectado | A testar |
| T3.7 | Linkar numero Evolution a inbox | Channel criado, Chatwoot integration configurada | A testar |
| T3.8 | Enviar mensagem texto pelo inbox | Mensagem chega no WhatsApp | A testar |
| T3.9 | Receber mensagem no inbox | Mensagem aparece no Frontdesk | A testar |
| T3.10 | Enviar imagem pelo inbox | Imagem chega no WhatsApp | A testar |
| T3.11 | Enviar audio pelo inbox | Audio chega no WhatsApp | A testar |
| T3.12 | Receber audio no inbox | Audio aparece no Frontdesk | A testar |
| T3.13 | Receber imagem no inbox | Imagem aparece no Frontdesk | A testar |
| T3.14 | Unlinkar numero Evolution | Inbox e channel destruidos, numero 'available' | A testar |
| T3.15 | Desconectar instancia | Logout do WhatsApp, status 'disconnected' | A testar |
| T3.16 | Deletar instancia | Evolution cleanup (disable → logout → delete), registro removido | A testar |
| T3.17 | Deletar conexao Evolution | Todas instancias limpas, conexao removida | A testar |
| T3.18 | Reconectar instancia desconectada | Novo QR code, reconexao funciona | A testar |
| T3.19 | Limite 1 conexao Evolution por conta | Segunda tentativa bloqueada | A testar |

### T4. Integracao KLaOS

| # | Teste | Esperado | Status |
|---|-------|----------|--------|
| T4.1 | Agent Bot responde em inbox WABA | Lara responde mensagem de texto | A testar |
| T4.2 | Agent Bot responde em inbox Evolution | Lara responde mensagem de texto | A testar |
| T4.3 | Agent Bot recebe e processa audio (Whisper) | Audio transcrito, Lara responde | A testar |
| T4.4 | Agent Bot envia audio TTS via WABA | Audio chega no WhatsApp (fix Media API) | A testar |
| T4.5 | Agent Bot recebe e processa imagem (Vision) | Imagem descrita, Lara responde | A testar |
| T4.6 | KLaOS envia template WABA via Frontdesk | Template enviado com variaveis preenchidas | A testar |
| T4.7 | KLaOS aplica/remove tags na conversa | Tags atualizadas no Frontdesk | A testar |
| T4.8 | KLaOS faz handoff para time humano | Conversa atribuida ao time correto | A testar |
| T4.9 | Webhook conversation_created chega ao KLaOS | KLaOS recebe e processa | A testar |
| T4.10 | Webhook message_created chega ao KLaOS | KLaOS recebe e processa | A testar |
| T4.11 | Webhook conversation_status_changed | KLaOS recebe quando conversa resolve | A testar |
| T4.12 | CRM Bridge: deal data na sidebar | custom_attributes aparecem na conversa | A testar |
| T4.13 | Campanha de cobranca dispara templates | Templates WABA enviados automaticamente | A testar |
| T4.14 | SSO KLaOS → Frontdesk | Abre Frontdesk sem login adicional | A testar |

### T5. Edge Cases e Erros

| # | Teste | Esperado | Status |
|---|-------|----------|--------|
| T5.1 | Token Meta expirado | Erro claro, solicita renovacao | A testar |
| T5.2 | Evolution API offline | Erro gracioso, nao quebra a app | A testar |
| T5.3 | Tentar linkar numero ja linkado | Erro: numero ja em uso | A testar |
| T5.4 | Tentar unlinkar numero nao linkado | Erro: numero nao esta linkado | A testar |
| T5.5 | Criar template com nome duplicado | Erro da Meta propagado | A testar |
| T5.6 | Editar template nao-APPROVED | Bloquear edicao no frontend | A testar |
| T5.7 | Deletar template em uso por campanha | Warning ou bloqueio | A testar |
| T5.8 | Conexao Meta sem numeros | Lista vazia, sem erro | A testar |
| T5.9 | QR code expira sem escanear | Auto-refresh gera novo QR | A testar |
| T5.10 | Perda de conexao WhatsApp Evolution | Status atualiza para disconnected | A testar |
| T5.11 | Envio de mensagem para numero invalido | Erro tratado, status failed | A testar |
| T5.12 | Upload de media > limite Meta (16MB) | Erro de validacao | A testar |

---

## ORDEM DE EXECUCAO

1. **Fase 2** (fixes de estabilidade) — Rapido, corrige bugs existentes
2. **Fase 1.1-1.2** (backend validacao + media upload) — Critico para templates
3. **Fase 1.3-1.4** (frontend editor + preview) — UI completa
4. **Fase 3** (templates Evolution) — Nice to have
5. **Fase 4** (integracao KLaOS) — Apos tudo funcionar
6. **Testes T1-T5** — Ao longo de cada fase

## ARQUIVOS ENVOLVIDOS

### Backend (custom/ — upstream-safe)
- `custom/app/controllers/api/v1/accounts/whatsapp_connections/templates_controller.rb`
- `custom/app/services/whatsapp_connections/meta/template_crud_service.rb`
- `custom/app/services/whatsapp_connections/meta/template_sync_service.rb`
- `custom/app/services/whatsapp_connections/evolution/phone_linker_service.rb`
- `custom/app/services/whatsapp_connections/evolution/api_client.rb`
- `custom/app/services/whatsapp_connections/evolution/instance_manager_service.rb`
- `custom/app/services/whatsapp_connections/meta/phone_linker_service.rb`

### Frontend (Vue — cuidado com upstream merges)
- `app/javascript/dashboard/routes/dashboard/settings/whatsappConnections/components/TemplateEditor.vue`
- `app/javascript/dashboard/routes/dashboard/settings/whatsappConnections/components/TemplatePreview.vue`
- `app/javascript/dashboard/routes/dashboard/settings/whatsappConnections/components/TemplateManager.vue`
- `app/javascript/dashboard/store/modules/whatsappConnections.js`
- `app/javascript/dashboard/api/whatsappConnections.js`

### KLaOS (referencia — nao modificar aqui)
- `server/src/services/waba/metaCloudApi.service.ts`
- `server/src/services/evolutionApi.service.ts`
- `server/src/services/frontdesk/frontdeskAccountApi.service.ts`
