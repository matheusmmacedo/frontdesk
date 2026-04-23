# Pedidos do Frontdesk pro KLaOS

Arquivo pra eu (agente Frontdesk) registrar pedidos que o agente KLaOS tem que atender. O Matheus passa essas mensagens no chat com o outro agente OU o agente KLaOS lê isso aqui em fluxo automático futuro.

## Formato

```
## YYYY-MM-DD — <título>
**Contexto**: ...
**Pedido**: ...
**Prioridade**: Crítica/Alta/Média/Baixa
**Status**: Pendente / Em andamento / Resolvido (commit hash)
```

---

## Pedidos ativos

### 2026-04-23 — Invocação real da tool `transferir_para_time`
**Contexto**: conv 151 (Mais Saúde DEV) — Lara respondeu "vou te transferir" mas não invocou a tool. `agent_conversations.handoff_at=NULL`.  
**Pedido**: implementar `../para-klaos-agent/SDD_HANDOFF_TOOL_INVOCATION.md`.  
**Prioridade**: Crítica  
**Status**: Pendente

### 2026-04-23 — Roteamento de handoff por intent
**Contexto**: Tool recebe `team_name` mas não há map pra `team_id`. Risco de cair no team errado.  
**Pedido**: implementar `../para-klaos-agent/SDD_HANDOFF_ROUTING.md`. Popular `handoff_team_map` pra Mais Saúde.  
**Prioridade**: Crítica (dependência do fix acima)  
**Status**: Pendente

### 2026-04-23 — Política de reabertura por tempo
**Contexto**: hoje toda reabertura vai pro mesmo assignee, mesmo após dias. Cliente fica preso.  
**Pedido**: implementar `../para-klaos-agent/SDD_REOPEN_POLICY.md` após fechar DPs.  
**Prioridade**: Crítica  
**Status**: Aguarda decisões DP-1 a DP-5 do Matheus

### 2026-04-23 — Backfill `desk_conversation_id`
**Contexto**: coluna dedicada NULL em todas rows, dado só em `platform_metadata`.  
**Pedido**: implementar `../para-klaos-agent/SDD_DESK_CONVERSATION_ID_BACKFILL.md`.  
**Prioridade**: Alta  
**Status**: Pendente
