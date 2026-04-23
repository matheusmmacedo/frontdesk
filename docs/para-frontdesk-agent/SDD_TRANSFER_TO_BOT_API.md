# SDD — Endpoint de transferência pro bot

| Campo | Valor |
|---|---|
| Status | **Draft** |
| Prioridade | 🟡 Alta |
| Responsável | Agente Frontdesk |
| Data | 2026-04-23 |

## Objetivo

Expor endpoint que:
1. Muda conv pra `pending`
2. Remove assignee e team
3. Posta nota privada explicativa
4. Chama webhook pro KLaOS sincronizar estado interno

## Rota

`POST /api/v1/accounts/:account_id/conversations/:conversation_id/transfer_to_bot`

## Arquivos em `custom/`

### 1. Controller

`custom/app/controllers/api/v1/accounts/conversations/transfer_to_bot_controller.rb`

```ruby
class Api::V1::Accounts::Conversations::TransferToBotController < Api::V1::Accounts::Conversations::BaseController
  def create
    authorize_transfer!

    ActiveRecord::Base.transaction do
      @conversation.update_columns(assignee_id: nil, team_id: nil, status: Conversation.statuses[:pending])
      @conversation.messages.create!(
        content: I18n.t('conversations.activity.transferred_to_bot', user: current_user.name),
        message_type: :activity,
        account_id: @conversation.account_id,
        inbox_id: @conversation.inbox_id,
      )
    end

    notify_klaos_bridge(@conversation, current_user)
    head :no_content
  rescue StandardError => e
    Rails.logger.error("[TransferToBot] failed conv=#{@conversation.id}: #{e.class}: #{e.message}")
    render json: { error: 'Transfer failed' }, status: :unprocessable_entity
  end

  private

  def authorize_transfer!
    # Agentes da inbox + admins do account
    return if current_user.administrator?
    return if @conversation.inbox.inbox_members.exists?(user_id: current_user.id)
    render json: { error: 'Forbidden' }, status: :forbidden and return
  end

  def notify_klaos_bridge(conversation, user)
    # Busca webhook do KLaOS configurado pro account
    webhook_url = conversation.account.custom_attributes&.dig('klaos_bridge_webhook_url')
    return if webhook_url.blank?

    payload = {
      type: 'manual_transfer_to_bot',
      account_id: conversation.account_id,
      conversation_display_id: conversation.display_id,
      inbox_id: conversation.inbox_id,
      initiator: { id: user.id, name: user.name, email: user.email },
      timestamp: Time.current.iso8601,
    }

    # Fire-and-forget (não bloquear o request). Retry simples.
    KlaosBridgeWebhookJob.perform_later(webhook_url, payload)
  end
end
```

### 2. Rota

Chatwoot tem convenção de colocar rotas customizadas em `config/routes/custom.rb` (ou similar). Ver o padrão já usado em outras rotas custom (`crm_bridge_controller`). Se não existe, criar:

`custom/config/routes/custom_routes.rb`:
```ruby
Rails.application.routes.append do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :accounts, only: [] do
        resources :conversations, only: [] do
          post :transfer_to_bot, to: 'conversations/transfer_to_bot#create'
        end
      end
    end
  end
end
```

E require do custom initializer pra rota subir:
`custom/config/initializers/custom_routes.rb`:
```ruby
require_relative '../routes/custom_routes'
```

### 3. Webhook Job pro KLaOS

`custom/app/jobs/klaos_bridge_webhook_job.rb`:
```ruby
class KlaosBridgeWebhookJob < ApplicationJob
  queue_as :low
  retry_on RestClient::Exception, attempts: 3, wait: 5.seconds

  def perform(url, payload)
    RestClient::Request.execute(
      method: :post,
      url: url,
      payload: payload.to_json,
      headers: { content_type: :json, accept: :json },
      timeout: 5,
    )
  end
end
```

### 4. i18n (upstream, mínimo)

`app/javascript/dashboard/i18n/locale/pt_BR/conversation.json`:
```json
{
  "ACTIVITY": {
    "TRANSFERRED_TO_BOT": "Conversa devolvida ao bot por {user}."
  }
}
```

Idem en.

(Se tiver arquivo de backend i18n tipo `config/locales/conversation.pt.yml`, adicionar lá também pra `conversations.activity.transferred_to_bot`.)

## Config por account

Admin tem que setar o webhook do KLaOS:
```sql
UPDATE accounts
SET custom_attributes = COALESCE(custom_attributes, '{}'::jsonb) || '{"klaos_bridge_webhook_url": "https://api-dev.klaos.ai/api/webhooks/klaos/bridge-event"}'::jsonb
WHERE id = 10;
```

Idealmente via UI `Configurações → Integrações → KLaOS Bridge` mas v1 pode ser SQL manual.

## Segurança

- Endpoint exige auth (cookie do agente ou api_access_token de User)
- Bot NÃO pode chamar esse endpoint (bots têm whitelist em `access_token_auth_helper.rb`; não adicionar `transfer_to_bot` na whitelist)

## Critérios de sucesso

- [ ] POST com auth válido muda status + remove assignee + posta nota
- [ ] Sem auth → 401
- [ ] Auth de bot → 401 (não autorizado)
- [ ] Auth de agente NÃO-colaborador da inbox → 403
- [ ] Webhook pro KLaOS dispara se `klaos_bridge_webhook_url` estiver setado
- [ ] Erro no webhook não aborta a transferência (KLaOS side é eventually consistent)

## Relação

- Frontend: `SDD_TRANSFER_TO_BOT_BUTTON.md`
- KLaOS side: `../para-klaos-agent/SDD_REOPEN_POLICY.md` § "Dependência do Frontdesk agent"
