# SDD — Timestamp de resolução para política de reabertura

| Campo | Valor |
|---|---|
| Status | **Draft** |
| Prioridade | 🟢 Média (opcional — KLaOS pode lidar sem) |
| Responsável | Agente Frontdesk |
| Data | 2026-04-23 |

## Contexto

A política de reabertura (`../para-klaos-agent/SDD_REOPEN_POLICY.md`) precisa saber quando uma conversa foi resolvida pra decidir se janela de X horas já passou.

KLaOS recebe webhook `conversation_resolved` e pode gravar `resolved_at` em `agent_conversations`. Mas:
- Pode ter lag (webhook pode falhar, job pode atrasar)
- Consulta reverse de "quando resolveu?" via Chatwoot API custa 1 request extra
- Ter o dado **no próprio Chatwoot** simplifica debug e operações

## Solução

Gravar `resolved_at` em `conversations.additional_attributes` no momento em que a transição `open → resolved` acontece.

## Arquivo

`custom/config/initializers/track_resolved_timestamp.rb`

```ruby
Rails.application.config.to_prepare do
  Conversation.class_eval do
    after_update_commit :klaos_track_resolved_timestamp

    def klaos_track_resolved_timestamp
      return unless saved_change_to_status?

      case status
      when 'resolved'
        extras = additional_attributes || {}
        extras = extras.merge(
          'klaos_resolved_at' => Time.current.iso8601,
          'klaos_last_assignee_id' => assignee_id,
          'klaos_last_team_id' => team_id,
        )
        update_column(:additional_attributes, extras)
      when 'pending'
        # Quando devolve pro bot (seja manual ou via reopen policy), limpar
        extras = additional_attributes || {}
        extras = extras.except('klaos_resolved_at')
        update_column(:additional_attributes, extras)
      end
    rescue StandardError => e
      Rails.logger.error("[TrackResolved] error conv=#{id}: #{e.class}: #{e.message}")
    end
  end
end
```

## Como KLaOS consome

Ao receber webhook `message_created` de conv resolved (Chatwoot vai reabrir automático), KLaOS lê `conversation.additional_attributes.klaos_resolved_at` e calcula:
```
horas_decorridas = now - klaos_resolved_at
if horas_decorridas > workspace.settings.reopen_policy.window_minutes / 60:
    devolve pro bot
else:
    tenta agente original
```

## Alternativa

KLaOS pode usar só o próprio `agent_conversations.resolved_at` (gravado quando ele recebe `conversation_resolved`). Esse SDD é **redundância defensiva** — útil se o webhook falhar.

## Critérios de sucesso

- [ ] Resolver conv → `additional_attributes.klaos_resolved_at` gravado
- [ ] Reabrir pra pending → campo removido
- [ ] Não introduz regressão em outras features (custom_attributes continuam funcionando)
- [ ] Visível via `SELECT additional_attributes FROM conversations WHERE id = X`
