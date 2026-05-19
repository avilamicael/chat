<script setup>
import { reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: Object, required: true },
});

const emit = defineEmits(['update:modelValue', 'save', 'cancel']);

const { t } = useI18n();

const HTTP_METHODS = ['POST', 'PUT'];

const headersToArray = headers => {
  if (!headers || typeof headers !== 'object') return [];
  return Object.entries(headers).map(([key, value]) => ({ key, value }));
};

const draft = reactive({
  url: props.modelValue.url || '',
  method: props.modelValue.method || 'POST',
  headers: headersToArray(props.modelValue.headers),
  body: props.modelValue.body || '',
});

watch(
  draft,
  () => {
    const headersObj = Object.fromEntries(
      draft.headers
        .filter(h => h.key && h.key.trim())
        .map(h => [h.key.trim(), h.value])
    );
    emit('update:modelValue', {
      url: draft.url,
      method: draft.method,
      headers: headersObj,
      body: draft.body,
    });
  },
  { deep: true }
);

const addHeader = () => draft.headers.push({ key: '', value: '' });
const removeHeader = idx => draft.headers.splice(idx, 1);
</script>

<template>
  <div class="space-y-3 px-4 py-3 bg-n-alpha-1 rounded-lg mt-2">
    <div>
      <label class="text-heading-3 text-n-slate-12 block mb-1">
        {{ t('KANBAN.COLUMN.WEBHOOK_URL_LABEL') }}
      </label>
      <Input
        v-model="draft.url"
        type="url"
        placeholder="https://api.example.com/hook"
      />
    </div>
    <div>
      <label
        for="kanban-action-webhook-method"
        class="text-heading-3 text-n-slate-12 block mb-1"
      >
        {{ t('KANBAN.COLUMN.WEBHOOK_METHOD_LABEL') }}
      </label>
      <select
        id="kanban-action-webhook-method"
        v-model="draft.method"
        class="w-32 h-10 px-3 py-2 rounded-lg outline outline-1 -outline-offset-1 outline-n-weak bg-n-alpha-black2 text-n-slate-12 text-sm"
      >
        <option v-for="m in HTTP_METHODS" :key="m" :value="m">
          {{ m }}
        </option>
      </select>
    </div>
    <div>
      <label class="text-heading-3 text-n-slate-12 block mb-1">
        {{ t('KANBAN.COLUMN.WEBHOOK_HEADERS_LABEL') }}
      </label>
      <div
        v-for="(h, idx) in draft.headers"
        :key="idx"
        class="flex gap-2 mb-1 items-center"
      >
        <Input
          v-model="h.key"
          placeholder="X-Custom-Header"
          custom-input-class="flex-1"
        />
        <Input
          v-model="h.value"
          placeholder="value or {{secret}}"
          custom-input-class="flex-1"
        />
        <button
          type="button"
          class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-ruby-9"
          :aria-label="t('KANBAN.COLUMN.ACTION_REMOVE_HEADER_ARIA')"
          @click="removeHeader(idx)"
        >
          <Icon icon="i-lucide-x" class="size-3.5" />
        </button>
      </div>
      <button
        type="button"
        class="text-label-small text-n-brand hover:underline"
        @click="addHeader"
      >
        {{ t('KANBAN.COLUMN.WEBHOOK_ADD_HEADER') }}
      </button>
    </div>
    <div>
      <label class="text-heading-3 text-n-slate-12 block mb-1">
        {{ t('KANBAN.COLUMN.WEBHOOK_BODY_LABEL') }}
      </label>
      <TextArea
        v-model="draft.body"
        :max-length="4000"
        custom-text-area-class="font-mono text-xs"
        :placeholder="t('KANBAN.COLUMN.WEBHOOK_BODY_PLACEHOLDER')"
      />
      <p class="text-label-small text-n-slate-11 mt-1">
        {{ t('KANBAN.COLUMN.WEBHOOK_BODY_HINT') }}
      </p>
    </div>
    <div class="flex justify-end gap-2 pt-2">
      <button
        type="button"
        class="px-3 py-1.5 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak text-n-slate-11 hover:bg-n-alpha-2"
        @click="emit('cancel')"
      >
        {{ t('KANBAN.COLUMN.ACTION_CANCEL') }}
      </button>
      <button
        type="button"
        class="px-3 py-1.5 text-sm rounded-lg bg-n-brand text-white hover:bg-n-brand/90"
        @click="emit('save')"
      >
        {{ t('KANBAN.COLUMN.ACTION_SAVE') }}
      </button>
    </div>
  </div>
</template>
