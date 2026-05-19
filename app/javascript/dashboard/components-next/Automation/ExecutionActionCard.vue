<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  formatActionResolved,
  STATUS_ICON_MAP,
  SUB_STATUS_ICON_MAP,
} from 'dashboard/helper/automationFormatters';

const props = defineProps({
  entry: { type: Object, required: true },
});

const { t } = useI18n();

const iconConf = computed(
  () =>
    SUB_STATUS_ICON_MAP[props.entry.status] ||
    STATUS_ICON_MAP[props.entry.status] || {
      icon: 'i-lucide-circle',
      class: 'text-n-slate-9',
    }
);

const summary = computed(() => formatActionResolved(props.entry));

const subStatusText = computed(() => {
  if (props.entry.status === 'queued') {
    return t('AUTOMATION.RUNS.ACTION_QUEUED');
  }
  if (props.entry.status === 'blocked_24h') {
    return t('AUTOMATION.RUNS.ACTION_BLOCKED_24H');
  }
  if (props.entry.status === 'not_executed') {
    return t('AUTOMATION.RUNS.ACTION_NOT_EXECUTED');
  }
  return '';
});

const resolvedPayload = computed(
  () => props.entry.resolved_params || props.entry.payload_resolved || null
);

const resolvedPayloadJson = computed(() => {
  if (!resolvedPayload.value) return '';
  return JSON.stringify(resolvedPayload.value, null, 2);
});
</script>

<template>
  <div class="outline outline-1 outline-n-weak rounded-lg p-3 bg-n-solid-2">
    <div class="flex items-start gap-2">
      <Icon
        :icon="iconConf.icon"
        class="size-4 mt-0.5"
        :class="[iconConf.class]"
        aria-hidden="true"
      />
      <div class="flex-1 min-w-0">
        <p class="text-heading-3 text-n-slate-12">{{ entry.type }}</p>
        <p v-if="summary" class="text-body-main text-n-slate-11 truncate">
          {{ summary }}
        </p>
        <p v-if="subStatusText" class="text-xs text-n-slate-9 mt-1">
          {{ subStatusText }}
        </p>
        <p v-if="entry.error" class="text-xs text-n-ruby-9 mt-1">
          {{ entry.error }}
        </p>
        <details v-if="resolvedPayload" class="mt-2">
          <summary class="text-xs text-n-brand cursor-pointer">
            {{ t('AUTOMATION.RUNS.RESOLVED_VALUES_TOGGLE') }}
          </summary>
          <pre
            class="text-xs font-mono mt-1 p-2 bg-n-alpha-1 rounded overflow-x-auto whitespace-pre-wrap"
          ><code>{{ resolvedPayloadJson }}</code></pre>
        </details>
      </div>
      <span
        v-if="entry.duration_ms"
        class="text-xs text-n-slate-9 tabular-nums"
      >
        {{ `${entry.duration_ms}ms` }}
      </span>
    </div>
  </div>
</template>
