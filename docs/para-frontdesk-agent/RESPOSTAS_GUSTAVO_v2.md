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
> [preencher]

---

## 2 — Notificação enviada deve abrir/atribuir a conversa pra quem enviou
**Relato do Gustavo:** "Enviei a notificação com o meu usuário e a conversa não veio pra mim. Deveria abrir/ficar em 'minhas'. Tive que pesquisar pelo nome e clicar em reabrir."
**Ex.:** PAULO ROBERTO DE ARRUDA PINTO

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 6 — Negrito com um único asterisco (estilo WhatsApp)
**Relato do Gustavo:** "Pra negrito tem que voltar o asterisco várias vezes — primeiro fica itálico. Não usamos itálico, só negrito. Deixar 1 asterisco no começo e fim = negrito."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 7 — Reabertura: mensagem nova reabre + bolinha verde (não lida) + som por atendente
**Relato do Gustavo:** "A reabertura não está funcionando, a mensagem não abre. Deveria reabrir com a bolinha verde (não-lida) e alertar com o sinal sonoro configurado pra cada agente."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 8 — Caminho do admin pra acompanhar/assumir/transferir conversas em tempo real
**Relato do Gustavo:** "Como admin, qual o caminho pra acompanhar conversas em tempo real e interagir? E as colaboradoras puxarem conversa de outra (ex.: uma passou mal e saiu)?"
**Observação:** parte é how-to (já existe na plataforma — descrever o passo a passo), parte pode ser gap de UX (se tiver, descrever o ajuste).

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher — incluir passo a passo do admin: ver todas as conversas → assumir → reatribuir]

---

## 9 — Conexão sempre online (não desconectar como o sistema atual dele)
**Relato do Gustavo:** "Fica desconectado e não recebo mensagem. Queria igual ao QUALIZAP que uso hoje — 100% online o tempo todo."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 10 — Renomear "não atribuídas" para "Inteligência Artificial"
**Relato do Gustavo:** "Pra facilitar a gestão, no lugar de 'não atribuídas' escrever 'inteligência artificial'."

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 11 — Busca de contato sem exigir acento/cedilha
**Relato do Gustavo:** "Sem o acento na letra Á não encontra. Desabilitar a obrigatoriedade de acento/cedilha — com ou sem acento tem que achar."
**Ex.:** CÁSSIA OLIVEIRA FELIPE NOVATO

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> [preencher]

---

## 12 — Mídia: tempo real + ✓✓ de entrega + envio de imagem/áudio
**Relato do Gustavo:** (4 sub-itens)
- 12.1 — Imagens só aparecem após atualizar a página (deveria ser tempo real).
- 12.2 — Não conseguem ouvir áudios recebidos. **(já endereçado — confirmar a resolução pro Gustavo testar)**
- 12.3 — Ao enviar print/imagem dá erro e não tem ✓/✓✓ de entrega.
- 12.4 — Ao enviar áudio idem — erro + sem ✓✓; "em alguns recebem, em outros não".

✏️ **RESPOSTA DA EQUIPE FRONTDESK:**
> 12.1 — [preencher]
> 12.2 — [preencher: já resolvido — confirmar como testar (ex.: tocar áudio novo na conversa)]
> 12.3 — [preencher]
> 12.4 — [preencher]

---

## Quando terminar
Commit em `klaos-dev`:
```
docs(handoff): respostas Gustavo v2 — itens plataforma preenchidos
```
Eu (KLaOS) leio daqui e colo as respostas no Google Doc final que vai pro Gustavo.

Doc final no Drive (do KLaOS): "Respostas — Ajustes Mais Saúde (Lara + Plataforma) v2"
(você não precisa abrir — só me devolve este markdown preenchido)
