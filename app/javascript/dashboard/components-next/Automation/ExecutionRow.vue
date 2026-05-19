<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ExecutionActionCard from './ExecutionActionCard.vue';
import {
  formatTriggerSummary,
  formatStatusLabel,
  STATUS_ICON_MAP,
} from 'dashboard/helper/automationFormatters';

const props = defineProps({
  run: { type: Object, required: true },
});

const { t } = useI18n();

const expanded = ref(false);
const toggle = () => {
  expanded.value = !expanded.value;
};

const statusIcon = computed(
  () =>
    STATUS_ICON_MAP[props.run.status] || {
      icon: 'i-lucide-circle',
      class: 'text-n-slate-9',
    }
);

const time = computed(() => {
  if (!props.run.triggered_at) return '—';
  return new Date(props.run.triggered_at).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
});

const triggerSummary = computed(() => formatTriggerSummary(props.run));

const actionsCount = computed(
  () => `${props.run.succeeded_actions ?? 0}/${props.run.total_actions ?? 0}`
);

const statusLabel = computed(() => formatStatusLabel(props.run.status, t));
</script>

<template>
  <div role="listitem">
    <button
      type="button"
      class="grid grid-cols-[100px_1fr_120px_80px_24px] gap-3 px-4 py-3 w-full text-left hover:bg-n-alpha-2 border-b border-n-weak items-center"
      :aria-expanded="expanded"
      :aria-controls="`run-expand-${run.id}`"
      @click="toggle"
    >
      <span class="text-body-main text-n-slate-12 tabular-nums">
        {{ time }}
      </span>
      <span class="text-body-main text-n-slate-11 truncate">
        {{ triggerSummary }}
      </span>
      <span class="inline-flex items-center gap-1">
        <Icon
          :icon="statusIcon.icon"
          class="size-4"
          :class="[statusIcon.class]"
          aria-hidden="true"
        />
        <span class="text-body-main">{{ statusLabel }}</span>
      </span>
      <span class="text-body-main text-n-slate-11 tabular-nums">
        {{ actionsCount }}
      </span>
      <Icon
        :icon="expanded ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
        class="size-4 text-n-slate-10"
        aria-hidden="true"
      />
    </button>
    <div
      v-if="expanded"
      :id="`run-expand-${run.id}`"
      class="px-4 py-3 space-y-2 bg-n-alpha-1"
    >
      <p v-if="run.error_summary" class="text-sm text-n-ruby-9 mb-1">
        {{ run.error_summary }}
      </p>
      <ExecutionActionCard
        v-for="entry in run.actions_log || []"
        :key="entry.action_index"
        :entry="entry"
      />
    </div>
  </div>
</template>
