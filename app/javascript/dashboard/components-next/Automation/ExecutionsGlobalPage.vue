<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import automationRuleRunsAPI from 'dashboard/api/automationRuleRuns';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import ExecutionRow from './ExecutionRow.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const route = useRoute();
const store = useStore();
const getters = useStoreGetters();

const filters = ref({
  rule_id: route.query.rule_id ? Number(route.query.rule_id) : '',
  status: '',
  period: '24h',
});

const runs = ref([]);
const loading = ref(true);
const hasMore = ref(false);

const automations = computed(
  () => getters['automations/getAutomations'].value || []
);

const ruleOptions = computed(() => [
  { value: '', label: t('AUTOMATION.GLOBAL_HISTORY.ALL_RULES') },
  ...automations.value.map(r => ({ value: r.id, label: r.name })),
]);

const statusOptions = computed(() => [
  { value: '', label: t('AUTOMATION.GLOBAL_HISTORY.ALL_STATUSES') },
  { value: 'ok', label: t('AUTOMATION.RUNS.STATUS_OK') },
  { value: 'error', label: t('AUTOMATION.RUNS.STATUS_ERROR') },
  { value: 'partial', label: t('AUTOMATION.RUNS.STATUS_PARTIAL') },
  { value: 'skipped', label: t('AUTOMATION.RUNS.STATUS_SKIPPED') },
  { value: 'aborted', label: t('AUTOMATION.RUNS.STATUS_ABORTED') },
]);

const periodOptions = computed(() => [
  { value: '24h', label: t('AUTOMATION.GLOBAL_HISTORY.PERIOD_24H') },
  { value: '7d', label: t('AUTOMATION.GLOBAL_HISTORY.PERIOD_7D') },
  { value: '30d', label: t('AUTOMATION.GLOBAL_HISTORY.PERIOD_30D') },
]);

const periodToFrom = period => {
  if (period === '24h') {
    return new Date(Date.now() - 24 * 3600 * 1000).toISOString();
  }
  if (period === '7d') {
    return new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString();
  }
  if (period === '30d') {
    return new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();
  }
  return null;
};

const fetchRuns = async (beforeId = null) => {
  loading.value = true;
  const params = {
    rule_id: filters.value.rule_id || undefined,
    status: filters.value.status || undefined,
    from: periodToFrom(filters.value.period),
    before: beforeId,
    limit: 20,
  };
  try {
    const { data } = await automationRuleRunsAPI.list(params);
    const newRuns = data.payload || [];
    runs.value = beforeId ? [...runs.value, ...newRuns] : newRuns;
    hasMore.value = data.meta?.has_more === true;
  } finally {
    loading.value = false;
  }
};

const loadOlder = () => {
  const lastId = runs.value[runs.value.length - 1]?.id;
  if (lastId) fetchRuns(lastId);
};

onMounted(() => {
  store.dispatch('automations/get');
  fetchRuns();
});

watch(
  filters,
  () => {
    fetchRuns();
  },
  { deep: true }
);
</script>

<template>
  <div class="px-6 py-4 space-y-4">
    <h1 class="text-heading-1 text-n-slate-12">
      {{ t('AUTOMATION.GLOBAL_HISTORY.TITLE') }}
    </h1>

    <div class="flex gap-3 items-end flex-wrap">
      <div>
        <label class="text-xs text-n-slate-10 block mb-1">
          {{ t('AUTOMATION.GLOBAL_HISTORY.FILTER_RULE') }}
        </label>
        <ComboBox
          v-model="filters.rule_id"
          :options="ruleOptions"
          :placeholder="t('AUTOMATION.GLOBAL_HISTORY.FILTER_RULE')"
        />
      </div>
      <div>
        <label class="text-xs text-n-slate-10 block mb-1">
          {{ t('AUTOMATION.GLOBAL_HISTORY.FILTER_STATUS') }}
        </label>
        <ComboBox
          v-model="filters.status"
          :options="statusOptions"
          :placeholder="t('AUTOMATION.GLOBAL_HISTORY.FILTER_STATUS')"
        />
      </div>
      <div>
        <label class="text-xs text-n-slate-10 block mb-1">
          {{ t('AUTOMATION.GLOBAL_HISTORY.FILTER_PERIOD') }}
        </label>
        <ComboBox
          v-model="filters.period"
          :options="periodOptions"
          :placeholder="t('AUTOMATION.GLOBAL_HISTORY.FILTER_PERIOD')"
        />
      </div>
    </div>

    <div v-if="loading && runs.length === 0" class="space-y-2">
      <div
        v-for="i in 3"
        :key="i"
        class="h-10 bg-n-alpha-1 rounded animate-pulse"
      />
    </div>
    <div v-else-if="runs.length === 0" class="py-12 text-center">
      <Icon
        icon="i-lucide-history"
        class="size-8 text-n-slate-7 mx-auto"
        aria-hidden="true"
      />
      <p class="text-heading-3 text-n-slate-11 mt-2">
        {{ t('AUTOMATION.GLOBAL_HISTORY.EMPTY_STATE') }}
      </p>
    </div>
    <div v-else>
      <div
        class="grid grid-cols-[100px_1fr_120px_80px_24px] gap-3 px-4 py-2 text-xs font-semibold uppercase tracking-wide text-n-slate-9"
      >
        <span>{{ t('AUTOMATION.RUNS.COLUMN_TIME') }}</span>
        <span>{{ t('AUTOMATION.RUNS.COLUMN_TRIGGER') }}</span>
        <span>{{ t('AUTOMATION.RUNS.COLUMN_STATUS') }}</span>
        <span>{{ t('AUTOMATION.RUNS.COLUMN_ACTIONS_COUNT') }}</span>
        <span aria-hidden="true" />
      </div>
      <div role="list">
        <ExecutionRow v-for="run in runs" :key="run.id" :run="run" />
      </div>
      <div v-if="hasMore" class="mt-3 flex justify-center">
        <button
          type="button"
          class="text-sm text-n-brand hover:underline disabled:opacity-50"
          :disabled="loading"
          @click="loadOlder"
        >
          {{
            loading
              ? t('AUTOMATION.RUNS.LOADING')
              : t('AUTOMATION.RUNS.LOAD_OLDER')
          }}
        </button>
      </div>
    </div>
  </div>
</template>
