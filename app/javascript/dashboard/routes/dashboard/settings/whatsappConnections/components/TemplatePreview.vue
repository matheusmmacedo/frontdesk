<script setup>
import { computed } from 'vue';

const props = defineProps({
  template: { type: Object, default: () => ({}) },
  sampleValues: { type: Object, default: () => ({}) },
  mediaPreviewUrl: { type: String, default: '' },
});

const header = computed(() =>
  props.template.components?.find(c => c.type === 'HEADER')
);

const body = computed(() =>
  props.template.components?.find(c => c.type === 'BODY')
);

const footer = computed(() =>
  props.template.components?.find(c => c.type === 'FOOTER')
);

const buttons = computed(() => {
  const btn = props.template.components?.find(c => c.type === 'BUTTONS');
  return btn?.buttons || [];
});

function formatWhatsAppText(text) {
  if (!text) return '';
  let formatted = text
    .replace(/\*(.*?)\*/g, '<strong>$1</strong>')
    .replace(/_(.*?)_/g, '<em>$1</em>')
    .replace(/~(.*?)~/g, '<del>$1</del>')
    .replace(/```(.*?)```/g, '<code>$1</code>')
    .replace(/\n/g, '<br>');

  // Replace {{N}} with sample values or highlighted placeholders
  // sampleValues uses numeric keys (1, 2, 3) from bodyExamples
  formatted = formatted.replace(/\{\{(\d+)\}\}/g, (match, num) => {
    const val = props.sampleValues[num] || props.sampleValues[`body_${num}`] || props.sampleValues[String(num)];
    if (val) return `<span class="text-n-brand font-medium">${val}</span>`;
    return `<span class="bg-yellow-100 text-yellow-800 px-1 rounded text-xs font-mono">${match}</span>`;
  });

  return formatted;
}

function formatHeaderText(text) {
  if (!text) return '';
  let formatted = text.replace(/\{\{(\d+)\}\}/g, (match, num) => {
    const val = props.sampleValues[`header_${num}`];
    if (val) return `<span class="text-n-brand font-medium">${val}</span>`;
    return `<span class="bg-yellow-100 text-yellow-800 px-1 rounded text-xs font-mono">${match}</span>`;
  });
  return formatted;
}

const headerText = computed(() => {
  if (!header.value) return '';
  if (header.value.format === 'TEXT') return formatHeaderText(header.value.text);
  return '';
});

const bodyHtml = computed(() => formatWhatsAppText(body.value?.text));
const footerText = computed(() => footer.value?.text || '');
</script>

<template>
  <div class="max-w-sm mx-auto">
    <div class="bg-[#e5ddd5] rounded-lg p-3">
      <div class="bg-white rounded-lg shadow-sm overflow-hidden">
        <!-- Header -->
        <div v-if="header" class="px-3 pt-3">
          <div
            v-if="header.format === 'TEXT'"
            class="font-bold text-sm text-n-slate-12"
            v-html="headerText"
          />
          <div
            v-else-if="header.format === 'IMAGE'"
            class="bg-n-alpha-2 rounded h-32 flex items-center justify-center overflow-hidden"
          >
            <img v-if="mediaPreviewUrl" :src="mediaPreviewUrl" class="w-full h-full object-cover" />
            <span v-else class="text-n-slate-9 text-xs">Imagem</span>
          </div>
          <div
            v-else-if="header.format === 'VIDEO'"
            class="bg-n-alpha-2 rounded h-32 flex items-center justify-center"
          >
            <span class="text-n-slate-9 text-xs">🎬 Vídeo</span>
          </div>
          <div
            v-else-if="header.format === 'DOCUMENT'"
            class="bg-n-alpha-2 rounded p-3 flex items-center gap-2"
          >
            <span class="text-n-slate-9 text-xs">📄 Documento</span>
          </div>
        </div>

        <!-- Body -->
        <div
          v-if="body"
          class="px-3 py-2 text-sm text-n-slate-12 leading-relaxed"
          v-html="bodyHtml"
        />

        <!-- Footer -->
        <div v-if="footer" class="px-3 pb-2">
          <p class="text-xs text-n-slate-9">{{ footerText }}</p>
        </div>

        <!-- Buttons -->
        <div v-if="buttons.length > 0" class="border-t border-n-weak">
          <div
            v-for="(btn, idx) in buttons"
            :key="idx"
            class="flex items-center justify-center py-2 text-sm text-n-brand font-medium border-b border-n-weak last:border-b-0"
          >
            <span v-if="btn.type === 'URL'" class="mr-1">🔗</span>
            <span v-else-if="btn.type === 'PHONE_NUMBER'" class="mr-1">📞</span>
            <span v-else class="mr-1">↩️</span>
            {{ btn.text }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
