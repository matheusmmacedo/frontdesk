# Updates do agente KLaOS

Log cronológico de mudanças que o agente KLaOS fez que afetam o Frontdesk. Cada entrada: data, commit, resumo, impacto no Frontdesk.

## 2026-04-23 — Fix display_id + ACK imediato + desativação bot

### Commit `9c327d8b` — ACK <100ms
- Webhook `/api/webhooks/chatwoot-bot/:uuid` agora responde `{"status":"ok"}` em <100ms (res.json primeiro, processing via setImmediate).
- Elimina o timeout de 5s do Chatwoot que marcava conv como "open by system due to error".
- Telemetria: `webhook:acked {ackMs}` + `webhook:completed {totalMs}`.

### Commit `9837d52a` — display_id ao postar
- Agent message delivery usa `platform_metadata.desk_conversation_id` antes de `chatwoot_conversation_id`.
- Acaba o bug de 404 no POST `/messages`.

### Commit `a7cc48d7` — desativação automática de bot
- `updateStatus` do agent_instance → `paused/error/archived` desvincula bot de TODAS as inboxes (`removeInboxAgentBot`).
- Active → re-atacha via `agent_frontdesk_bridge`.

### Commit `4ab690da` — timeout handoff detector
- `waitingSeconds` usa `newestQueuedTime` (msg atual), não a mais antiga.
- Elimina "Motivo: timeout" disparado por backlog stale.

### Impacto no Frontdesk
- Não precisa fazer nada do lado do Chatwoot pra esses fixes funcionarem.
- Recomendado: manter o `custom/config/initializers/agent_bot_webhook_guard.rb` (síncrono, bypassa Sidekiq) como segunda camada de defesa.

---

## Formato pra novas entradas

```
## YYYY-MM-DD — <título da mudança>
### Commit `<hash>` — <descrição curta>
- o que mudou
- impacto
### Impacto no Frontdesk
- ação necessária ou "nenhuma"
```
