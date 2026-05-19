<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { messageStamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  status: {
    type: String,
    default: null,
    validator: v => v === null || ['ok', 'error', 'pending'].includes(v),
  },
  at: {
    type: [String, Number, Date],
    default: null,
  },
  error: {
    type: String,
    default: null,
  },
});

const { t } = useI18n();

const dotClass = computed(() => {
  if (props.status === 'ok') return 'bg-emerald-500';
  if (props.status === 'error') return 'bg-red-500';
  return 'bg-slate-400';
});

const timeLabel = computed(() => {
  if (!props.at) return t('AUTOMATION.STATUS.NO_EXECUTION');
  return messageStamp(new Date(props.at), 'LLL d, hh:mm a');
});

const truncatedError = computed(() => {
  if (!props.error) return '';
  return props.error.length > 200
    ? `${props.error.slice(0, 200)}...`
    : props.error;
});

const tooltipText = computed(() => {
  if (props.status === 'error' && truncatedError.value) {
    return truncatedError.value;
  }
  return '';
});
</script>

<template>
  <span v-tooltip.top="tooltipText" class="flex items-center gap-2">
    <span class="w-2 h-2 rounded-full flex-shrink-0" :class="dotClass" />
    <span class="text-body-small text-n-slate-11 whitespace-nowrap">
      {{ timeLabel }}
    </span>
  </span>
</template>
