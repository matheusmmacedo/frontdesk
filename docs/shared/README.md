# Documentos compartilhados — KLaOS Ecosystem

Esta pasta tem documentos que servem de referência pros dois agentes (KLaOS e Frontdesk). Análises, planos de teste, matrizes de gaps.

## O que tem aqui

| Arquivo | Escopo | Quem mantém |
|---|---|---|
| `ANALISE_FLUXO_HANDOFF.md` | Mapa de 34 gaps identificados no fluxo bot ↔ humano + multi-tenancy | Frontdesk agent consolida, os dois leem |
| `PLANO_TESTES_FRONTDESK.md` | QA test plan pro Frontdesk (Chatwoot fork) — 28 features, ~280 TCs | Frontdesk agent |
| `PLANO_TESTES_KLAOS_CRM.md` | QA test plan pro módulo CRM do KLaOS — 15 features, ~50 TCs | Frontdesk agent escreveu; KLaOS agent pode adicionar correções |
| `PLANO_TESTES_AI_AGENTS.md` | QA test plan pro módulo AI Agents — 15 features, ~55 TCs | Idem |
| `PLANO_TESTES_INTEGRACAO.md` | QA test plan de jornadas e2e cruzando os 3 engines — 10 jornadas, ~70 TCs | Frontdesk agent |

## Regras de uso

- **Qualquer agente pode LER** esses docs pra contexto.
- **Mudanças escrevem** nesses docs SÓ se foram consolidações pós-investigação (ex: adicionar novo gap, atualizar status de gap fechado).
- **Não implemente nada baseado apenas nesses docs** — sempre prefira o SDD específico na pasta do seu agente.
