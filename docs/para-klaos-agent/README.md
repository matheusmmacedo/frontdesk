# Pasta exclusiva do agente KLaOS

> ⚠️ **Se você é o agente do KLaOS (rodando em `C:\dev\gmb\klaos`), leia APENAS os arquivos desta pasta.**
> Os arquivos em `../para-frontdesk-agent/` são do outro agente; não execute nem aplique aquelas instruções.
> Os arquivos em `../shared/` são referências compartilhadas (análises e planos de teste) — pode ler pra contexto, mas não tente implementar nada fora da sua pasta.

## O que tem aqui

Cada SDD nesta pasta cobre **uma mudança específica no KLaOS** (repo `matheusmmacedo/klaos`, Supabase KLaOS DEV `szkzkyexagunvadzzaec`, prod `ddnwemmvsuiibgbzjpwx`). Sua responsabilidade é implementar essas mudanças.

## Princípios

1. **Reaproveite o que já existe.** Não proponha tabelas novas se já há coluna/tabela que serve. Antes de sugerir schema, cheque se `agent_handoff_config`, `agent_conversations`, `workspaces.features` já têm o campo.
2. **Multi-tenant sempre.** Toda leitura/escrita escopada por `workspace_id` e `agent_instance_id`. Nunca valores globais hardcoded — use config das tabelas.
3. **Mudanças são opt-in por workspace.** Use `workspace_feature_flags` pra controlar rollout.
4. **Não mexa no Frontdesk (Chatwoot).** Se precisar de algo no lado Chatwoot, abra ticket/escreve mensagem pro outro agente no `../para-frontdesk-agent/REQUESTS.md`.

## Fluxo de trabalho

1. Lê o SDD do arquivo
2. Confirma com o Matheus (dono do produto) se tem decisão pendente
3. Implementa no branch `dev` do KLaOS, deploy dev
4. Marca como "done" atualizando o estado no topo do SDD
5. Escreve resumo do que foi feito pro agente Frontdesk saber em `../para-frontdesk-agent/KLAOS_UPDATES.md`

## Índice

- [SDD — Invocação real da tool `transferir_para_time`](./SDD_HANDOFF_TOOL_INVOCATION.md)
- [SDD — Política de reabertura (reopen) por tempo + fallback](./SDD_REOPEN_POLICY.md)
- [SDD — Backfill de `desk_conversation_id` nas `agent_conversations`](./SDD_DESK_CONVERSATION_ID_BACKFILL.md)
- [SDD — Roteamento de handoff por intent (team_id por intent)](./SDD_HANDOFF_ROUTING.md)

## Referências compartilhadas (leitura opcional)

- `../shared/ANALISE_FLUXO_HANDOFF.md` — mapa completo de gaps (lado KLaOS + lado Frontdesk misturados)
- `../shared/PLANO_TESTES_AI_AGENTS.md` — plano de QA do módulo Agents
- `../shared/PLANO_TESTES_INTEGRACAO.md` — testes e2e entre engines
