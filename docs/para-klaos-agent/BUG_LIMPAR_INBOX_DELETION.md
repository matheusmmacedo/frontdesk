# BUG — `/limpar` deleta inbox mas deixa conversas órfãs

| Campo | Valor |
|---|---|
| Status | **Reportado — aguarda fix no KLaOS** |
| Prioridade | 🔴 Crítica (quebra filtro "Ativas" + pode quebrar outros endpoints) |
| Descoberto | 2026-04-23 |
| Workaround Frontdesk | ✅ `custom/config/initializers/conversation_orphan_guard.rb` |
| Fix real | ⬜ Precisa ser no KLaOS |

## Sintoma

Endpoint `GET /api/v1/accounts/:id/conversations?status=active` → **500 Internal Server Error**.

Stack trace em runtime (dev):

```
ActionView::Template::Error (undefined method 'channel_type' for nil):
app/services/conversations/message_window_service.rb:18:in 'messaging_window'
app/services/conversations/message_window_service.rb:10:in 'can_reply?'
app/models/conversation.rb:128:in 'Conversation#can_reply?'
app/views/api/v1/conversations/partials/_conversation.json.jbuilder:44
```

## Causa raiz

O comando `/limpar` no KLaOS está deletando inboxes do Chatwoot (via `DELETE /api/v1/accounts/:id/inboxes/:id`) **sem garantir** que as conversas associadas sejam deletadas/movidas antes.

Resultado: `conversations` fica com `inbox_id` apontando pra uma linha que não existe mais em `inboxes`. Quando o jbuilder renderiza a listagem e chama `conversation.inbox.channel_type`, `inbox` é `nil` → crash.

Chatwoot tem `dependent: :destroy_async` na relação `Inbox has_many :conversations`, mas:
- O job `Inbox::DestroyJob` (ou similar) **é assíncrono**
- Se ele falha silenciosamente, as conversas ficam órfãs **permanentemente**
- O `/limpar` retorna sucesso mesmo se o cleanup cascade não rodou

## Evidência no DB dev (Mais Saúde)

Consulta pra listar conversas órfãs:

```sql
SELECT c.id, c.display_id, c.status, c.inbox_id, c.created_at::date
FROM conversations c
LEFT JOIN inboxes i ON i.id = c.inbox_id
WHERE c.account_id = 10 AND i.id IS NULL
ORDER BY c.id DESC;
```

Conta 10 = Mais Saúde dev. Só ficou o inbox 30 (KLaOS Cobranca) após limpeza recente. Conversas que estavam nos inboxes deletados (17, 18, 19, etc.) viraram órfãs.

## Workaround aplicado no Frontdesk (já em dev+prod)

Commit `0992446b8`:

```ruby
# custom/config/initializers/conversation_orphan_guard.rb
module KlaosConversationOrphanGuard
  def can_reply?
    return false if inbox.nil?
    super
  end
end

Rails.application.config.to_prepare do
  next unless defined?(Conversation)
  next if Conversation.include?(KlaosConversationOrphanGuard)
  Conversation.prepend(KlaosConversationOrphanGuard)
end
```

Evita o 500 na listagem. **Mas não resolve o problema de dados**: conversas órfãs continuam no DB, aparecem com "Ativas", e qualquer feature que dependa de `conversation.inbox` vai ter que saber lidar com nil.

## O que o KLaOS precisa fazer

**Opção A — Cleanup cascade no `/limpar`** (recomendado)

Antes de deletar uma inbox, deletar/reassign todas as conversas associadas:

```ts
async function limparInbox(accountId: number, inboxId: number) {
  // 1. Listar conversas da inbox
  const convs = await frontdeskAccountApi.listConversations(accountId, { inbox_id: inboxId });

  // 2. Deletar cada uma (ou reassign pra inbox default)
  for (const conv of convs) {
    await frontdeskAccountApi.deleteConversation(accountId, conv.display_id);
  }

  // 3. Agora sim deletar a inbox
  await frontdeskAccountApi.deleteInbox(accountId, inboxId);
}
```

**Opção B — Cleanup job separado** (pior, mas mais simples)

Após `/limpar` rodar, rodar um job que varre `conversations` com `inbox_id` apontando pra inboxes deletadas e deleta/arquiva.

## Cleanup manual em dev (fazer antes do merge pra prod do fix no KLaOS)

Se o fix do `/limpar` demorar, limpar os órfãos existentes:

```sql
-- 1. Ver quantos existem
SELECT COUNT(*) FROM conversations c
LEFT JOIN inboxes i ON i.id = c.inbox_id
WHERE i.id IS NULL;

-- 2. Se estiver OK com o número, deletar
DELETE FROM conversations c
WHERE c.inbox_id NOT IN (SELECT id FROM inboxes);

-- 3. Limpar messages órfãs também
DELETE FROM messages m
WHERE m.conversation_id NOT IN (SELECT id FROM conversations);
```

Rodar no dev DB via Railway preDeployCommand ou Supabase SQL Editor (Chatwoot DB — `ab30ff6b-...` Railway project, Postgres service).

## Critérios de sucesso

- [ ] Fix no comando `/limpar` do KLaOS pra cascade delete conversations antes de deletar inbox
- [ ] Cleanup dos órfãos existentes no dev (e prod se tiver)
- [ ] Teste: rodar `/limpar` e verificar que não sobra conversa com `inbox_id` inválido no DB
- [ ] Workaround do Frontdesk pode ser REMOVIDO depois que o KLaOS garantir que não cria mais órfãos — mas pode também ficar de cinto-e-suspensório.

## Contexto extra

- Isso **só manifestou** agora porque adicionamos filtro "Ativas" que inclui `pending + snoozed`. O filtro default "Abertas" não trazia essas conversas órfãs porque elas estavam `pending`/`snoozed`. Bug latente virou visível.
- Provavelmente outros endpoints também explodem (ex: buscar conversa específica que ficou órfã), só que nunca foram acessados.
