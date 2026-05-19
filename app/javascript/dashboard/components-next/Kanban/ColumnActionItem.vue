<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  action: { type: Object, required: true },
  isEditing: { type: Boolean, default: false },
  isLegacy: { type: Boolean, default: false },
});

const emit = defineEmits(['edit', 'remove']);

const { t } = useI18n();

const ICON_MAP = {
  send_webhook_event: 'i-lucide-webhook',
  send_message: 'i-lucide-message-square',
};

const actionIcon = computed(
  () => ICON_MAP[props.action.action_name] || 'i-lucide-file-question'
);

const actionTypeLabel = computed(() => {
  if (props.action.action_name === 'send_webhook_event') {
    return t('KANBAN.COLUMN.ACTION_TYPE_WEBHOOK');
  }
  if (props.action.action_name === 'send_message') {
    return t('KANBAN.COLUMN.ACTION_TYPE_SEND_MESSAGE');
  }
  return props.action.action_name;
});

const summary = computed(() => {
  const params = props.action.action_params || {};
  if (props.action.action_name === 'send_webhook_event') {
    const method = params.method || 'POST';
    const url = params.url || '';
    return `${method} ${url}`.slice(0, 80);
  }
  if (props.action.action_name === 'send_message') {
    const content = Array.isArray(params) ? params[0] : params.content;
    return (content || '').slice(0, 80);
  }
  return '';
});
</script>

<template>
  <div
    class="outline outline-1 -outline-offset-1 rounded-xl px-4 py-3 flex items-center gap-3"
    :class="
      isEditing
        ? 'outline-2 outline-n-brand'
        : isLegacy
          ? 'outline-n-weak bg-n-alpha-1'
          : 'outline-n-weak'
    "
    role="listitem"
  >
    <Icon
      :icon="actionIcon"
      class="size-4 flex-shrink-0 text-n-slate-11"
      aria-hidden="true"
    />
    <div class="flex-1 min-w-0">
      <p class="text-heading-3 text-n-slate-12">
        {{ actionTypeLabel }}
      </p>
      <p class="text-label-small text-n-slate-11 truncate">
        {{ summary }}
      </p>
    </div>
    <button
      v-if="!isLegacy"
      type="button"
      class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-slate-11"
      :aria-label="t('KANBAN.COLUMN.ACTION_EDIT_ARIA')"
      :aria-expanded="isEditing"
      @click="emit('edit')"
    >
      <Icon icon="i-lucide-pencil" class="size-3.5" />
    </button>
    <button
      type="button"
      class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-ruby-9"
      :aria-label="t('KANBAN.COLUMN.ACTION_REMOVE_ARIA')"
      @click="emit('remove')"
    >
      <Icon icon="i-lucide-trash-2" class="size-3.5" />
    </button>
  </div>
</template>
