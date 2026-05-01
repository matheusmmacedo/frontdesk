# Schema drift — billing engine (DEV vs PROD)

> **Owner:** agente KLaOS — aplicar migration em PROD.
> **Severidade:** **alta** — bloqueia deploy de qualquer feature que usa `permanent_labels` (segmentação por etiqueta) e impede sync de templates em prod.
> **Detectado:** 2026-04-29 pelo agente Frontdesk.
> **Ambientes:** DEV `szkzkyexagunvadzzaec` ↔ PROD `ddnwemmvsuiibgbzjpwx`.

## Resumo

| Item | DEV | PROD | Bloqueio |
|---|---|---|---|
| `collection_campaigns.permanent_labels` (text[]) | ✅ existe | ❌ falta | bloqueia segmentação por label |
| `waba_templates` populada | 16 rows, sync 2026-04-29 | **0 rows, nunca sincronizado** | régua não dispara em prod |
| `waba_numbers` com WABA Klaus | 1 row | (não verificado neste audit — confirmar) | sync depende disso |
| `collection_campaigns` rows | 2 (paused) | **0** | nenhuma régua existe em prod |

## (1) Coluna faltante — `collection_campaigns.permanent_labels`

```sql
-- Em PROD (ddnwemmvsuiibgbzjpwx)
ALTER TABLE public.collection_campaigns
  ADD COLUMN IF NOT EXISTS permanent_labels text[] NOT NULL DEFAULT '{}';

-- (opcional) índice GIN se for filtrar por label
CREATE INDEX IF NOT EXISTS idx_collection_campaigns_permanent_labels
  ON public.collection_campaigns USING gin (permanent_labels);
```

Por quê: o agente Frontdesk auditou o schema completo de ambos os ambientes. Tudo o resto bate (handoff_team_id, boletos_team_id, reply_mode, filter_*, demo_interval_seconds). Só falta `permanent_labels`.

## (2) Sync de `waba_templates` em PROD

PROD tem a tabela criada mas **vazia**. Provavelmente:
- O cron/edge function que faz sync está lendo `waba_numbers` em DEV apenas
- Ou o cron não está habilitado em PROD
- Ou `waba_numbers` em PROD não tem nenhum row pra sincronizar

**Diagnóstico necessário** (rodar em PROD):

```sql
SELECT
  (SELECT COUNT(*) FROM waba_numbers) AS waba_numbers_count,
  (SELECT COUNT(*) FROM waba_numbers WHERE status='verified') AS waba_numbers_verified,
  (SELECT MAX(updated_at) FROM waba_numbers) AS last_waba_update,
  (SELECT COUNT(*) FROM waba_templates) AS templates_count,
  (SELECT MAX(last_synced_at) FROM waba_templates) AS last_template_sync;
```

Esperado se sync estivesse rodando em prod: `waba_numbers_count >= 1` (Atend Med BH cliente), `waba_numbers_verified >= 1`, `templates_count > 0`, `last_template_sync` recente.

Se `waba_numbers_count = 0`: cliente Atend Med BH não foi provisionado em prod — onboarding pendente. Se `waba_numbers > 0` mas `templates = 0`: sync job não roda em prod (verificar pg_cron / edge function).

## (3) Régua não existe em PROD

`SELECT COUNT(*) FROM collection_campaigns` em PROD = 0.

Não é drift de schema — é decisão de produto. Atend Med BH **não tem régua provisionada em prod**. Quando o cliente for migrar, precisa:
1. Aplicar fix (1) acima.
2. Garantir (2) acima rodando.
3. Provisionar `waba_numbers` (Atend Med BH WABA Klaus + access_token).
4. Triggar sync inicial de `waba_templates`.
5. Criar `collection_campaign` apontando pros template uuids sincronizados.
6. Linkar à inbox correta via `frontdesk_inbox_id`.

Ordem importa — passos 4-5 dependem de 3, e 6 depende da inbox existir no Frontdesk prod (já existe — confirmar `Inbox.id` da Atend Med BH em prod).

## (4) Outras divergências verificadas e OK

Comparação completa de colunas em todas tabelas billing-relevant:

| Tabela | DEV cols | PROD cols | Diff |
|---|---|---|---|
| `collection_campaigns` | 39 | 38 | falta `permanent_labels` em prod |
| `collection_sequence_steps` | 17 | 17 | ✅ |
| `collection_enrollments` | 22 | 22 | ✅ |
| `collection_enrollment_events` | 13 | 13 | ✅ |
| `waba_templates` | 11 | 11 | ✅ schema |
| `waba_numbers` | 19 | 19 | ✅ |
| `waba_number_assignments` | 11 | 11 | ✅ |
| `waba_campaigns` | 13 | 13 | ✅ |
| `collection_campaign_templates` | 10 | 10 | ✅ |

Schema dos billing-relevant tá 99% alinhado — só `permanent_labels`.

## Plano de aplicação

1. Aplicar (1) — 1 ALTER TABLE, < 1s, idempotente.
2. Verificar (2) com query diagnóstica → escalar pra fix se sync não estiver rodando.
3. (3) é trabalho de provisionamento — fora do escopo deste cleanup, mas depende de (1) e (2).

Anotar em `docs/para-frontdesk-agent/KLAOS_UPDATES.md` quando aplicado.
