# Novo evento bridge: `waba_template_changed`

> **Owner**: agente KLaOS — implementar handler no `bridge-event` endpoint.
> **Detectado**: 2026-04-30. Frontdesk agora intercepta webhooks `message_template_*` da Meta e propaga pro KLaOS via bridge.

## Por quê

Hoje `waba_templates` em DEV sincroniza 1×/dia (04:00 UTC). Quando Meta:
- Aprova um template novo
- Reclassifica UTILITY → MARKETING (caso `ms24h_boleto_vencido` que aconteceu)
- Pausa por quality
- Rejeita

…demora até 24h pra `waba_templates` saber. Em régua de cobrança ativa, isso é gap inaceitável — pode disparar mensagem MARKETING sem opt-in e bloquear a WABA.

**Solução**: Frontdesk recebe o webhook real-time da Meta (subscrição já existente do Channel::Whatsapp), faz re-sync do cache local, **e dispara webhook pro KLaOS** com o evento.

## Implementação no Frontdesk (já feita)

- `custom/app/jobs/whatsapp_template_events_handler.rb` — módulo (concern) prepended ao `Webhooks::WhatsappEventsJob`. Vive direto em `custom/app/jobs/` (não em `concerns/`) pra autoload Zeitwerk resolver sem `collapse` extra.
- `custom/config/initializers/whatsapp_template_events_extension.rb` — wire up via `Rails.application.config.to_prepare` com guards `defined?` + `method_defined?` pra falhar gracioso se upstream renomear a class/método (warning em vez de boot crash).
- Tudo modular: nenhum arquivo upstream do Chatwoot foi modificado. Sobrevive a `git merge upstream/master` sem conflito.
- Quando recebe template event, chama `KlaosBridgeWebhookJob` apontando pro `KLAOS_BRIDGE_URL/api/webhooks/klaos/bridge-event`.

## Contrato do payload

```http
POST {KLAOS_BRIDGE_URL}/api/webhooks/klaos/bridge-event
Content-Type: application/json
X-Bridge-Secret: <FRONTDESK_BRIDGE_SECRET>

{
  "type": "waba_template_changed",
  "waba_id": "735467396201142",
  "field": "message_template_status_update" | "message_template_category_update" | "message_template_quality_update",
  "template_id": "1511276237252287",
  "template_name": "ms24h_boleto_vencido_v2",
  "template_language": "pt_BR",
  "event": "APPROVED" | "REJECTED" | "PENDING_DELETION" | "FLAGGED" | "PAUSED" | "DISABLED" | "CATEGORY_UPDATE" | ...,
  "previous_category": "MARKETING",   // só presente em CATEGORY_UPDATE
  "new_category": "UTILITY",
  "reason": "..."                      // texto livre da Meta quando rejeita
}
```

Resposta esperada: `200 { "ok": true }` em <2s. Idempotência via `(waba_id, template_id, event)`.

## Ação esperada no KLaOS

1. **Re-sync `waba_templates`** pro `waba_id` afetado (mesma rotina da sync diária, agora trigada manualmente)
2. **Update da row específica** se já existir (idempotente)
3. **Trigger DB de validação** (G-Sync.3 do SDD) recalcula `collection_sequence_steps.broken_reason` automaticamente quando `waba_templates.status/category` mudar
4. **Sentry alert** se `event = 'REJECTED'` ou se categoria virou MARKETING (Frontdesk já alerta do lado dele, mas KLaOS deve duplicar pq régua é dele)
5. **Auto-pause enrollments** que usam o template afetado quando `event` for crítico:
   ```sql
   -- Pseudocode
   UPDATE collection_enrollments
   SET status = 'paused_template_broken'
   WHERE id IN (
     SELECT ce.id FROM collection_enrollments ce
     JOIN collection_sequence_steps css ON css.campaign_id = ce.campaign_id
     JOIN waba_templates wt ON wt.id = css.waba_template_id
     WHERE wt.meta_template_id = $template_id
       AND wt.status != 'APPROVED'
   );
   ```

## Como testar

Em DEV, ativar handler depois deste deploy. Disparar manualmente alterando texto de `fatura_emissao` (ex via UI Templates Settings → Edit). Meta envia webhook `message_template_status_update` (status volta pra PENDING). Frontdesk re-sync local + POST pro KLaOS bridge. KLaOS deve receber payload + atualizar row.

**Não esquecer setar env vars no Frontdesk:**
- `KLAOS_BRIDGE_URL=https://api-dev.klaos.ai`
- `FRONTDESK_BRIDGE_SECRET=<shared>`

(Hoje já existe pra outros eventos do bridge — confirmar valores.)

## Validação fim a fim

```sql
-- KLaOS DEV — verificar last_synced_at recente após webhook
SELECT name, status, category, last_synced_at
FROM waba_templates
WHERE meta_template_id = '<id>'
ORDER BY last_synced_at DESC LIMIT 1;
```

`last_synced_at` deve estar dentro de ~30s do timestamp do webhook recebido.
