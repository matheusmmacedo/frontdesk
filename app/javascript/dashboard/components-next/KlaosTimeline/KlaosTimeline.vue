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
    error.value = e?.response?.data?.error || e.message || 'Erro ao carregar histórico';
  } finally {
    isLoading.value = false;
  }
};

const loadOlder = () => {
  if (!hasMore.value || messages.value.length === 0) return;
  const oldestId = messages.value[0].id;
  fetchPage({ before: oldestId });
};

watch(() => props.contactId, () => {
  messages.value = [];
  conversations.value = [];
  hasMore.value = false;
  fetchPage();
});

onMounted(() => fetchPage());

const itemsWithDividers = computed(() => {
  const items = [];
  let lastConvId = null;
  for (const m of messages.value) {
    if (m.conversation_id !== lastConvId) {
      const conv = conversationsById.value[m.conversation_id];
      if (conv) items.push({ kind: 'divider', conv, key: `div-${conv.id}-${m.id}` });
      lastConvId = m.conversation_id;
    }
    items.push({ kind: 'message', msg: m, key: `msg-${m.id}` });
  }
  return items;
});

const STATUS_LABEL = { 0: 'aberta', 1: 'resolvida', 2: 'pendente', 3: 'adiada' };
const formatConvBoundary = conv => {
  // resolved_at vem do additional_attributes.klaos_resolved_at; created_at é fallback.
  const dt = conv.resolved_at || conv.created_at;
  const d = dt ? new Date(dt * 1000) : null;
  const dateStr = d && !isNaN(d.getTime())
    ? `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
    : '—';
  const status = STATUS_LABEL[conv.status] || conv.status || '';
  const isCurrent = String(conv.id) === String(props.currentConversationId);
  return `Conversa #${conv.display_id} · ${conv.inbox_name || ''} · ${status} · ${dateStr}${isCurrent ? ' · atual' : ''}`;
};

const formatTime = ts => {
  if (!ts) return '';
  const d = new Date(ts * 1000);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
};

// message_type: 0=incoming, 1=outgoing, 2=activity, 3=template
const isIncoming = m => m.message_type === 0;
const isActivity = m => m.message_type === 2;
const isTemplate = m => Boolean(m.template_meta);

const senderLabel = m => {
  if (isIncoming(m)) return m.sender?.name || 'Cliente';
  if (m.sender_type === 'AgentBot') return `🤖 ${m.sender?.name || 'Bot'}`;
  if (m.sender_type === 'User') return m.sender?.name || 'Atendente';
  return 'Sistema';
};

// Texto que vai pro MessageFormatter:
// - Templates: rendered_content (body já com placeholders substituídos)
// - Resto: content cru
const messageBodyText = m => {
  if (m.rendered_content) return m.rendered_content;
  if (isTemplate(m) && !m.rendered_content) return m.content; // template_not_found → mostra nome cru
  return m.content || '';
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
  <div class="klaos-timeline flex flex-col h-full min-h-0 w-full bg-n-surface-1 overflow-hidden">
    <div class="flex-shrink-0 px-4 py-2 border-b border-n-weak bg-n-alpha-1 text-sm text-n-slate-11">
      <span class="i-ph-clock-counter-clockwise mr-1.5 align-middle" />
      Linha do tempo unificada — todas as conversas com este contato
      <span v-if="conversations.length" class="ml-2 text-xs text-n-slate-10">
        ({{ conversations.length }} conversa{{ conversations.length === 1 ? '' : 's' }})
      </span>
    </div>

    <div class="flex-1 min-h-0 overflow-y-auto px-4 py-3">
      <div v-if="hasMore && !isLoading" class="text-center mb-3">
        <button
          class="text-xs text-n-brand hover:underline"
          @click="loadOlder"
        >
          Carregar mensagens mais antigas
        </button>
      </div>

      <div v-if="isLoading && messages.length === 0" class="text-center text-sm text-n-slate-11 py-8">
        Carregando histórico...
      </div>

      <div v-if="error" class="text-center text-sm text-n-ruby-11 py-4">
        {{ error }}
      </div>

      <div v-if="!isLoading && !error && messages.length === 0" class="text-center text-sm text-n-slate-11 py-8">
        Nenhuma mensagem encontrada para este contato.
      </div>

      <template v-for="item in itemsWithDividers" :key="item.key">
        <!-- Divisor entre conversas -->
        <div v-if="item.kind === 'divider'" class="flex items-center gap-2 my-4">
          <div class="flex-1 h-px bg-n-strong" />
          <span class="text-xs text-n-slate-10 font-medium px-2 py-0.5 rounded bg-n-alpha-1">
            {{ formatConvBoundary(item.conv) }}
          </span>
          <div class="flex-1 h-px bg-n-strong" />
        </div>

        <!-- Activity message (italic, centralizada) -->
        <div v-else-if="isActivity(item.msg)" class="text-center text-xs text-n-slate-10 my-2 italic">
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
              class="text-xs text-n-slate-10 px-1"
              :class="isIncoming(item.msg) ? 'text-left' : 'text-right'"
            >
              {{ senderLabel(item.msg) }}
              <span v-if="isTemplate(item.msg)" class="ml-1 px-1 rounded bg-n-blue-3 text-n-blue-11">
                template · {{ item.msg.template_meta?.name }}
              </span>
              · {{ formatTime(item.msg.created_at) }}
            </div>
            <div
              class="rounded-xl px-3 py-2 text-sm break-words"
              :class="isIncoming(item.msg)
                ? 'bg-n-slate-4 text-n-slate-12 rounded-bl-sm'
                : 'bg-n-teal-3 text-n-teal-12 rounded-br-sm'"
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
                v-html="formattedHtml(messageBodyText(item.msg), item.msg.private)"
              />

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
                <span
                  v-for="(btn, btnIdx) in item.msg.template_meta.buttons"
                  :key="btnIdx"
                  class="text-xs text-n-blue-11 text-center py-1 rounded bg-n-alpha-1"
                >
                  <span v-if="btn.type === 'URL'" class="i-ph-link size-3 mr-1 align-middle" />
                  <span v-else-if="btn.type === 'PHONE_NUMBER'" class="i-ph-phone size-3 mr-1 align-middle" />
                  <span v-else class="i-ph-arrow-right size-3 mr-1 align-middle" />
                  {{ btn.text }}
                </span>
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
