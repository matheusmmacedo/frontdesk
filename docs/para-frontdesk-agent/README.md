# Pasta exclusiva do agente Frontdesk

> ⚠️ **Se você é o agente do Frontdesk (rodando em `C:\dev\gmb\frontdesk`), leia APENAS os arquivos desta pasta.**
> Os arquivos em `../para-klaos-agent/` são do outro agente; não execute nem aplique aquelas instruções.
> Os arquivos em `../shared/` são referências compartilhadas (análises e planos de teste) — pode ler pra contexto, mas não tente implementar nada fora da sua pasta.

## O que tem aqui

Cada SDD nesta pasta cobre **uma mudança específica no Frontdesk** (repo `matheusmmacedo/frontdesk`, fork de Chatwoot). Sua responsabilidade é implementar essas mudanças.

## Princípios

1. **Todo código novo em `custom/`.** Nunca edite arquivos upstream do Chatwoot (sobrevive ao merge). Se for UI (Vue component), o diff tem que ser mínimo e bem documentado.
2. **Multi-tenant via `account_id`.** Nativo do Chatwoot; garanta que escopa.
3. **Feature flags por account** via `account.custom_attributes` ou `InstallationConfig`.
4. **Não mexa no KLaOS.** Se precisar de algo no KLaOS, escreve na `KLAOS_UPDATES.md` ou `REQUESTS.md`.

## Fluxo de trabalho

1. Lê o SDD
2. Implementa em `custom/` + branch `klaos-dev`, push e deploy dev automático
3. Marca "done" no topo do SDD
4. Escreve update em `REQUESTS.md` se precisar de algo do KLaOS

## Índice

- [SDD — Botão "Devolver ao bot" na UI da conversa](./SDD_TRANSFER_TO_BOT_BUTTON.md)
- [SDD — Endpoint custom de transferência pro bot](./SDD_TRANSFER_TO_BOT_API.md)
- [SDD — Timestamp de resolução em `additional_attributes` pra política de reabertura](./SDD_RESOLVED_TIMESTAMP.md)
- [SDD — Incluir `channel_type` em `Inbox#webhook_data` (1-liner crítico)](./SDD_INBOX_WEBHOOK_DATA_CHANNEL_TYPE.md) — multi-tenant fix pra resolver 115 convs prod com chatwoot_channel=null
- [SDD CROSS-REF — UI Modularidade KLaOS](./SDD_UI_MODULARIDADE_CROSSREF.md) — auditoria UI+backend+modelos; 3 pontos de coordenação Frontdesk (teams API enrichment, inbox placeholder, Klingo card)

## Comunicação cruzada

- `KLAOS_UPDATES.md` — updates recebidos do agente KLaOS (quando ele fizer fix, consolida aqui)
- `REQUESTS.md` — pedidos do Frontdesk pro KLaOS (quando você precisa de algo no lado deles)

## Referências compartilhadas

- `../shared/ANALISE_FLUXO_HANDOFF.md` — mapa completo de gaps
- `../shared/PLANO_TESTES_FRONTDESK.md` — plano de QA principal
- `../shared/PLANO_TESTES_INTEGRACAO.md` — testes e2e
