<!--
KLaOS — Linha do tempo unificada do contato
Renderiza TODAS as msgs de TODAS as convs do contato em ordem cronológica,
com divisores indicando boundary entre conversas. Read-only — reply continua
na conv ativa abaixo (não tocamos no ReplyBox).

Estratégia "réplica fiel":
- Markdown WhatsApp (*bold* _italic_ ~strike~ + links) via MessageFormatter
  (mesmo helper que o renderer principal do Chatwoot usa).
- Templates outgoing são expandidos no backend: `rendered_content` traz o body
  do template com {{1}}/{{2}}/etc substituídos por additional_attributes.
  template_params.processed_params.body — exatamente o que o cliente recebeu.
- template_meta carrega header/footer/buttons (se existirem) pra render
  completo com o frame de template.
- Mídia: image inline (clicável p/ abrir em nova aba), audio com player nativo,
  video, file fallback com nome.
- Notas internas (private=true): bolha amarela + badge "nota interna".
- Templates renomeados/excluídos no canal: badge vermelha + lista dos params
  enviados (ainda dá pra ver os dados que o cliente recebeu).

Endpoint: GET /api/custom/v1/accounts/:account_id/contacts/:contact_id/timeline
-->
<script setup>
/* global axios */
import { computed, ref, watch, onMounted } from 'vue';
import MessageFormatter from 'shared/helpers/MessageFormatter';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
  accountId: { type: [Number, String], required: true },
  currentConversationId: { type: [Number, String], default: null },
});

const messages = ref([]);
const conversations = ref([]);
const hasMore = ref(false);
const isLoading = ref(false);
const error = ref(null);

const conversationsById = computed(() => {
  const map = {};
  for (const c of conversations.value) map[c.id] = c;
  return map;
});

const fetchPage = async ({ before } = {}) => {
  if (isLoading.value) return;
  isLoading.value = true;
  error.value = null;
  try {
    const url = `/api/custom/v1/accounts/${props.accountId}/contacts/${props.contactId}/timeline`;
    const res = await axios.get(url, { params: { before } });
    if (before) {
      messages.value = [...res.data.messages, ...messages.value];
    } else {
      messages.value = res.data.messages;
      conversations.value = res.data.conversations || [];
    }
    hasMore.value = !!res.data.has_more;
  } catch (e) {
    error.value =
      e?.response?.data?.error || e.message || 'Erro ao carregar histórico';
  } finally {
    isLoading.value = false;
  }
};

const loadOlder = () => {
  if (!hasMore.value || messages.value.length === 0) return;
  // Cursor = menor id carregado. Robusto mesmo se a ordem visual reagrupar.
  const oldestId = messages.value.reduce(
    (min, m) => (m.id < min ? m.id : min),
    messages.value[0].id
  );
  fetchPage({ before: oldestId });
};

watch(
  () => props.contactId,
  () => {
    messages.value = [];
    conversations.value = [];
    hasMore.value = false;
    fetchPage();
  }
);

onMounted(() => fetchPage());

// Chave de dia (ano-mês-dia no fuso local do browser) pra agrupar separadores.
const dayKey = ts => {
  if (!ts) return null;
  const d = new Date(ts * 1000);
  if (Number.isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
};

// Agrupa mensagens em BLOCOS por conversa, com as conversas em ordem
// cronológica de INÍCIO (conv.created_at). Isso evita o "desalinho" antigo:
// quando lock_to_single_conversation estava OFF, conversas se sobrepunham no
// tempo (ex: conv A 15:35→18:50 e conv B 15:45→15:46 dentro dela). Ordenar
// tudo por created_at global intercalava as mensagens e fazia o divisor
// repetir/fragmentar. Agora cada conversa é um bloco contínuo, e dentro do
// bloco entram separadores por DIA.
const itemsWithDividers = computed(() => {
  const items = [];

  const msgsByConv = {};
  for (const m of messages.value) {
    (msgsByConv[m.conversation_id] ||= []).push(m);
  }

  const orderedConvs = Object.keys(msgsByConv)
    .map(id => {
      const conv = conversationsById.value[id];
      const firstMsgTs = Math.min(
        ...msgsByConv[id].map(m => m.created_at || 0)
      );
      return { id, conv, sortTs: conv?.created_at ?? firstMsgTs };
    })
    .sort((a, b) => a.sortTs - b.sortTs);

  for (const { id, conv } of orderedConvs) {
    items.push({
      kind: 'divider',
      conv: conv || { id, display_id: id, status: null },
      key: `div-${id}`,
    });

    const msgs = msgsByConv[id]
      .slice()
      .sort((a, b) => a.created_at - b.created_at || a.id - b.id);

    let lastDay = null;
    for (const m of msgs) {
      const day = dayKey(m.created_at);
      if (day && day !== lastDay) {
        items.push({ kind: 'day', ts: m.created_at, key: `day-${id}-${day}` });
        lastDay = day;
      }
      items.push({ kind: 'message', msg: m, key: `msg-${m.id}` });
    }
  }
  return items;
});

const STATUS_LABEL = {
  0: 'aberta',
  1: 'resolvida',
  2: 'pendente',
  3: 'adiada',
};
const formatConvBoundary = conv => {
  // Data do divisor = INÍCIO da conversa (created_at). Antes usava resolved_at
  // (fim da conversa), mas o divisor fica no TOPO do bloco — então mostrava uma
  // data que não batia com onde as mensagens daquela conversa começam. Era a
  // origem do "desalinho de datas".
  const d = conv.created_at ? new Date(conv.created_at * 1000) : null;
  const dateStr =
    d && !isNaN(d.getTime())
      ? `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
      : null;
  const status = STATUS_LABEL[conv.status] || conv.status || '';
  const statusPart = status ? ` · ${status}` : '';
  const isCurrent = String(conv.id) === String(props.currentConversationId);
  // display_id pode vir nulo em dados antigos/sincronizados → cai pro id, e se
  // nada existir omite o "#" em vez de mostrar "#undefined". Sem data → omite o
  // trecho "iniciada" em vez de mostrar "—".
  const idLabel = conv.display_id ?? conv.id;
  const idPart = idLabel != null && idLabel !== '' ? ` #${idLabel}` : '';
  const datePart = dateStr ? ` · iniciada ${dateStr}` : '';
  return `Conversa${idPart} · ${conv.inbox_name || ''}${statusPart}${datePart}${isCurrent ? ' · atual' : ''}`;
};

const formatDay = ts => {
  const d = new Date(ts * 1000);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleDateString('pt-BR', {
    weekday: 'long',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
};

const formatTime = ts => {
  if (!ts) return '';
  const d = new Date(ts * 1000);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

// message_type: 0=incoming, 1=outgoing, 2=activity, 3=template
const isIncoming = m => m.message_type === 0;
const isActivity = m => m.message_type === 2;
const isTemplate = m => Boolean(m.template_meta);
const isPrivateNote = m => Boolean(m.private);
const isTemplateMissing = m => m.template_meta?.status === 'template_not_found';

const senderLabel = m => {
  if (isIncoming(m)) return m.sender?.name || 'Cliente';
  if (m.sender_type === 'AgentBot') return `🤖 ${m.sender?.name || 'Bot'}`;
  if (m.sender_type === 'User') return m.sender?.name || 'Atendente';
  return 'Sistema';
};

// Texto que vai pro MessageFormatter:
// - Templates renderizados: rendered_content (body já com placeholders substituídos)
// - Texto livre: content
// Quando template não foi achado (renomeado/excluído) NÃO usamos content (que é só o nome do template);
// o fallback de params é renderizado num bloco separado abaixo.
const messageBodyText = m => {
  if (m.rendered_content) return m.rendered_content;
  if (isTemplate(m)) return ''; // sem body renderizado → renderiza fallback de params
  return m.content || '';
};

// Params enviados ao Meta (processed_params.body) — usado no fallback quando
// o template não foi achado em channel.message_templates (renomeado/excluído).
const templateProcessedParams = m => {
  const body = m.additional_attributes?.template_params?.processed_params?.body;
  if (!body || typeof body !== 'object') return [];
  return Object.entries(body).map(([key, value]) => ({
    key,
    value: String(value ?? ''),
  }));
};

// Detecta bubble realmente vazia (sem texto, sem template, sem anexo) — nesse
// caso mostra um placeholder pra usuário não pensar que quebrou.
const isEmptyBubble = m => {
  if (messageBodyText(m)) return false;
  if (isTemplate(m)) return false; // template tem fallback próprio
  if ((m.attachments || []).length > 0) return false;
  return true;
};

const formattedHtml = (text, isPrivate = false) => {
  if (!text) return '';
  // MessageFormatter aplica markdown (whatsapp-style fica próximo o suficiente:
  // *bold* → <strong>, _italic_ → <em>, etc) + linkify URLs.
  return new MessageFormatter(text, false, isPrivate, true).formattedMessage;
};

const openImage = url => {
  if (url) window.open(url, '_blank', 'noopener');
};
</script>

<template>
  <div
    class="klaos-timeline flex flex-col h-full min-h-0 w-full bg-n-surface-1 overflow-hidden"
  >
    <div
      class="flex-shrink-0 px-4 py-2 border-b border-n-weak bg-n-alpha-1 text-sm text-n-slate-11"
    >
      <span class="i-ph-clock-counter-clockwise mr-1.5 align-middle" />
      Linha do tempo unificada — todas as conversas com este contato
      <span v-if="conversations.length" class="ml-2 text-xs text-n-slate-10">
        ({{ conversations.length }} conversa{{
          conversations.length === 1 ? '' : 's'
        }})
      </span>
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto px-4 py-3">
      <div v-if="hasMore && !isLoading" class="text-center mb-3">
        <button class="text-xs text-n-brand hover:underline" @click="loadOlder">
          Carregar mensagens mais antigas
        </button>
      </div>

      <div
        v-if="isLoading && messages.length === 0"
        class="text-center text-sm text-n-slate-11 py-8"
      >
        Carregando histórico...
      </div>

      <div v-if="error" class="text-center text-sm text-n-ruby-11 py-4">
        {{ error }}
      </div>

      <div
        v-if="!isLoading && !error && messages.length === 0"
        class="text-center text-sm text-n-slate-11 py-8"
      >
        Nenhuma mensagem encontrada para este contato.
      </div>

      <template v-for="item in itemsWithDividers" :key="item.key">
        <!-- Divisor entre conversas -->
        <div
          v-if="item.kind === 'divider'"
          class="flex items-center gap-2 my-4"
        >
          <div class="flex-1 h-px bg-n-strong" />
          <span
            class="text-xs text-n-slate-10 font-medium px-2 py-0.5 rounded bg-n-alpha-1"
          >
            {{ formatConvBoundary(item.conv) }}
          </span>
          <div class="flex-1 h-px bg-n-strong" />
        </div>

        <!-- Separador por dia (dentro do bloco de uma conversa) -->
        <div
          v-else-if="item.kind === 'day'"
          class="flex items-center justify-center my-3"
        >
          <span
            class="text-[11px] uppercase tracking-wide text-n-slate-10 font-medium px-3 py-0.5 rounded-full bg-n-alpha-2 first-letter:uppercase"
          >
            {{ formatDay(item.ts) }}
          </span>
        </div>

        <!-- Activity message (italic, centralizada) -->
        <div
          v-else-if="isActivity(item.msg)"
          class="text-center text-xs text-n-slate-10 my-2 italic"
        >
          {{ item.msg.content }}
        </div>

        <!-- Bubble -->
        <div
          v-else
          class="flex w-full mb-2"
          :class="isIncoming(item.msg) ? 'justify-start' : 'justify-end'"
        >
          <div class="flex flex-col max-w-[75%] gap-0.5">
            <div
              class="text-xs text-n-slate-10 px-1 flex flex-wrap items-center gap-1"
              :class="isIncoming(item.msg) ? 'justify-start' : 'justify-end'"
            >
              <span>{{ senderLabel(item.msg) }}</span>
              <span
                v-if="isPrivateNote(item.msg)"
                class="px-1 rounded bg-n-amber-3 text-n-amber-11 font-medium"
              >
                <span class="i-ph-note-pencil size-3 align-middle mr-0.5" />nota
                interna
              </span>
              <span
                v-if="isTemplate(item.msg)"
                class="px-1 rounded bg-n-blue-3 text-n-blue-11"
              >
                template · {{ item.msg.template_meta?.name }}
              </span>
              <span
                v-if="isTemplateMissing(item.msg)"
                class="px-1 rounded bg-n-ruby-3 text-n-ruby-11"
              >
                renomeado/excluído
              </span>
              <span>· {{ formatTime(item.msg.created_at) }}</span>
            </div>
            <div
              class="rounded-xl px-3 py-2 text-sm break-words"
              :class="[
                isPrivateNote(item.msg)
                  ? 'bg-n-amber-3 text-n-amber-12 border border-n-amber-6 rounded-bl-sm'
                  : isIncoming(item.msg)
                    ? 'bg-n-slate-4 text-n-slate-12 rounded-bl-sm'
                    : 'bg-n-teal-3 text-n-teal-12 rounded-br-sm',
              ]"
            >
              <!-- Header do template (se houver) -->
              <div
                v-if="item.msg.template_meta?.header"
                class="font-semibold mb-1.5 message-formatter"
                v-html="formattedHtml(item.msg.template_meta.header)"
              />

              <!-- Corpo principal: rendered_content (template) ou content (texto livre) -->
              <div
                v-if="messageBodyText(item.msg)"
                class="message-formatter whitespace-pre-wrap"
                v-html="
                  formattedHtml(messageBodyText(item.msg), item.msg.private)
                "
              />

              <!-- Fallback para template não achado: lista os params que foram enviados -->
              <div
                v-if="
                  isTemplateMissing(item.msg) &&
                  templateProcessedParams(item.msg).length
                "
                class="text-xs"
              >
                <div class="text-n-slate-11 italic mb-1">
                  Template
                  <strong>{{ item.msg.template_meta?.name }}</strong> foi
                  renomeado ou excluído. Variáveis enviadas:
                </div>
                <div
                  class="flex flex-col gap-0.5 pl-2 border-l-2 border-n-alpha-2"
                >
                  <div
                    v-for="param in templateProcessedParams(item.msg)"
                    :key="param.key"
                    class="break-words"
                  >
                    <!-- "{{ key }}: value" sem usar literal {{ }} pra não quebrar o parser do Vue -->
                    <span class="text-n-slate-10">&#123;&#123;{{ param.key }}&#125;&#125;:</span>
                    <span class="ml-1">{{ param.value }}</span>
                  </div>
                </div>
              </div>

              <!-- Bubble verdadeiramente vazia (sem texto/template/anexo) -->
              <div
                v-else-if="isEmptyBubble(item.msg)"
                class="text-xs italic text-n-slate-10"
              >
                (mensagem sem conteúdo)
              </div>

              <!-- Footer do template -->
              <div
                v-if="item.msg.template_meta?.footer"
                class="mt-1.5 text-xs text-n-slate-11 italic"
              >
                {{ item.msg.template_meta.footer }}
              </div>

              <!-- Buttons do template -->
              <div
                v-if="item.msg.template_meta?.buttons?.length"
                class="mt-2 flex flex-col gap-1 pt-2 border-t border-n-alpha-2"
              >
                <template
                  v-for="(btn, btnIdx) in item.msg.template_meta.buttons"
                  :key="btnIdx"
                >
                  <!-- URL clicável (botões tipo "Pagar com Pix/Boleto") -->
                  <a
                    v-if="btn.type === 'URL' && btn.url"
                    :href="btn.url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="text-xs text-n-blue-11 text-center py-1 rounded bg-n-alpha-1 hover:bg-n-alpha-3 hover:underline transition-colors"
                  >
                    <span class="i-ph-link size-3 mr-1 align-middle" />
                    {{ btn.text }}
                  </a>
                  <!-- Telefone clicável -->
                  <a
                    v-else-if="btn.type === 'PHONE_NUMBER' && btn.phone_number"
                    :href="`tel:${btn.phone_number}`"
                    class="text-xs text-n-blue-11 text-center py-1 rounded bg-n-alpha-1 hover:bg-n-alpha-3 hover:underline transition-colors"
                  >
                    <span class="i-ph-phone size-3 mr-1 align-middle" />
                    {{ btn.text }}
                  </a>
                  <!-- QUICK_REPLY (ou URL sem link resolvido): não navega -->
                  <span
                    v-else
                    class="text-xs text-n-slate-11 text-center py-1 rounded bg-n-alpha-1"
                  >
                    <span class="i-ph-arrow-right size-3 mr-1 align-middle" />
                    {{ btn.text }}
                  </span>
                </template>
              </div>

              <!-- Attachments -->
              <div
                v-for="att in item.msg.attachments || []"
                :key="att.id"
                class="mt-1.5"
              >
                <img
                  v-if="att.file_type === 'image' && att.data_url"
                  :src="att.data_url"
                  class="rounded-lg max-w-full max-h-64 object-cover cursor-pointer hover:opacity-90"
                  loading="lazy"
                  @click="openImage(att.data_url)"
                />
                <audio
                  v-else-if="att.file_type === 'audio' && att.data_url"
                  :src="att.data_url"
                  controls
                  class="w-full"
                />
                <video
                  v-else-if="att.file_type === 'video' && att.data_url"
                  :src="att.data_url"
                  controls
                  class="rounded-lg max-w-full max-h-64"
                />
                <a
                  v-else-if="att.data_url"
                  :href="att.data_url"
                  target="_blank"
                  rel="noopener"
                  class="text-xs underline text-n-brand inline-flex items-center gap-1"
                >
                  <span class="i-ph-paperclip size-3" />
                  {{ att.fallback_title || `Anexo (${att.file_type})` }}
                </a>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
/* MessageFormatter retorna HTML com tags <p>, <strong>, <em>, <a> etc.
   Aplicamos os mínimos pra parecer nativo dentro do bubble. */
.message-formatter :deep(p) {
  margin: 0 0 0.5em 0;
}
.message-formatter :deep(p:last-child) {
  margin-bottom: 0;
}
.message-formatter :deep(strong) {
  font-weight: 700;
}
.message-formatter :deep(em) {
  font-style: italic;
}
.message-formatter :deep(a) {
  color: inherit;
  text-decoration: underline;
}
.message-formatter :deep(code) {
  background: rgba(0, 0, 0, 0.08);
  padding: 0 0.25em;
  border-radius: 3px;
  font-family: ui-monospace, monospace;
  font-size: 0.92em;
}
</style>
