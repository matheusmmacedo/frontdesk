<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  initialTemplate: { type: Object, default: null },
  isEditMode: { type: Boolean, default: false },
});

const emit = defineEmits(['save', 'cancel']);

const name = ref(props.initialTemplate?.name || '');
const body = ref(props.initialTemplate?.body || '');
const header = ref(props.initialTemplate?.header || '');
const footer = ref(props.initialTemplate?.footer || '');
const mediaUrl = ref(props.initialTemplate?.media_url || '');
const mediaType = ref(props.initialTemplate?.media_type || 'none');
const category = ref(props.initialTemplate?.category || 'general');
const buttons = ref(props.initialTemplate?.buttons?.map(b => ({ ...b })) || []);

const CATEGORIES = [
  { value: 'general', label: 'Geral' },
  { value: 'cobranca', label: 'Cobranca' },
  { value: 'vendas', label: 'Vendas' },
  { value: 'suporte', label: 'Suporte' },
  { value: 'notificacao', label: 'Notificacao' },
  { value: 'marketing', label: 'Marketing' },
];

const validationErrors = computed(() => {
  const errors = [];
  if (!props.isEditMode && !name.value.trim()) errors.push('Nome e obrigatorio');
  if (!props.isEditMode && !/^[a-z0-9_]+$/.test(name.value)) errors.push('Nome: apenas letras minusculas, numeros e _');
  if (!body.value.trim()) errors.push('Corpo da mensagem e obrigatorio');
  if (mediaType.value !== 'none' && !mediaUrl.value.trim()) errors.push('URL da media e obrigatoria');
  if (mediaUrl.value && !mediaUrl.value.startsWith('http')) errors.push('URL da media deve comecar com http');
  for (const [idx, btn] of buttons.value.entries()) {
    if (!btn.text?.trim()) errors.push(`Botao ${idx + 1}: texto obrigatorio`);
  }
  return errors;
});

const isValid = computed(() => validationErrors.value.length === 0);

function addButton() {
  if (buttons.value.length >= 3) return;
  buttons.value.push({ type: 'text', text: '', url: '' });
}

function removeButton(idx) {
  buttons.value.splice(idx, 1);
}

function save() {
  if (!isValid.value) return;
  const payload = {
    body: body.value,
    header: header.value || undefined,
    footer: footer.value || undefined,
    media_url: mediaType.value !== 'none' ? mediaUrl.value : undefined,
    media_type: mediaType.value !== 'none' ? mediaType.value : undefined,
    category: category.value,
    language: 'pt_BR',
    buttons: buttons.value.length > 0 ? buttons.value : undefined,
  };
  if (!props.isEditMode) {
    payload.name = name.value;
  }
  emit('save', payload);
}

// Simple WhatsApp-style preview
const previewBody = computed(() => {
  return body.value
    .replace(/\*(.*?)\*/g, '<strong>$1</strong>')
    .replace(/_(.*?)_/g, '<em>$1</em>')
    .replace(/~(.*?)~/g, '<del>$1</del>')
    .replace(/\n/g, '<br>');
});
</script>

<template>
  <div class="flex gap-6">
    <!-- Editor -->
    <div class="flex-1 flex flex-col gap-4">
      <!-- Name (create only) -->
      <label v-if="!isEditMode" class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-11">Nome do template</span>
        <input
          v-model="name"
          type="text"
          placeholder="ex: lembrete_pagamento"
          class="px-3 py-2 border border-n-weak rounded-lg text-sm font-mono"
          pattern="[a-z0-9_]+"
        />
        <span class="text-xs text-n-slate-9">Apenas letras minusculas, numeros e _</span>
      </label>

      <!-- Category -->
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-11">Categoria</span>
        <select v-model="category" class="px-3 py-2 border border-n-weak rounded-lg text-sm">
          <option v-for="cat in CATEGORIES" :key="cat.value" :value="cat.value">
            {{ cat.label }}
          </option>
        </select>
      </label>

      <!-- Header (optional) -->
      <label class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-11">Header (opcional)</span>
        <input
          v-model="header"
          type="text"
          placeholder="Titulo da mensagem"
          class="px-3 py-2 border border-n-weak rounded-lg text-sm"
          maxlength="60"
        />
      </label>

      <!-- Body -->
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">
            Corpo da mensagem <span class="text-red-500">*</span>
          </span>
          <span class="text-xs text-n-slate-9">{{ body.length }} caracteres</span>
        </div>
        <textarea
          v-model="body"
          placeholder="Escreva o corpo da mensagem. Use *negrito*, _italico_, ~riscado~. Variaveis livres como {nome}, {valor}, etc."
          class="px-3 py-2 border border-n-weak rounded-lg text-sm min-h-[120px] resize-y"
        />
        <div class="flex items-center gap-2 text-xs text-n-slate-9">
          <span>*texto* = <strong>negrito</strong></span>
          <span>_texto_ = <em>italico</em></span>
          <span>~texto~ = <del>riscado</del></span>
        </div>
      </div>

      <!-- Footer (optional) -->
      <label class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">Rodape (opcional)</span>
          <span class="text-xs text-n-slate-9">{{ footer.length }}/60</span>
        </div>
        <input
          v-model="footer"
          type="text"
          placeholder="Texto do rodape"
          class="px-3 py-2 border border-n-weak rounded-lg text-sm"
          maxlength="60"
        />
      </label>

      <!-- Media (optional) -->
      <div class="flex flex-col gap-2">
        <span class="text-sm font-medium text-n-slate-11">Media (opcional)</span>
        <div class="flex gap-2">
          <select v-model="mediaType" class="px-3 py-2 border border-n-weak rounded-lg text-sm">
            <option value="none">Sem media</option>
            <option value="image">Imagem</option>
            <option value="video">Video</option>
            <option value="audio">Audio</option>
            <option value="document">Documento</option>
          </select>
          <input
            v-if="mediaType !== 'none'"
            v-model="mediaUrl"
            type="url"
            placeholder="https://exemplo.com/arquivo.jpg"
            class="flex-1 px-3 py-2 border border-n-weak rounded-lg text-sm"
          />
        </div>
      </div>

      <!-- Buttons (optional) -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-n-slate-11">Botoes (opcional)</span>
          <button
            v-if="buttons.length < 3"
            class="px-2 py-1 text-xs border border-n-weak rounded hover:bg-n-alpha-1"
            @click="addButton"
          >
            + Botao
          </button>
        </div>
        <div v-for="(btn, idx) in buttons" :key="idx" class="flex gap-2 items-center p-2 bg-n-alpha-1 rounded">
          <input
            v-model="btn.text"
            type="text"
            placeholder="Texto do botao"
            class="flex-1 px-2 py-1 border border-n-weak rounded text-sm"
            maxlength="25"
          />
          <input
            v-model="btn.url"
            type="url"
            placeholder="URL (opcional)"
            class="flex-1 px-2 py-1 border border-n-weak rounded text-sm"
          />
          <button class="text-red-500 hover:text-red-700 text-sm" @click="removeButton(idx)">x</button>
        </div>
      </div>

      <!-- Validation Errors -->
      <div v-if="validationErrors.length > 0" class="flex flex-col gap-1 p-3 bg-red-50 border border-red-200 rounded-lg">
        <span v-for="err in validationErrors" :key="err" class="text-xs text-red-600">{{ err }}</span>
      </div>

      <!-- Actions -->
      <div class="flex justify-end gap-2 pt-2 border-t border-n-weak">
        <button class="px-4 py-2 text-sm border border-n-weak rounded-lg" @click="emit('cancel')">
          Cancelar
        </button>
        <button
          class="px-4 py-2 text-sm font-medium text-white bg-n-brand rounded-lg disabled:opacity-50"
          :disabled="!isValid"
          @click="save"
        >
          {{ isEditMode ? 'Salvar alteracoes' : 'Criar template' }}
        </button>
      </div>
    </div>

    <!-- Live Preview -->
    <div class="w-80 shrink-0">
      <div class="sticky top-4">
        <span class="text-sm font-medium text-n-slate-11 mb-2 block">Preview</span>
        <div class="max-w-sm mx-auto">
          <div class="bg-[#e5ddd5] rounded-lg p-3">
            <div class="bg-white rounded-lg shadow-sm overflow-hidden">
              <!-- Media preview -->
              <div v-if="mediaType === 'image' && mediaUrl" class="h-32 bg-n-alpha-2 overflow-hidden">
                <img :src="mediaUrl" class="w-full h-full object-cover" @error="$event.target.style.display='none'" />
              </div>
              <div v-else-if="mediaType !== 'none' && mediaUrl" class="p-3 bg-n-alpha-2 flex items-center gap-2">
                <span class="text-xs text-n-slate-9">
                  {{ mediaType === 'video' ? 'Video' : mediaType === 'audio' ? 'Audio' : 'Documento' }}
                </span>
              </div>
              <!-- Header -->
              <div v-if="header" class="px-3 pt-3 font-bold text-sm text-n-slate-12">{{ header }}</div>
              <!-- Body -->
              <div v-if="body" class="px-3 py-2 text-sm text-n-slate-12 leading-relaxed" v-html="previewBody" />
              <!-- Footer -->
              <div v-if="footer" class="px-3 pb-2">
                <p class="text-xs text-n-slate-9">{{ footer }}</p>
              </div>
              <!-- Buttons -->
              <div v-if="buttons.length > 0" class="border-t border-n-weak">
                <div
                  v-for="(btn, idx) in buttons"
                  :key="idx"
                  class="flex items-center justify-center py-2 text-sm text-n-brand font-medium border-b border-n-weak last:border-b-0"
                >
                  <span v-if="btn.url" class="mr-1">link</span>
                  {{ btn.text }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
