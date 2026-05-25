# [PARA O AGENTE DO FRONTDESK] Feedback do Gustavo (Mais Saúde) — itens da plataforma

**Origem:** agente KLaOS · 25/05/2026 · conta Chatwoot **9 (Mais Saúde)** · branch `klaos-dev`
**Contexto:** o Gustavo (operação Mais Saúde) listou 17 pontos. Abaixo só os **da plataforma Frontdesk/Chatwoot** (os de IA/cobrança ficam com o KLaOS). Para cada: o que ele relatou, análise, o que investigar e como testar/validar.

> ⚠️ Item de **mídia (áudio)** já teve um fix hoje (host da URL `app-desk` vs worker — ver `INVESTIGAR_MEDIA_URL_HOST.md`). Aqui detalho o que ainda falta (tempo-real + ✓✓ de entrega).

---

## 1) Ordem dos templates desconfigurou
**Relato:** "Desconfigurou e não está mais na ordem dos mais usados. Colocar de novo na ordem — o mais usado inicialmente é o de **protesto**."
**Análise:** ordenação dos templates/respostas rápidas no Chatwoot mudou. Faz sentido — é configuração de UI/ordenação.
**Investigar:** como a ordem de templates é definida (canned responses / templates WABA) na conta 9; se há campo de ordenação ou se está alfabético/por-criação.
**Resolver:** restaurar a ordem com **protesto em 1º** (alinhar a ordem com a frequência de uso da operação).
**Testar:** abrir o seletor de templates numa conversa → "protesto" aparece no topo.

## 2) Notificação enviada pelo usuário não abre/atribui a conversa pra ele
**Relato:** "Enviei a notificação com o meu usuário e a conversa não veio pra mim. Deveria abrir/ficar em 'minhas'. Tive que pesquisar pelo nome e clicar em reabrir." (EX: **PAULO ROBERTO DE ARRUDA PINTO**)
**Análise:** quando um atendente dispara um template/notificação ativa, a conversa deveria ficar **atribuída a ele** (em "minhas"/"mine"). Hoje não atribui. Faz sentido.
**Investigar:** o fluxo de envio de template ativo no Chatwoot — atribuição automática (assignee) ao agente que dispara; por que a conversa fica sem dono / precisa reabrir manual.
**Resolver:** ao enviar notificação ativa, **auto-atribuir** a conversa ao agente remetente.
**Testar:** disparar um template pra um contato → a conversa aparece em "Minhas" do remetente, sem precisar pesquisar/reabrir.

## 6) Negrito exige asterisco repetido (vira itálico primeiro)
**Relato:** "Pra negrito tem que voltar o asterisco várias vezes — primeiro fica itálico. Não usamos itálico, só negrito. Deixar 1 asterisco no começo e fim = negrito."
**Análise:** no WhatsApp `*texto*` = **negrito**. O composer/preview do Chatwoot está tratando `*` como itálico (markdown padrão). A operação quer comportamento **estilo WhatsApp** (1 asterisco = negrito).
**Investigar:** o editor de mensagem do agente no Chatwoot (markdown → WhatsApp). Hoje `*` vira itálico; precisa mapear `*texto*` → negrito no envio pro WhatsApp.
**Resolver:** ajustar o render/markdown do composer pra `*` = negrito (estilo WhatsApp), não itálico.
**Testar:** digitar `*urgente*` → cliente recebe **urgente** em negrito (não itálico).

## 7) Reabertura não funciona (sem bolinha verde, sem som)
**Relato:** "A reabertura não está funcionando, a mensagem não abre. Deveria reabrir com a bolinha verde (não-lida) e **alertar com o sinal sonoro** configurado pra cada agente."
**Análise:** ligado ao item 2. Quando chega mensagem numa conversa resolvida, deveria **reabrir + marcar não-lida + tocar som**. Hoje não reabre/avisa.
**Investigar:** lógica de reopen-on-new-message no Chatwoot da conta 9; o estado "não-lida" (bolinha verde); e o **alerta sonoro** por agente (config de notificação).
**Resolver:** mensagem nova em conversa resolvida → reabre + não-lida + som.
**Testar:** resolver uma conversa → cliente manda mensagem → ela reabre sozinha, fica verde/não-lida e toca o som.

## 8) Caminho do admin pra acompanhar/puxar conversas em tempo real
**Relato:** "Como admin, qual o caminho pra acompanhar conversas em tempo real e interagir? E as colaboradoras puxarem conversa de outra (ex.: uma passou mal e saiu)? No sistema atual (que o Mateus tem o login) é fácil ver todas, interagir e transferir."
**Análise:** é supervisão/handoff entre agentes no Chatwoot — ver todas as conversas, assumir, transferir. Parte é **how-to** (já existe no Chatwoot: visão de admin, reassign), parte pode ser **gap de UX**.
**Investigar:** o que o perfil admin da conta 9 já permite (ver todas, reassign, intervir); documentar o caminho; e se falta algo, implementar.
**Resolver/Responder:** mandar pro Gustavo o **passo-a-passo** (admin → ver todas → assumir/transferir) e cobrir o gap se houver.
**Testar:** admin abre conversa de uma colaboradora, assume e responde; reatribui pra outra agente.

## 9) Desconecta constantemente (quer 100% online como o QUALIZ)
**Relato:** "Fica desconectado e não recebo mensagem. Queria igual ao QUALIZ que uso hoje — 100% online o tempo todo."
**Análise:** sessão do agente cai (websocket/online presence). Impacto direto: perde mensagem em tempo real. Faz muito sentido — é estabilidade de conexão.
**Investigar:** por que a sessão do agente desconecta (timeout de websocket, presence, reconexão); comparar com o comportamento esperado (sempre-online).
**Resolver:** reconexão automática / manter presença online estável.
**Testar:** agente fica logado horas sem interagir → continua "online" e recebe mensagem em tempo real (sem refresh).

## 10) "Não atribuídas" → renomear para "Inteligência Artificial"
**Relato:** "Pra facilitar a gestão, no lugar de 'não atribuídas' escrever **'inteligência artificial'**."
**Análise:** as conversas que a IA (bot) atende ficam no bucket "não atribuídas". O Gustavo quer rotular esse grupo como "Inteligência Artificial" (deixa claro que é a IA cuidando, não abandono). Faz sentido — é label/UX.
**Investigar:** como renomear/rotular o bucket de conversas atendidas pelo bot (custom view / label "Inteligência Artificial").
**Resolver:** exibir as conversas do bot como "Inteligência Artificial" em vez de "não atribuídas".
**Testar:** conversa atendida pelo bot aparece sob "Inteligência Artificial".

## 11) Busca de contato exige acento/cedilha
**Relato:** "Sem o acento na letra Á não encontra. Desabilitar a obrigatoriedade de acento/cedilha — com ou sem acento tem que achar." (EX: **CÁSSIA OLIVEIRA FELIPE NOVATO**)
**Análise:** a busca de contatos do Chatwoot é accent-sensitive. Quer accent-insensitive. Faz total sentido (operação digita sem acento).
**Investigar:** a busca de contatos da conta 9 — normalizar acentos/cedilha (unaccent) na query.
**Resolver:** busca ignora acento/cedilha (CASSIA = CÁSSIA).
**Testar:** buscar "cassia" (sem acento) → encontra "CÁSSIA".
> Nota KLaOS: a busca de **devedor por CPF** no KLaOS já é normalizada; a busca de **contato/nome** no Chatwoot é separada (este item).

## 12) Mídia — ERROS GRAVES (4 sub-itens)
**Relato:** (12.1) imagens só aparecem **após atualizar a página** (não tempo real); (12.2) **não conseguem ouvir os áudios** recebidos; (12.3) ao enviar print/imagem dá **erro** e **não tem ✓/✓✓** (sem saber se o cliente recebeu); (12.4) ao enviar áudio idem — erro + sem ✓✓; "em alguns recebem, em outros não".
**Análise + status:**
- **12.2 (ouvir áudio): JÁ ENDEREÇADO hoje** pelo fix do host de mídia (worker→`app-desk`, ver `INVESTIGAR_MEDIA_URL_HOST.md`). **Confirmar** que a operação consegue tocar áudios novos (URL `app-desk`, 200 + Range). Se ainda houver caso, é o mesmo pipeline.
- **12.1 (imagem só após refresh): tempo-real** — mensagens novas (entrada) não aparecem sem refresh → **websocket/realtime** do Chatwoot (liga ao item 9). Investigar o push em tempo real de mensagens recebidas.
- **12.3 / 12.4 (sem ✓/✓✓ de entrega + erro ao enviar):** falta o **status de entrega (delivery receipts)** das mensagens **enviadas** pelo agente (sent/delivered/read) + o erro no envio de mídia. Investigar: (a) o envio de imagem/áudio do agente pro WhatsApp (por que dá erro/intermitente), (b) exibir os ✓/✓✓ (delivery status) na conversa.
**Resolver:** mídia recebida em tempo real (sem refresh) + envio de mídia do agente confiável + ✓/✓✓ de entrega visíveis.
**Testar:** cliente manda imagem/áudio → aparece **na hora** (sem refresh) e toca; agente manda imagem/áudio → envia sem erro e mostra ✓✓ quando entregue.

---

## Resumo pro agente do Frontdesk
| # | Tema | Tipo |
|---|---|---|
| 1 | Ordem dos templates (protesto 1º) | UI/config |
| 2 | Auto-atribuir conversa ao remetente da notificação | Atribuição |
| 6 | `*` = negrito (estilo WhatsApp), não itálico | Composer |
| 7 | Reopen + não-lida + som ao chegar msg | Realtime/notif |
| 8 | Caminho admin: ver/assumir/transferir todas | Supervisão (how-to + gap) |
| 9 | Sessão sempre online (não desconectar) | Conexão/presence |
| 10 | "Não atribuídas" → "Inteligência Artificial" | UI/label |
| 11 | Busca de contato sem exigir acento | Busca |
| 12 | Mídia: tempo-real + ✓✓ entrega (áudio download já fixado) | Realtime + delivery |

**Quando resolver cada um, responda em `docs/para-klaos-agent/` (ou aqui)** com: o que foi corrigido + como testar — pro KLaOS consolidar a resposta ao Gustavo.
