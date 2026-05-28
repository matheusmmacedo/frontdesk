# [PARA O AGENTE DO FRONTDESK] Respostas pro Gustavo — itens da plataforma

**Origem:** agente KLaOS · 26/05/2026
**Contexto:** O Gustavo (cliente Mais Saúde, conta Frontdesk 9) escreveu um documento "AJUSTES" com 17 pontos. Os de IA/cobrança (3, 4, 5, 13, 14, 15, 16, 17) já foram respondidos por nós no doc final pro Gustavo. Os de plataforma (1, 2, 6, 7, 8, 9, 10, 11, 12) estão com vocês — precisamos das respostas pra consolidar o retorno.

**Como completar este arquivo:** sob cada item abaixo, preencha o bloco `RESPOSTA DO MATHEUS:` com:
- **Status** (corrigido / em andamento / how-to já existe / não vai fazer + motivo).
- **O que foi feito** (descrição gerencial, NÃO técnica — sem jargão interno, sem nomes de classe/arquivo).
- **Como o Gustavo testa** (passo a passo curto que ele consegue executar).

Tom: **gerencial, simples, direto**. **JAMAIS** dizer que foi erro nosso/bug nosso/falha nossa — explicar a causa de forma técnica neutra (ex.: "ajustamos a configuração X pra Y", "o comportamento foi atualizado pra Z"). Quando precisar mencionar causa, descrever como melhoria ou ajuste de comportamento, nunca como assunção de culpa. A plataforma se chama **Frontdesk** em toda comunicação.

Quando terminar, commit em `klaos-dev` com mensagem `docs(handoff): respostas Gustavo v2 — itens 1/2/6/7/8/9/10/11/12 preenchidos` — eu pego daqui e colo no doc final pro Gustavo no Drive.

---

## 1 — Ordem dos templates de resposta (protesto em 1º)
**Relato do Gustavo:** "Desconfigurou e não está mais na ordem dos mais usados. Colocar de novo na ordem — o mais usado inicialmente é o de protesto."

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
>
> A ordenação dos templates pelos mais usados existe no Frontdesk (ordenação automática, sem precisar configurar manualmente). Vamos verificar por que essa ordem deixou de refletir o uso da operação e reposicionar o "protesto" no topo. Te respondo com prazo até quarta.
>
> **Como testar (após o ajuste):** dentro de uma conversa, no campo de mensagem, abrir o seletor de templates → o template de **protesto** aparece no topo da lista.

---

## 2 — Notificação enviada deve abrir/atribuir a conversa pra quem enviou
**Relato do Gustavo:** "Enviei a notificação com o meu usuário e a conversa não veio pra mim. Deveria abrir/ficar em 'minhas'. Tive que pesquisar pelo nome e clicar em reabrir."
**Ex.:** PAULO ROBERTO DE ARRUDA PINTO

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
>
> Hoje o Frontdesk não atribui automaticamente a conversa ao atendente que disparou a notificação. Vamos ajustar pra que, **ao enviar a notificação, a conversa caia direto em "Minhas" do remetente**, sem precisar pesquisar ou reabrir. Te respondo com prazo até quarta.
>
> **Como testar (após o ajuste):** disparar um template pra um contato → abrir a aba **"Minhas"** no topo da lista de conversas → a conversa do contato está lá.

---

## 6 — Negrito com um único asterisco (estilo WhatsApp)
**Relato do Gustavo:** "Pra negrito tem que voltar o asterisco várias vezes — primeiro fica itálico. Não usamos itálico, só negrito. Deixar 1 asterisco no começo e fim = negrito."

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
>
> Hoje o editor do Frontdesk usa o padrão universal de formatação (Markdown): `*texto*` (um asterisco) faz **itálico** e `**texto**` (dois asteriscos) faz **negrito**. Vamos ajustar pro estilo WhatsApp — **um asterisco = negrito** — pra ficar igual à digitação que a operação já está acostumada. Te respondo com prazo até quarta.
>
> **Enquanto isso (paliativo imediato):** pra negrito, usar `**texto**` (dois asteriscos no começo e dois no fim). O cliente recebe em negrito no WhatsApp normalmente.
>
> **Como testar (após o ajuste):** digitar `*urgente*` (um asterisco) no editor → cliente recebe **urgente** em negrito (não itálico).

---

## 7 — Reabertura: mensagem nova reabre + bolinha verde (não lida) + som por atendente
**Relato do Gustavo:** "A reabertura não está funcionando, a mensagem não abre. Deveria reabrir com a bolinha verde (não-lida) e alertar com o sinal sonoro configurado pra cada agente."

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** parte funciona com configuração rápida (passo a passo abaixo), parte entra na rotina — **prazo informado até quarta (27/05)** pra parte da reabertura.
>
> **A — Reabertura automática (msg nova reabre a conversa):** vamos verificar o comportamento na conta da Mais Saúde — entra na rotina, prazo até quarta. O Frontdesk **já tem** essa lógica nativa, mas a Mais Saúde tem uma particularidade que precisamos checar (lock de uma conversa por contato) — confirmamos o comportamento e ajustamos.
>
> **B — Bolinha verde (não-lida):** já funciona automaticamente. Quando chega mensagem nova, a conversa aparece na lista com a marcação de "não-lida".
>
> **C — Alerta sonoro por atendente:** **funciona — depende de uma configuração rápida por atendente (uma vez só):**
>
> **Passo a passo pra cada atendente (Yasmin, Marta, Gustavo, Daniel...):**
> 1. Na primeira vez que abrir o Frontdesk, o navegador (Chrome) vai perguntar **"Permitir notificações"** — clicar em **Permitir**.
> 2. Clicar no **avatar** no canto **inferior esquerdo** da barra lateral.
> 3. No menu que abre, clicar em **"Configurações do Perfil"**.
> 4. Rolar até a seção **"Alertas de áudio"**.
> 5. Em **"Eventos de alerta para conversas"**, escolher uma das opções:
>    - **"Conversas atribuídas"** (recomendado pra Yasmin/Marta/Daniel — só as conversas delas tocam som)
>    - **"Todas as conversas"** (recomendado pro Gustavo se quiser ouvir tudo)
> 6. Em **"Condições"**, deixar marcado **"Enviar alertas a cada 30 segundos até que todas as conversas atribuídas sejam lidas"** (assim não passa batido).
> 7. Pronto — fechar a janela. Não precisa salvar; a configuração já fica.
>
> **Como testar:** com o Frontdesk aberto (e navegador autorizado), pedir pra alguém mandar uma mensagem teste → o som toca + a conversa aparece na lista com a bolinha de não-lida.

---

## 8 — Caminho do admin pra acompanhar/assumir/transferir conversas em tempo real
**Relato do Gustavo:** "Como admin, qual o caminho pra acompanhar conversas em tempo real e interagir? E as colaboradoras puxarem conversa de outra (ex.: uma passou mal e saiu)?"

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** **já existe no Frontdesk — passo a passo abaixo.** É o mesmo padrão simples que o QUALIZAP, com 3 caminhos.
>
> **Caminho 1 — Ver TODAS as conversas em tempo real (visão admin):**
> 1. Na barra lateral esquerda, clicar em **"Conversas"** → **"Todas as conversas"**.
> 2. No topo da lista, escolher a aba **"Todos"** (em vez de "Minhas" ou "Não atribuídas").
> 3. Pronto — você vê todas as conversas, de todos os atendentes, ao vivo, sem precisar recarregar a página.
>
> **Caminho 2 — Você (admin) assumir a conversa de uma atendente:**
> 1. Abrir a conversa.
> 2. No **painel à direita** da conversa (Detalhes da conversa), procurar a seção **"Agente atribuído"** (ou "Atribuído a").
> 3. Clicar no nome da atendente atual → na lista que abre, escolher o **seu próprio nome**.
> 4. Pronto — você já pode responder no lugar dela. Ela perde a atribuição automaticamente.
>
> **Caminho 3 — Transferir entre atendentes (uma passou mal e saiu):**
> 1. Abrir a conversa da atendente que saiu (você consegue por "Todas as conversas" → "Todos").
> 2. No mesmo painel à direita, em **"Agente atribuído"**, clicar e escolher **outra agente** da lista.
> 3. Pronto — a conversa cai pra outra agente na hora.
>
> Os 3 caminhos funcionam em tempo real (sem refresh). Se for útil pra você passar pra equipe, gravo um vídeo de 1 minuto mostrando os 3.

---

## 9 — Conexão sempre online (não desconectar como o sistema atual dele)
**Relato do Gustavo:** "Fica desconectado e não recebo mensagem. Queria igual ao QUALIZAP que uso hoje — 100% online o tempo todo."

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** **já existe no Frontdesk — passo a passo abaixo.**
>
> Cada atendente consegue **deixar o status dela como "sempre online"** em 4 cliques. Quando isso está ligado, ela não sai do ar por inatividade — fica online o tempo todo, igual ao QUALIZAP.
>
> **Passo a passo (cada atendente faz no próprio login):**
> 1. Clicar no **avatar** no canto **inferior esquerdo** da barra lateral.
> 2. No menu que abre, procurar a opção **"Marcar offline automaticamente"** (é um interruptor / toggle).
> 3. **Desligar** esse interruptor.
> 4. Pronto — ela não vai mais ser marcada offline por ficar parada. Continua online recebendo mensagem em tempo real.
>
> **Alternativa (você como admin faz pra todas de uma vez):**
> 1. **Configurações** (engrenagem na barra lateral) → **"Agentes"**.
> 2. Editar cada atendente → desligar **"Marcar offline automaticamente"**.
> 3. Salvar.
>
> Se quiser, a gente já aplica isso pra todos os atendentes da Mais Saúde (Gustavo, Yasmin, Marta, Daniel etc.) num passo só — só pedir.
>
> **Como testar:** depois de desligado, deixar o Frontdesk aberto sem mexer por ~30 minutos → o status continua como "Online" e a próxima mensagem cai na conversa em tempo real.

---

## 10 — Renomear "não atribuídas" para "Inteligência Artificial"
**Relato do Gustavo:** "Pra facilitar a gestão, no lugar de 'não atribuídas' escrever 'inteligência artificial'."

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
>
> Vamos renomear o rótulo **"Não atribuídas"** pra **"Inteligência Artificial"** nas abas no topo da lista de conversas e em todos os pontos da plataforma que usam esse termo — fica claro pra equipe que aquelas conversas estão sendo cuidadas pela Lara, não estão abandonadas. Te respondo com prazo até quarta.
>
> **Como testar (após o ajuste):** abrir a lista de conversas → no topo, em vez de **"Minhas / Não atribuídas / Todos"** vai aparecer **"Minhas / Inteligência Artificial / Todos"**.

---

## 11 — Busca de contato sem exigir acento/cedilha
**Relato do Gustavo:** "Sem o acento na letra Á não encontra. Desabilitar a obrigatoriedade de acento/cedilha — com ou sem acento tem que achar."
**Ex.:** CÁSSIA OLIVEIRA FELIPE NOVATO

✏️ **RESPOSTA DO MATHEUS:**
> **Status:** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
>
> Hoje a busca de contato no Frontdesk considera o acento (digitar "cassia" não acha "CÁSSIA"). Vamos ajustar pra **ignorar acento e cedilha** — digitar "cassia" vai trazer "CÁSSIA", "luis" vai trazer "Luís", "concicao" vai trazer "Conceição", etc. Te respondo com prazo até quarta.
>
> **Como testar (após o ajuste):** no campo **"Buscar por nome, telefone ou #ID"** da lista de conversas (ou em **Contatos**), digitar "cassia" sem acento → "CÁSSIA OLIVEIRA FELIPE NOVATO" aparece nos resultados.

---

## 12 — Mídia: tempo real + ✓✓ de entrega + envio de imagem/áudio
**Relato do Gustavo:** (4 sub-itens)
- 12.1 — Imagens só aparecem após atualizar a página (deveria ser tempo real).
- 12.2 — Não conseguem ouvir áudios recebidos.
- 12.3 — Ao enviar print/imagem dá erro e não tem ✓/✓✓ de entrega.
- 12.4 — Ao enviar áudio idem — erro + sem ✓✓; "em alguns recebem, em outros não".

✏️ **RESPOSTA DO MATHEUS:**
> **12.1 — Imagem recebida em tempo real:** ✅ **resolvido em 25/05/2026.** Ajustamos a entrega da mídia no Frontdesk — agora a imagem que o cliente envia **aparece na conversa em tempo real**, sem precisar atualizar a página. Saiu junto com o ajuste do áudio (mesma causa, mesma correção).
> **Como testar:** cliente manda uma imagem → ela aparece na conversa da atendente em segundos, sem refresh.
>
> ---
>
> **12.2 — Ouvir áudio recebido:** ✅ **resolvido em 25/05/2026.** A entrega da mídia foi ajustada — os áudios que o cliente envia agora **tocam direto** no player do Frontdesk.
> **Como testar:** cliente manda um áudio → atendente abre a conversa, clica no botão de play no áudio → toca normal. Vale também pros áudios **antigos** da conversa: basta a atendente reabrir a conversa que eles voltam a tocar.
>
> ---
>
> **12.3 — Enviar imagem (erro + sem ✓/✓✓):** entra na rotina de desenvolvimento — **prazo informado até quarta (27/05)**.
> Vamos investigar o erro intermitente ao enviar imagem pelo atendente e o aparecimento dos ✓/✓✓ (status de entrega: enviado / entregue / lido) na mensagem enviada. Te respondo com prazo até quarta.
> **Como testar (após o ajuste):** atendente envia uma imagem → cliente recebe sem erro e aparecem na mensagem do atendente: ✓ (enviado pela rede) → ✓✓ (entregue no WhatsApp do cliente) → ✓✓ azul (lido).
>
> ---
>
> **12.4 — Enviar áudio (erro + sem ✓✓):** ✅ **erro de envio resolvido em 22/05/2026** — não dá mais "falha ao enviar". A parte dos ✓/✓✓ na mensagem enviada vai junto com o item 12.3 (entra na rotina, prazo até quarta).
> **Como testar:** atendente grava um áudio e envia → cliente recebe sem erro (em Android e iPhone). Os ✓✓ entram junto com o ajuste do 12.3.

---

## Quando terminar
Commit em `klaos-dev`:
```
docs(handoff): respostas Gustavo v2 — itens plataforma preenchidos
```
Eu (KLaOS) leio daqui e colo as respostas no Google Doc final que vai pro Gustavo.

Doc final no Drive (do KLaOS): "Respostas — Ajustes Mais Saúde (Lara + Plataforma) v2"
(você não precisa abrir — só me devolve este markdown preenchido)
