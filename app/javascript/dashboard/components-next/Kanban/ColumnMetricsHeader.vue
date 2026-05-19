<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { formatDwellTime } from 'dashboard/helper/kanbanFormatters';

const props = defineProps({
  count: { type: Number, required: true },
  avgDwellSeconds: { type: [Number, null], default: null },
  columnColor: { type: String, default: null },
});

const { t } = useI18n();

const formattedDwell = computed(() => formatDwellTime(props.avgDwellSeconds));

// UI-SPEC Open Q #8: quando column.color é null/cinza default, usar text-n-slate-11.
// Quando column tem cor (colored header), usar text-white/80 (contraste no fundo colorido).
const textClass = computed(() =>
  props.columnColor ? 'text-white/80' : 'text-n-slate-11'
);

const showEmptyTime = computed(
  () => formattedDwell.value === null || props.count === 0
);

const ariaLabelValue = computed(() =>
  showEmptyTime.value
    ? t('KANBAN.COLUMN_METRICS.EMPTY_TIME')
    : formattedDwell.value
);
</script>

<template>
  <span
    class="inline-flex items-center gap-2 text-xs tabular-nums"
    :class="textClass"
    :aria-label="
      t('KANBAN.COLUMN_METRICS.ARIA_LABEL', { value: ariaLabelValue })
    "
    :title="t('KANBAN.COLUMN_METRICS.TOOLTIP')"
  >
    <span>{{ t('KANBAN.COLUMN_METRICS.COUNT', { count }) }}</span>
    <span
      v-if="showEmptyTime"
      class="inline-flex items-center gap-1"
      aria-hidden="true"
    >
      <Icon icon="i-lucide-clock" class="size-3" />
      {{ t('KANBAN.COLUMN_METRICS.EMPTY_TIME') }}
    </span>
    <span v-else class="inline-flex items-center gap-1">
      <Icon icon="i-lucide-clock" class="size-3" aria-hidden="true" />
      {{ formattedDwell }}
    </span>
  </span>
</template>
