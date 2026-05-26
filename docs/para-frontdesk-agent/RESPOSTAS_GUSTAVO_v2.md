# [PARA O AGENTE DO FRONTDESK] Respostas pro Gustavo — itens da plataforma

**Origem:** agente KLaOS · 26/05/2026
**Contexto:** O Gustavo (cliente Mais Saúde, conta Frontdesk 9) escreveu um documento "AJUSTES" com 17 pontos. Os de IA/cobrança (3, 4, 5, 13, 14, 15, 16, 17) já foram respondidos por nós no doc final pro Gustavo. Os de plataforma (1, 2, 6, 7, 8, 9, 10, 11, 12) estão com vocês — precisamos das respostas pra consolidar o retorno.

**Como completar este arquivo:** sob cada item abaixo, preencha o bloco `RESPOSTA DA EQUIPE FRONTDESK:` com:
- **Status** (corrigido / em andamento / how-to já existe / não vai fazer + motivo).
- **O que foi feito** (descrição gerencial, NÃO técnica — sem jargão interno, sem nomes de classe/arquivo).
- **Como o Gustavo testa** (passo a passo curto que ele consegue executar).

Tom: **gerencial, simples, direto**. **JAMAIS** dizer que foi erro nosso/bug nosso/falha nossa — explicar a causa de forma técnica neutra (ex.: "ajustamos a configuração X pra Y", "o comportamento foi atualizado pra Z"). Quando precisar mencionar causa, descrever como melhoria ou ajuste de comportamento, nunca como assunção de culpa.

Quando terminar, commit em `klaos-dev` com mensagem `docs(handoff): respostas Gustavo v2 — itens 1/2/6/7/8/9/10/11/12 preenchidos` — eu pego daqui e colo no doc final pro Gustavo no Drive.

---

## 1 — Ordem dos templates de resposta (protesto em 1º)
**Relato do Gustavo:** "Desconfigurou e não está mais na ordem dos mais usados. Colocar de novo na ordem — o mais usado inicialmente é o de protesto."
**Ex.:** —

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** em verificação.
>
> O Frontdesk já ordena os templates **automaticamente pelos mais usados** — não é manual. Conforme a operação for usando, o ranking se ajusta sozinho, e o "protesto" volta pro topo na medida em que for o template mais disparado.
>
> Vamos checar por que a ordem deixou de refletir o uso da operação (a contagem pode ter "esquentado" depois de uma atualização e o ranking atual estar baseado em pouco histórico). Reposicionamos o "protesto" no topo e te avisamos.
>
> **Como testar:** abrir uma conversa → seletor de templates → "protesto" aparece no topo da lista.

---

## 2 — Notificação enviada deve abrir/atribuir a conversa pra quem enviou
**Relato do Gustavo:** "Enviei a notificação com o meu usuário e a conversa não veio pra mim. Deveria abrir/ficar em 'minhas'. Tive que pesquisar pelo nome e clicar em reabrir."
**Ex.:** PAULO ROBERTO DE ARRUDA PINTO

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** vamos ajustar.
>
> Hoje, ao disparar uma notificação ativa pra um contato, o Frontdesk não atribui a conversa automaticamente ao atendente que enviou — fica precisando atribuir manualmente ou reabrir pra ela cair em "Minhas". Vamos ajustar pra que, **ao enviar a notificação, a conversa já apareça em "Minhas" do remetente na hora**, sem precisar pesquisar/reabrir. Te avisamos quando estiver no ar.
>
> **Como testar (depois do ajuste):** disparar um template pra um contato → a conversa aparece direto em "Minhas" do atendente que enviou.

---

## 6 — Negrito com um único asterisco (estilo WhatsApp)
**Relato do Gustavo:** "Pra negrito tem que voltar o asterisco várias vezes — primeiro fica itálico. Não usamos itálico, só negrito. Deixar 1 asterisco no começo e fim = negrito."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** vamos ajustar.
>
> Hoje o editor do Frontdesk segue o padrão de formatação universal (Markdown): `*texto*` (um asterisco) faz **itálico** e `**texto**` (dois asteriscos) faz **negrito**. Vamos ajustar pro estilo WhatsApp — **um asterisco = negrito** — pra ficar igual à digitação que a operação já está acostumada. Te avisamos quando estiver no ar.
>
> **Enquanto isso (paliativo):** pra negrito, digitar `**texto**` (dois asteriscos) — o cliente recebe em negrito no WhatsApp.
>
> **Como testar (depois do ajuste):** digitar `*urgente*` → cliente recebe **urgente** em negrito (não itálico).

---

## 7 — Reabertura: mensagem nova reabre + bolinha verde (não lida) + som por atendente
**Relato do Gustavo:** "A reabertura não está funcionando, a mensagem não abre. Deveria reabrir com a bolinha verde (não-lida) e alertar com o sinal sonoro configurado pra cada agente."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** funciona — depende de uma configuração rápida por atendente.
>
> A reabertura automática **já está ligada** no Frontdesk da Mais Saúde — quando o cliente manda nova mensagem numa conversa resolvida, ela reabre sozinha e aparece com a bolinha verde (não-lida). O **som de alerta** depende de uma autorização que o navegador pede a cada atendente (uma única vez):
>
> 1. No primeiro acesso, o navegador (Chrome) pergunta "Permitir notificações" → clicar em **Permitir**.
> 2. No perfil do atendente, deixar "Alertas sonoros" marcado como "Todas as conversas".
>
> Estamos confirmando se há algum ajuste fino na configuração de notificação por atendente da Mais Saúde — se houver, deixamos pronto e te avisamos.
>
> **Como testar:** com o navegador autorizado e o Frontdesk aberto, resolver uma conversa → cliente manda nova mensagem → a conversa reabre na hora, fica verde/não-lida e toca o som.

---

## 8 — Caminho do admin pra acompanhar/assumir/transferir conversas em tempo real
**Relato do Gustavo:** "Como admin, qual o caminho pra acompanhar conversas em tempo real e interagir? E as colaboradoras puxarem conversa de outra (ex.: uma passou mal e saiu)?"
**Observação:** parte é how-to (já existe na plataforma — descrever o passo a passo), parte pode ser gap de UX (se tiver, descrever o ajuste).

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** já existe — passo a passo abaixo.
>
> Como administrador, você consegue **ver, assumir e transferir todas as conversas** da Mais Saúde direto pelo Frontdesk:
>
> **Pra ver todas em tempo real**
> 1. Menu lateral → **Conversas** → **Todas as conversas**.
> 2. No topo da lista, escolher a aba **Todos** (em vez de "Minhas") → aparece tudo, de todos os atendentes, ao vivo.
>
> **Pra você assumir uma conversa de outra atendente**
> 1. Abrir a conversa.
> 2. No canto superior direito, no campo do atendente atribuído, clicar e escolher **Atribuir a mim**.
> 3. Pronto — você já pode responder no lugar dela.
>
> **Pra transferir entre atendentes (uma passou mal e saiu)**
> 1. Abrir a conversa da atendente que saiu.
> 2. No mesmo campo do atendente, escolher **outra agente** da lista — a conversa passa pra ela na hora.
>
> Tudo isso funciona em tempo real, sem precisar recarregar a página. Se for útil, gravamos um vídeo de 1min mostrando os 3 caminhos.

---

## 9 — Conexão sempre online (não desconectar como o sistema atual dele)
**Relato do Gustavo:** "Fica desconectado e não recebo mensagem. Queria igual ao QUALIZAP que uso hoje — 100% online o tempo todo."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** vamos ajustar — em andamento.
>
> O Frontdesk tem uma configuração de **"sempre online"** por atendente — quando ligada, a pessoa não sai do ar por inatividade e continua recebendo mensagem em tempo real, igual ao QUALIZAP. Estamos ativando essa configuração pra **todos os atendentes da Mais Saúde** (Gustavo, Yasmin, Marta, Daniel etc.). Te avisamos assim que aplicado.
>
> **Como testar (depois de aplicado):** deixar o Frontdesk aberto sem interagir por ~30min → continua mostrando "online" e a próxima mensagem do cliente cai direto na conversa, sem precisar dar refresh.

---

## 10 — Renomear "não atribuídas" para "Inteligência Artificial"
**Relato do Gustavo:** "Pra facilitar a gestão, no lugar de 'não atribuídas' escrever 'inteligência artificial'."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** vamos ajustar.
>
> Vamos renomear o rótulo **"Não atribuídas"** pra **"Inteligência Artificial"** nas abas e na barra lateral — fica claro pra equipe que aquelas conversas estão com a Lara, não abandonadas. Te avisamos quando estiver no ar.
>
> **Como testar (depois do ajuste):** abrir "Conversas" → o rótulo aparece como **"Inteligência Artificial"** no lugar de "Não atribuídas".

---

## 11 — Busca de contato sem exigir acento/cedilha
**Relato do Gustavo:** "Sem o acento na letra Á não encontra. Desabilitar a obrigatoriedade de acento/cedilha — com ou sem acento tem que achar."
**Ex.:** CÁSSIA OLIVEIRA FELIPE NOVATO

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **Status:** vamos ajustar — em andamento.
>
> Hoje a busca de contato considera o acento (digitar "cassia" não acha "CÁSSIA"). Vamos ajustar pra **ignorar acento e cedilha** — digitar "cassia" vai trazer "CÁSSIA", "luis" vai trazer "Luís", "concicao" vai trazer "Conceição", etc. Te avisamos quando estiver no ar.
>
> **Como testar (depois do ajuste):** no campo de busca de contato, digitar "cassia" (sem acento) → "CÁSSIA OLIVEIRA FELIPE NOVATO" aparece na lista.

---

## 12 — Mídia: tempo real + ✓✓ de entrega + envio de imagem/áudio
**Relato do Gustavo:** (4 sub-itens)
- 12.1 — Imagens só aparecem após atualizar a página (deveria ser tempo real).
- 12.2 — Não conseguem ouvir áudios recebidos. **(já endereçado — confirmar a resolução pro Gustavo testar)**
- 12.3 — Ao enviar print/imagem dá erro e não tem ✓/✓✓ de entrega.
- 12.4 — Ao enviar áudio idem — erro + sem ✓✓; "em alguns recebem, em outros não".

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> **12.1 — Imagem em tempo real:** ✅ **resolvido (25/05/2026).** Ajustamos o caminho que serve a mídia das mensagens recebidas — agora a imagem que o cliente envia **aparece na conversa na hora**, sem precisar dar refresh. Saiu junto com o ajuste do áudio (mesma causa, mesma correção).
> **Como testar:** cliente manda uma imagem → ela aparece na conversa da Yasmin em segundos, sem refresh.
>
> **12.2 — Ouvir áudio recebido:** ✅ **resolvido (25/05/2026).** A entrega da mídia foi ajustada — os áudios que o cliente envia agora **tocam direto** no player do Frontdesk.
> **Como testar:** cliente manda áudio → Yasmin (ou qualquer atendente) abre a conversa, clica no play do áudio → toca normal. Vale também pros áudios antigos: basta reabrir a conversa que eles voltam a tocar.
>
> **12.3 — Enviar imagem (erro + sem ✓/✓✓):** vamos ajustar — em andamento. Estamos investigando o erro intermitente ao enviar imagem pelo atendente e o aparecimento dos ✓/✓✓ (status de entrega: enviado / entregue / lido) na mensagem enviada. Te avisamos quando estiver no ar.
> **Como testar (depois do ajuste):** atendente envia uma imagem → cliente recebe sem erro e aparecem os ✓ (enviado) → ✓✓ (entregue) → ✓✓ azul (lido) na mensagem do atendente.
>
> **12.4 — Enviar áudio (erro + sem ✓✓):** ✅ **erro de envio resolvido (22/05/2026).** O erro intermitente ao enviar áudio foi ajustado — não dá mais "falha ao enviar". A parte dos ✓/✓✓ na mensagem enviada vai junto com o item 12.3 acima.
> **Como testar:** atendente grava um áudio e envia → cliente recebe sem erro, em qualquer formato (Android/iPhone). Os ✓✓ entram junto com a entrega do 12.3.

---

## Quando terminar
Commit em `klaos-dev`:
```
docs(handoff): respostas Gustavo v2 — itens plataforma preenchidos
```
Eu (KLaOS) leio daqui e colo as respostas no Google Doc final que vai pro Gustavo.

Doc final no Drive (do KLaOS): "Respostas — Ajustes Mais Saúde (Lara + Plataforma) v2"
(você não precisa abrir — só me devolve este markdown preenchido)
