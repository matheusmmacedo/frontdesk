<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import KlaosMessagePrefixAPI from 'dashboard/api/klaosMessagePrefix';

const template = ref('');
const original = ref('');
const availableVariables = ref([]);
const examples = ref([]);
const loading = ref(false);
const saving = ref(false);

const previewName = 'Matheus Macedo';

const isDirty = computed(() => template.value !== original.value);

const renderPreview = tpl => {
  if (!tpl) return '(sem prefixo — comportamento padrão do Chatwoot)';
  const name = previewName;
  const first = name.split(/\s+/)[0] || '';
  return (
    tpl
      .replace(/\{NAME_UPPER\}/g, name.toUpperCase())
      .replace(/\{NAME\}/g, name)
      .replace(/\{FIRST_NAME_UPPER\}/g, first.toUpperCase())
      .replace(/\{FIRST_NAME\}/g, first)
      .replace(/\{DISPLAY_NAME_UPPER\}/g, name.toUpperCase())
      .replace(/\{DISPLAY_NAME\}/g, name) +
    'Oi, tudo bem? Posso te ajudar?'
  );
};

const livePreview = computed(() => renderPreview(template.value));

const load = async () => {
  loading.value = true;
  try {
    const { data } = await KlaosMessagePrefixAPI.get();
    template.value = data.template || '';
    original.value = template.value;
    availableVariables.value = data.available_variables || [];
    examples.value = data.examples || [];
  } catch (e) {
    useAlert('Erro ao carregar configuração do prefixo.');
  } finally {
    loading.value = false;
  }
};

const save = async () => {
  if (template.value.length > 200) {
    useAlert('Template muito longo (máximo 200 caracteres).');
    return;
  }
  saving.value = true;
  try {
    const { data } = await KlaosMessagePrefixAPI.update({
      template: template.value,
    });
    template.value = data.template || '';
    original.value = template.value;
    useAlert('Prefixo salvo com sucesso!');
  } catch (e) {
    useAlert(e?.response?.data?.error || 'Erro ao salvar.');
  } finally {
    saving.value = false;
  }
};

const useExample = exampleTemplate => {
  template.value = exampleTemplate;
};

onMounted(load);
</script>

<template>
  <div class="h-auto overflow-auto w-full p-4">
    <BaseSettingsHeader
      title="Prefixo em mensagens humanas"
      description="Quando um atendente responde uma conversa, o Chatwoot envia o texto exato que ele digitou — sem identificar quem está falando. Esta configuração permite prepender automaticamente um template com o nome do atendente, trazendo consistência com o padrão usado pelo bot (ex: *Atendente GUSTAVO*: Oi, tudo bem?)."
    />

    <div class="mt-6 max-w-4xl space-y-6">
      <!-- Template input -->
      <div class="p-4 rounded-xl border border-n-weak bg-n-alpha-1">
        <label class="block mb-2 text-sm font-medium text-n-slate-12">
          Template
        </label>
        <textarea
          v-model="template"
          placeholder="Ex: **Atendente {FIRST_NAME_UPPER}:**&#10;"
          :disabled="loading"
          maxlength="200"
          rows="3"
          class="w-full px-3 py-2 text-sm font-mono rounded-lg border border-n-weak bg-n-alpha-2 text-n-slate-12 focus:outline-none focus:border-n-brand whitespace-pre"
        />
        <p class="mt-2 text-xs text-n-slate-11">
          Quebra de linha (Enter) é aplicada literal no WhatsApp. Deixe vazio pra desativar. Máximo 200 caracteres.
        </p>
      </div>

      <!-- Live preview -->
      <div class="p-4 rounded-xl border border-n-weak bg-n-alpha-1">
        <div class="mb-2 text-sm font-medium text-n-slate-12">
          Preview (com nome "{{ previewName }}")
        </div>
        <div class="p-3 rounded-lg bg-n-solid-blue text-n-slate-12 text-sm font-mono whitespace-pre-wrap break-words">
          {{ livePreview }}
        </div>
        <p class="mt-2 text-xs text-n-slate-11">
          <b>Markdown padrão:</b> use <code class="px-1 rounded bg-n-alpha-2">**texto**</code> (DOIS asteriscos) pra <b>negrito</b> e <code class="px-1 rounded bg-n-alpha-2">_texto_</code> pra <i>itálico</i>. O Chatwoot converte automaticamente pro formato do WhatsApp no envio.
        </p>
        <p class="mt-1 text-xs text-n-amber-12">
          ⚠️ Um asterisco só (<code class="px-1 rounded bg-n-alpha-2">*texto*</code>) é interpretado como <i>itálico</i> em markdown — não como negrito. Use <code class="px-1 rounded bg-n-alpha-2">**...**</code>.
        </p>
      </div>

      <!-- Variables -->
      <div class="p-4 rounded-xl border border-n-weak bg-n-alpha-1">
        <div class="mb-3 text-sm font-medium text-n-slate-12">
          Variáveis disponíveis
        </div>
        <div class="space-y-2">
          <div
            v-for="v in availableVariables"
            :key="v.variable"
            class="flex items-start gap-3 text-sm"
          >
            <code class="px-2 py-0.5 rounded bg-n-alpha-2 text-n-slate-12 font-mono whitespace-nowrap shrink-0">
              {{ v.variable }}
            </code>
            <span class="text-n-slate-11 pt-0.5">{{ v.description }}</span>
          </div>
        </div>
      </div>

      <!-- Examples -->
      <div class="p-4 rounded-xl border border-n-weak bg-n-alpha-1">
        <div class="mb-3 text-sm font-medium text-n-slate-12">
          Exemplos (clique pra usar)
        </div>
        <div class="space-y-3">
          <div
            v-for="ex in examples"
            :key="ex.template"
            class="p-3 rounded-lg bg-n-alpha-2 cursor-pointer hover:bg-n-alpha-3 transition-colors"
            @click="useExample(ex.template)"
          >
            <div v-if="ex.note" class="text-xs text-n-amber-12 mb-2 italic">{{ ex.note }}</div>
            <div class="text-xs text-n-slate-11 mb-1">Template:</div>
            <code class="block text-sm font-mono text-n-slate-12 mb-2 whitespace-pre-wrap">{{ ex.template }}</code>
            <div class="text-xs text-n-slate-11 mb-1">Resulta em:</div>
            <div class="text-sm font-mono text-n-slate-12 whitespace-pre-wrap">{{ ex.preview }}</div>
          </div>
        </div>
      </div>

      <!-- Notas importantes -->
      <div class="p-4 rounded-xl border border-n-amber-7 bg-n-amber-2/20">
        <div class="mb-2 text-sm font-medium text-n-slate-12">
          Notas importantes
        </div>
        <ul class="space-y-1 text-sm text-n-slate-11 list-disc list-inside">
          <li>O prefixo é aplicado só em <b>mensagens outgoing de humanos</b> (não se aplica ao bot nem a notas privadas).</li>
          <li>Se a mensagem digitada já começa com o prefixo, não duplica.</li>
          <li>Cada conta tem seu próprio template — esta config afeta só a conta atual.</li>
          <li>Atendentes <b>não</b> precisam fazer nada — funciona automático.</li>
        </ul>
      </div>

      <!-- Save -->
      <div class="flex justify-end gap-2">
        <NextButton
          faded
          slate
          :disabled="!isDirty || saving"
          label="Descartar"
          @click="template = original"
        />
        <NextButton
          solid
          blue
          :disabled="!isDirty || saving || loading"
          :label="saving ? 'Salvando...' : 'Salvar'"
          @click="save"
        />
      </div>
    </div>
  </div>
</template>
