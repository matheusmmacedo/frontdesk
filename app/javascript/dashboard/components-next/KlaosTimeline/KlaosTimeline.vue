<!--
KLaOS — Linha do tempo unificada do contato
Renderiza TODAS as msgs de TODAS as convs do contato em ordem cronológica,
com divisores indicando boundary entre conversas. Read-only — reply continua
na conv ativa abaixo (não tocamos no ReplyBox).

Endpoint: GET /api/custom/v1/accounts/:account_id/contacts/:contact_id/timeline
Componente é instanciado dentro de ConversationBox quando o toggle KLaOS
"Histórico do contato" está ativo. ConversationBox passa contact-id via prop.
-->
<script setup>
/* global axios */
import { computed, ref, watch, onMounted } from 'vue';

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

// Mostra divisor "─── Conversa #N ───" antes da PRIMEIRA msg de cada conv,
// percorrendo a lista cronológica (ASC). Marca em quais índices a conv muda.
const itemsWithDividers = computed(() => {
  const items = [];
  let lastConvId = null;
  for (const m of messages.value) {
    if (m.conversation_id !== lastConvId) {
      const conv = conversationsById.value[m.conversation_id];
      if (conv) items.push({ kind: 'divider', conv, key: `div-${conv.id}` });
      lastConvId = m.conversation_id;
    }
    items.push({ kind: 'message', msg: m, key: `msg-${m.id}` });
  }
  return items;
});

const STATUS_LABEL = { 0: 'aberta', 1: 'resolvida', 2: 'pendente', 3: 'adiada' };
const formatConvBoundary = conv => {
  const dt = conv.resolved_at || conv.created_at;
  const d = new Date(dt * 1000);
  const dateStr = `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
  const status = STATUS_LABEL[conv.status] || conv.status;
  const isCurrent = String(conv.id) === String(props.currentConversationId);
  return `Conversa #${conv.display_id} · ${conv.inbox_name || ''} · ${status} · ${dateStr}${isCurrent ? ' (atual)' : ''}`;
};

const formatTime = ts => {
  const d = new Date(ts * 1000);
  return d.toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
};

// message_type: 0=incoming, 1=outgoing, 2=activity, 3=template
const isIncoming = m => m.message_type === 0;
const isActivity = m => m.message_type === 2;

const senderLabel = m => {
  if (isIncoming(m)) return m.sender?.name || 'Cliente';
  if (m.sender_type === 'AgentBot') return `🤖 ${m.sender?.name || 'Bot'}`;
  if (m.sender_type === 'User') return m.sender?.name || 'Atendente';
  return 'Sistema';
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

        <!-- Activity message -->
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
              {{ senderLabel(item.msg) }} · {{ formatTime(item.msg.created_at) }}
            </div>
            <div
              class="rounded-xl px-3 py-2 text-sm whitespace-pre-wrap break-words"
              :class="isIncoming(item.msg)
                ? 'bg-n-slate-4 text-n-slate-12 rounded-bl-sm'
                : 'bg-n-teal-3 text-n-teal-12 rounded-br-sm'"
            >
              <span v-if="item.msg.content">{{ item.msg.content }}</span>
              <div
                v-for="att in item.msg.attachments || []"
                :key="att.id"
                class="mt-1.5"
              >
                <img
                  v-if="att.file_type === 'image' && att.data_url"
                  :src="att.data_url"
                  class="rounded-lg max-w-full max-h-64 object-cover"
                  loading="lazy"
                />
                <audio
                  v-else-if="att.file_type === 'audio' && att.data_url"
                  :src="att.data_url"
                  controls
                  class="w-full"
                />
                <a
                  v-else-if="att.data_url"
                  :href="att.data_url"
                  target="_blank"
                  rel="noopener"
                  class="text-xs underline text-n-brand inline-flex items-center gap-1"
                >
                  <span class="i-ph-paperclip size-3" />
                  Anexo ({{ att.file_type }})
                </a>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
