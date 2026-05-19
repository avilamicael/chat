<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: Object, default: () => ({}) },
  eventName: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const draft = ref({ ...props.modelValue });

// Open Q #3 — reset draft when eventName changes
watch(
  () => props.eventName,
  () => {
    draft.value = {};
    emit('update:modelValue', {});
  }
);

watch(
  draft,
  () => {
    emit('update:modelValue', { ...draft.value });
  },
  { deep: true }
);

const isKanbanEvent = computed(() =>
  (props.eventName || '').startsWith('kanban_card_')
);
const isKanbanMoved = computed(() => props.eventName === 'kanban_card_moved');
const isMessageEvent = computed(() => props.eventName === 'message_created');
const isConversationEvent = computed(() =>
  (props.eventName || '').startsWith('conversation_')
);
</script>

<template>
  <div class="space-y-3">
    <div v-if="isKanbanEvent">
      <label
        class="text-sm font-medium text-n-slate-12 block mb-1"
        for="manual-card-id"
      >
        {{ t('AUTOMATION.DRY_RUN.MANUAL_FIELD_CARD_ID') }}
      </label>
      <input
        id="manual-card-id"
        v-model.number="draft.card_id"
        type="number"
        class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 max-w-xs"
        :placeholder="t('AUTOMATION.DRY_RUN.MANUAL_FIELD_ID_PLACEHOLDER')"
      />
    </div>

    <div v-if="isKanbanMoved">
      <label
        class="text-sm font-medium text-n-slate-12 block mb-1"
        for="manual-target-col"
      >
        {{ t('AUTOMATION.DRY_RUN.MANUAL_FIELD_TARGET_COLUMN_ID') }}
      </label>
      <input
        id="manual-target-col"
        v-model.number="draft.target_column_id"
        type="number"
        class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 max-w-xs"
      />
      <label
        class="text-sm font-medium text-n-slate-12 block mt-3 mb-1"
        for="manual-source-col"
      >
        {{ t('AUTOMATION.DRY_RUN.MANUAL_FIELD_SOURCE_COLUMN_ID') }}
      </label>
      <input
        id="manual-source-col"
        v-model.number="draft.source_column_id"
        type="number"
        class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 max-w-xs"
      />
    </div>

    <div v-if="isMessageEvent || isConversationEvent">
      <label
        class="text-sm font-medium text-n-slate-12 block mb-1"
        for="manual-conversation-id"
      >
        {{ t('AUTOMATION.DRY_RUN.MANUAL_FIELD_CONVERSATION_ID') }}
      </label>
      <input
        id="manual-conversation-id"
        v-model.number="draft.conversation_id"
        type="number"
        class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 max-w-xs"
      />
    </div>

    <div v-if="isMessageEvent">
      <label
        class="text-sm font-medium text-n-slate-12 block mt-3 mb-1"
        for="manual-message-id"
      >
        {{ t('AUTOMATION.DRY_RUN.MANUAL_FIELD_MESSAGE_ID') }}
      </label>
      <input
        id="manual-message-id"
        v-model.number="draft.message_id"
        type="number"
        class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-1 max-w-xs"
      />
    </div>

    <p
      v-if="!isKanbanEvent && !isMessageEvent && !isConversationEvent"
      class="text-xs text-n-slate-9"
    >
      {{ t('AUTOMATION.DRY_RUN.MANUAL_NO_FIELDS') }}
    </p>
    <p class="text-xs text-n-slate-9 italic">
      {{ t('AUTOMATION.DRY_RUN.MANUAL_HINT_IDS') }}
    </p>
  </div>
</template>
