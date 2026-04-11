<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import TemplatePreview from './TemplatePreview.vue';

const props = defineProps({
  initialTemplate: { type: Object, default: null },
  isEditMode: { type: Boolean, default: false },
  connectionId: { type: [Number, String], default: null },
});

const emit = defineEmits(['save', 'cancel']);
const { t } = useI18n();
const store = useStore();

const name = ref(props.initialTemplate?.name || '');
const language = ref(props.initialTemplate?.language || 'pt_BR');
const category = ref(props.initialTemplate?.category || 'UTILITY');
const allowCategoryChange = ref(true);

// Components state
const headerType = ref('NONE');
const headerText = ref('');
const bodyText = ref('');
const footerText = ref('');
const buttons = ref([]);

// Variable examples
const headerExamples = ref({});
const bodyExamples = ref({});

// Media header state
const headerMediaFile = ref(null);
const headerMediaHandle = ref('');
const headerMediaPreviewUrl = ref('');
const isUploadingMedia = ref(false);
const mediaUploadError = ref('');

const MEDIA_ACCEPT = {
  IMAGE: 'image/jpeg,image/png',
  VIDEO: 'video/mp4,video/3gpp',
  DOCUMENT: 'application/pdf',
};

const MEDIA_TYPE_MAP = { IMAGE: 'image', VIDEO: 'video', DOCUMENT: 'document' };

async function handleMediaUpload(event) {
  const file = event.target.files?.[0];
  if (!file || !props.connectionId) return;

  headerMediaFile.value = file;
  mediaUploadError.value = '';

  // Show local preview for images
  if (headerType.value === 'IMAGE' && file.type.startsWith('image/')) {
    headerMediaPreviewUrl.value = URL.createObjectURL(file);
  } else {
    headerMediaPreviewUrl.value = '';
  }

  // Upload to Meta
  isUploadingMedia.value = true;
  try {
    const mediaType = MEDIA_TYPE_MAP[headerType.value];
    const result = await store.dispatch('whatsappConnections/uploadTemplateMedia', {
      connectionId: props.connectionId,
      file,
      mediaType,
    });
    headerMediaHandle.value = result.handle;
  } catch (err) {
    mediaUploadError.value = err?.response?.data?.error || err.message || 'Upload falhou';
    headerMediaFile.value = null;
    headerMediaHandle.value = '';
  } finally {
    isUploadingMedia.value = false;
  }
}

function clearMediaUpload() {
  headerMediaFile.value = null;
  headerMediaHandle.value = '';
  headerMediaPreviewUrl.value = '';
  mediaUploadError.value = '';
}

// Populate from initialTemplate if editing
if (props.initialTemplate?.components) {
  const comps = props.initialTemplate.components;
  const hdr = comps.find(c => c.type === 'HEADER');
  if (hdr) {
    headerType.value = hdr.format || 'TEXT';
    headerText.value = hdr.text || '';
  }
  const bdy = comps.find(c => c.type === 'BODY');
  if (bdy) bodyText.value = bdy.text || '';
  const ftr = comps.find(c => c.type === 'FOOTER');
  if (ftr) footerText.value = ftr.text || '';
  const btns = comps.find(c => c.type === 'BUTTONS');
  if (btns?.buttons) buttons.value = btns.buttons.map(b => ({ ...b }));
}

// Count variables in text
function countVars(text) {
  const matches = text.match(/\{\{\d+\}\}/g);
  return matches ? [...new Set(matches)].length : 0;
}

const bodyVarCount = computed(() => countVars(bodyText.value));
const headerVarCount = computed(() =>
  headerType.value === 'TEXT' ? countVars(headerText.value) : 0
);

// Build components for API
const components = computed(() => {
  const comps = [];

  if (headerType.value !== 'NONE') {
    const hdr = { type: 'HEADER', format: headerType.value };
    if (headerType.value === 'TEXT') {
      hdr.text = headerText.value;
      if (headerVarCount.value > 0) {
        const examples = [];
        for (let i = 1; i <= headerVarCount.value; i++) {
          examples.push(headerExamples.value[i] || `exemplo_${i}`);
        }
        hdr.example = { header_text: examples };
      }
    } else if (['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerType.value)) {
      // Media header: use handle from upload or URL
      if (headerMediaHandle.value) {
        hdr.example = { header_handle: [headerMediaHandle.value] };
      }
    }
    comps.push(hdr);
  }

  if (bodyText.value.trim()) {
    const bdy = { type: 'BODY', text: bodyText.value };
    if (bodyVarCount.value > 0) {
      const examples = [];
      for (let i = 1; i <= bodyVarCount.value; i++) {
        examples.push(bodyExamples.value[i] || `exemplo_${i}`);
      }
      bdy.example = { body_text: [examples] };
    }
    comps.push(bdy);
  }

  if (footerText.value.trim()) {
    comps.push({ type: 'FOOTER', text: footerText.value });
  }

  if (buttons.value.length > 0) {
    comps.push({
      type: 'BUTTONS',
      buttons: buttons.value.map(b => {
        const btn = { type: b.type, text: b.text };
        if (b.type === 'URL') btn.url = b.url || '';
        if (b.type === 'PHONE_NUMBER') btn.phone_number = b.phone_number || '';
        return btn;
      }),
    });
  }

  return comps;
});

// Build preview template object
const previewTemplate = computed(() => ({
  name: name.value,
  components: components.value,
}));

const sampleValues = computed(() => {
  const vals = {};
  Object.entries(bodyExamples.value).forEach(([k, v]) => {
    vals[k] = v;
  });
  Object.entries(headerExamples.value).forEach(([k, v]) => {
    vals[`header_${k}`] = v;
  });
  return vals;
});

function addButton(type) {
  if (buttons.value.length >= 3) return;
  const btn = { type, text: '' };
  if (type === 'URL') btn.url = '';
  if (type === 'PHONE_NUMBER') btn.phone_number = '';
  buttons.value.push(btn);
}

function removeButton(index) {
  buttons.value.splice(index, 1);
}

function insertVariable(field) {
  if (field === 'body') {
    const currentVars = bodyText.value.match(/\{\{\d+\}\}/g) || [];
    const nums = currentVars.map(v => parseInt(v.replace(/[{}]/g, '')));
    const next = nums.length > 0 ? Math.max(...nums) + 1 : 1;
    bodyText.value += `{{${next}}}`;
  } else if (field === 'header') {
    if (headerVarCount.value === 0) {
      headerText.value += '{{1}}';
    }
  }
}

const validationErrors = computed(() => {
  const errors = [];
  if (!props.isEditMode) {
    if (!name.value.trim()) errors.push('Nome é obrigatório');
    else if (!/^[a-z0-9_]+$/.test(name.value)) errors.push('Nome deve conter apenas letras minúsculas, números e _');
  }
  if (!bodyText.value.trim()) errors.push('Corpo é obrigatório');
  if (bodyText.value.length > 1024) errors.push(`Corpo excede 1024 caracteres (${bodyText.value.length})`);
  if (footerText.value.length > 60) errors.push(`Rodapé excede 60 caracteres (${footerText.value.length})`);
  for (const [idx, btn] of buttons.value.entries()) {
    if (!btn.text.trim()) errors.push(`Botão ${idx + 1}: texto obrigatório`);
    if (btn.text.length > 25) errors.push(`Botão ${idx + 1}: texto excede 25 caracteres`);
    if (btn.type === 'URL') {
      if (!btn.url?.trim()) errors.push(`Botão ${idx + 1}: URL obrigatória`);
      else if (!btn.url.startsWith('https://')) errors.push(`Botão ${idx + 1}: URL deve começar com https://`);
    }
    if (btn.type === 'PHONE_NUMBER') {
      if (!btn.phone_number?.trim()) errors.push(`Botão ${idx + 1}: telefone obrigatório`);
      else if (!btn.phone_number.startsWith('+')) errors.push(`Botão ${idx + 1}: telefone deve começar com +`);
    }
  }
  if (headerType.value === 'TEXT' && headerText.value.length > 60) {
    errors.push(`Header excede 60 caracteres (${headerText.value.length})`);
  }
  if (['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerType.value) && !headerMediaHandle.value && !props.isEditMode) {
    errors.push('Upload de media obrigatorio para header ' + headerType.value);
  }
  if (isUploadingMedia.value) {
    errors.push('Aguardando upload de media...');
  }
  return errors;
});

const isValid = computed(() => validationErrors.value.length === 0);

function save() {
  if (!isValid.value) return;

  const payload = { components: components.value };
  if (!props.isEditMode) {
    payload.name = name.value;
    payload.language = language.value;
    payload.category = category.value;
    payload.allow_category_change = allowCategoryChange.value;
  }
  emit('save', payload);
}

const LANGUAGES = [
  { code: 'pt_BR', label: 'Português (BR)' },
  { code: 'pt_PT', label: 'Português (PT)' },
  { code: 'en_US', label: 'English (US)' },
  { code: 'en_GB', label: 'English (UK)' },
  { code: 'es', label: 'Español' },
  { code: 'es_AR', label: 'Español (AR)' },
  { code: 'es_MX', label: 'Español (MX)' },
  { code: 'fr', label: 'Français' },
  { code: 'de', label: 'Deutsch' },
  { code: 'it', label: 'Italiano' },
  { code: 'ja', label: '日本語' },
  { code: 'ko', label: '한국어' },
  { code: 'zh_CN', label: '中文 (简体)' },
  { code: 'zh_TW', label: '中文 (繁體)' },
  { code: 'ar', label: 'العربية' },
  { code: 'hi', label: 'हिन्दी' },
  { code: 'ru', label: 'Русский' },
  { code: 'tr', label: 'Türkçe' },
  { code: 'nl', label: 'Nederlands' },
  { code: 'pl', label: 'Polski' },
  { code: 'sv', label: 'Svenska' },
  { code: 'da', label: 'Dansk' },
  { code: 'fi', label: 'Suomi' },
  { code: 'nb', label: 'Norsk' },
  { code: 'he', label: 'עברית' },
  { code: 'id', label: 'Bahasa Indonesia' },
  { code: 'ms', label: 'Bahasa Melayu' },
  { code: 'th', label: 'ไทย' },
  { code: 'vi', label: 'Tiếng Việt' },
  { code: 'uk', label: 'Українська' },
  { code: 'ro', label: 'Română' },
  { code: 'cs', label: 'Čeština' },
  { code: 'hu', label: 'Magyar' },
  { code: 'el', label: 'Ελληνικά' },
];
</script>

<template>
  <div class="flex gap-6">
    <!-- Editor -->
    <div class="flex-1 flex flex-col gap-4">
      <!-- Name, Language, Category (only for create) -->
      <div v-if="!isEditMode" class="flex flex-col gap-3">
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.NAME') }}
          </span>
          <input
            v-model="name"
            type="text"
            :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.NAME_PLACEHOLDER')"
            class="px-3 py-2 border border-n-weak rounded-lg text-sm font-mono"
            pattern="[a-z0-9_]+"
          />
          <span class="text-xs text-n-slate-9">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.NAME_HINT') }}
          </span>
        </label>

        <div class="flex gap-3">
          <label class="flex flex-col gap-1 flex-1">
            <span class="text-sm font-medium text-n-slate-11">
              {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.LANGUAGE') }}
            </span>
            <select
              v-model="language"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            >
              <option v-for="lang in LANGUAGES" :key="lang.code" :value="lang.code">
                {{ lang.label }}
              </option>
            </select>
          </label>
          <label class="flex flex-col gap-1 flex-1">
            <span class="text-sm font-medium text-n-slate-11">
              {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.CATEGORY') }}
            </span>
            <select
              v-model="category"
              class="px-3 py-2 border border-n-weak rounded-lg text-sm"
            >
              <option value="MARKETING">Marketing</option>
              <option value="UTILITY">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.CATEGORIES.UTILITY') }}</option>
              <option value="AUTHENTICATION">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.CATEGORIES.AUTHENTICATION') }}</option>
            </select>
          </label>
        </div>
      </div>

      <!-- Header -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER') }}
          </span>
          <select
            v-model="headerType"
            class="px-2 py-1 border border-n-weak rounded text-xs"
          >
            <option value="NONE">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_NONE') }}</option>
            <option value="TEXT">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_TEXT') }}</option>
            <option value="IMAGE">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_IMAGE') }}</option>
            <option value="VIDEO">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_VIDEO') }}</option>
            <option value="DOCUMENT">{{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_DOCUMENT') }}</option>
          </select>
        </div>
        <!-- Media header upload (IMAGE/VIDEO/DOCUMENT) -->
        <div v-if="['IMAGE', 'VIDEO', 'DOCUMENT'].includes(headerType)" class="flex flex-col gap-2">
          <div v-if="!headerMediaFile" class="flex flex-col gap-1">
            <label
              class="flex items-center justify-center gap-2 p-4 border-2 border-dashed border-n-weak rounded-lg cursor-pointer hover:bg-n-alpha-1 transition-colors"
            >
              <span class="text-sm text-n-slate-9">
                {{ headerType === 'IMAGE' ? 'Selecionar imagem (JPG, PNG, max 5MB)' :
                   headerType === 'VIDEO' ? 'Selecionar video (MP4, max 16MB)' :
                   'Selecionar documento (PDF, max 100MB)' }}
              </span>
              <input
                type="file"
                :accept="MEDIA_ACCEPT[headerType]"
                class="hidden"
                @change="handleMediaUpload"
              />
            </label>
          </div>
          <div v-else class="flex items-center gap-2 p-2 bg-n-alpha-1 rounded-lg">
            <div v-if="headerMediaPreviewUrl && headerType === 'IMAGE'" class="w-16 h-16 rounded overflow-hidden">
              <img :src="headerMediaPreviewUrl" class="w-full h-full object-cover" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm truncate">{{ headerMediaFile.name }}</p>
              <p class="text-xs text-n-slate-9">{{ (headerMediaFile.size / 1024).toFixed(0) }}KB</p>
              <p v-if="isUploadingMedia" class="text-xs text-n-brand">Enviando para Meta...</p>
              <p v-else-if="headerMediaHandle" class="text-xs text-green-600">Upload concluido</p>
              <p v-if="mediaUploadError" class="text-xs text-red-500">{{ mediaUploadError }}</p>
            </div>
            <button class="text-red-500 hover:text-red-700 text-sm shrink-0" @click="clearMediaUpload">
              Remover
            </button>
          </div>
        </div>

        <!-- Text header -->
        <div v-if="headerType === 'TEXT'" class="flex flex-col gap-1">
          <div class="flex gap-2">
            <input
              v-model="headerText"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.HEADER_PLACEHOLDER')"
              class="flex-1 px-3 py-2 border border-n-weak rounded-lg text-sm"
              maxlength="60"
            />
            <button
              v-if="headerVarCount === 0"
              class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
              @click="insertVariable('header')"
            >
              + {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.VARIABLE') }}
            </button>
          </div>
          <!-- Header variable examples -->
          <div v-if="headerVarCount > 0" class="flex gap-2">
            <div v-for="i in headerVarCount" :key="i" class="flex-1">
              <input
                v-model="headerExamples[i]"
                type="text"
                :placeholder="`Exemplo {{${i}}}`"
                class="w-full px-2 py-1 border border-yellow-200 bg-yellow-50 rounded text-xs"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Body -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BODY') }}
            <span class="text-red-500">*</span>
          </span>
          <div class="flex items-center gap-2">
            <span class="text-xs text-n-slate-9">{{ bodyText.length }}/1024</span>
            <button
              class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
              @click="insertVariable('body')"
            >
              + {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.VARIABLE') }}
            </button>
          </div>
        </div>
        <textarea
          v-model="bodyText"
          :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BODY_PLACEHOLDER')"
          class="px-3 py-2 border border-n-weak rounded-lg text-sm min-h-[120px] resize-y"
          maxlength="1024"
        />
        <div class="flex items-center gap-2 text-xs text-n-slate-9">
          <span>*texto* = <strong>negrito</strong></span>
          <span>_texto_ = <em>itálico</em></span>
          <span>~texto~ = <del>riscado</del></span>
        </div>
        <!-- Body variable examples -->
        <div v-if="bodyVarCount > 0" class="flex flex-col gap-1">
          <span class="text-xs font-medium text-n-slate-9">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.VARIABLE_EXAMPLES') }}
          </span>
          <div class="flex flex-wrap gap-2">
            <div v-for="i in bodyVarCount" :key="i" class="flex-1 min-w-[120px]">
              <input
                v-model="bodyExamples[i]"
                type="text"
                :placeholder="`Exemplo {{${i}}}`"
                class="w-full px-2 py-1 border border-yellow-200 bg-yellow-50 rounded text-xs"
              />
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.FOOTER') }}
          </span>
          <span class="text-xs text-n-slate-9">{{ footerText.length }}/60</span>
        </div>
        <input
          v-model="footerText"
          type="text"
          :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.FOOTER_PLACEHOLDER')"
          class="px-3 py-2 border border-n-weak rounded-lg text-sm"
          maxlength="60"
        />
      </div>

      <!-- Buttons -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BUTTONS') }}
          </span>
          <div v-if="buttons.length < 3" class="flex gap-1">
            <button
              class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
              @click="addButton('QUICK_REPLY')"
            >
              + {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BTN_QUICK_REPLY') }}
            </button>
            <button
              class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
              @click="addButton('URL')"
            >
              + {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BTN_URL') }}
            </button>
            <button
              class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
              @click="addButton('PHONE_NUMBER')"
            >
              + {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BTN_PHONE') }}
            </button>
          </div>
        </div>
        <div v-for="(btn, idx) in buttons" :key="idx" class="flex gap-2 items-start p-2 bg-n-alpha-1 rounded">
          <span class="text-xs text-n-slate-9 mt-2 w-20 shrink-0">
            {{ btn.type === 'QUICK_REPLY' ? 'Resposta' : btn.type === 'URL' ? 'Link' : 'Telefone' }}
          </span>
          <div class="flex-1 flex flex-col gap-1">
            <input
              v-model="btn.text"
              type="text"
              :placeholder="t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.BTN_TEXT_PLACEHOLDER')"
              class="px-2 py-1 border border-n-weak rounded text-sm"
              maxlength="25"
            />
            <input
              v-if="btn.type === 'URL'"
              v-model="btn.url"
              type="url"
              placeholder="https://..."
              class="px-2 py-1 border border-n-weak rounded text-sm"
            />
            <input
              v-if="btn.type === 'PHONE_NUMBER'"
              v-model="btn.phone_number"
              type="tel"
              placeholder="+5511999999999"
              class="px-2 py-1 border border-n-weak rounded text-sm"
            />
          </div>
          <button
            class="text-red-500 hover:text-red-700 text-sm mt-1"
            @click="removeButton(idx)"
          >
            ✕
          </button>
        </div>
      </div>

      <!-- Validation Errors -->
      <div v-if="validationErrors.length > 0" class="flex flex-col gap-1 p-3 bg-red-50 border border-red-200 rounded-lg">
        <span v-for="err in validationErrors" :key="err" class="text-xs text-red-600">
          {{ err }}
        </span>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-2 pt-2 border-t border-n-weak">
        <button
          class="px-4 py-2 text-sm border border-n-weak rounded-lg"
          @click="emit('cancel')"
        >
          {{ t('WHATSAPP_CONNECTIONS.ACTIONS.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg disabled:opacity-50"
          :disabled="!isValid"
          @click="save"
        >
          {{ isEditMode
            ? t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.SAVE_CHANGES')
            : t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.SUBMIT')
          }}
        </button>
      </div>
    </div>

    <!-- Live Preview -->
    <div class="w-80 shrink-0">
      <div class="sticky top-4">
        <span class="text-sm font-medium text-n-slate-11 mb-2 block">
          {{ t('WHATSAPP_CONNECTIONS.TEMPLATE_EDITOR.PREVIEW') }}
        </span>
        <TemplatePreview :template="previewTemplate" :sample-values="sampleValues" :media-preview-url="headerMediaPreviewUrl" />
      </div>
    </div>
  </div>
</template>
