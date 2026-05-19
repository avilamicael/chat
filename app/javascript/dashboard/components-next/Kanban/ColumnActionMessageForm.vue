<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  modelValue: { type: [Object, Array], required: true },
});

const emit = defineEmits(['update:modelValue', 'save', 'cancel']);

const { t } = useI18n();

const inboxes = useMapGetter('inboxes/getInboxes');
const inboxOptions = computed(() =>
  (inboxes.value || []).map(i => ({ value: i.id, label: i.name }))
);

const extractContent = source => {
  if (!source) return '';
  if (Array.isArray(source)) return source[0] || '';
  return source.content || '';
};

const extractInboxId = source => {
  if (!source || Array.isArray(source)) return null;
  return source.inbox_id || null;
};

const draft = reactive({
  content: extractContent(props.modelValue),
  inbox_id: extractInboxId(props.modelValue),
});

watch(
  draft,
  () => {
    emit('update:modelValue', {
      content: draft.content,
      inbox_id: draft.inbox_id,
    });
  },
  { deep: true }
);
</script>

<template>
  <div class="space-y-3 px-4 py-3 bg-n-alpha-1 rounded-lg mt-2">
    <div>
      <label class="text-heading-3 text-n-slate-12 block mb-1">
        {{ t('KANBAN.COLUMN.MESSAGE_SOURCE_INBOX_LABEL') }}
      </label>
      <ComboBox
        v-model="draft.inbox_id"
        :options="inboxOptions"
        :placeholder="t('KANBAN.COLUMN.MESSAGE_SOURCE_INBOX_PLACEHOLDER')"
      />
      <p class="text-label-small text-n-slate-11 mt-1">
        {{ t('KANBAN.COLUMN.MESSAGE_SOURCE_INBOX_HINT') }}
      </p>
    </div>
    <div>
      <label class="text-heading-3 text-n-slate-12 block mb-1">
        {{ t('KANBAN.COLUMN.MESSAGE_CONTENT_LABEL') }}
      </label>
      <TextArea
        v-model="draft.content"
        :max-length="2000"
        :placeholder="t('KANBAN.COLUMN.MESSAGE_CONTENT_PLACEHOLDER')"
      />
      <p class="text-label-small text-n-slate-11 mt-1">
        {{ t('KANBAN.COLUMN.MESSAGE_CONTENT_HINT') }}
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
