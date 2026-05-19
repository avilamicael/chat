<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { RouterLink } from 'vue-router';
import automationsAPI from 'dashboard/api/automation';
import ExecutionRow from './ExecutionRow.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  ruleId: { type: [Number, String], required: true },
  globalLinkVisible: { type: Boolean, default: true },
});

const { t } = useI18n();

const runs = ref([]);
const hasMore = ref(false);
const loading = ref(true);
const error = ref(null);

const fetchPage = async (beforeId = null) => {
  loading.value = true;
  error.value = null;
  try {
    const { data } = await automationsAPI.listRuns(props.ruleId, {
      before: beforeId,
      limit: 20,
    });
    const newRuns = data.payload || [];
    runs.value = beforeId ? [...runs.value, ...newRuns] : newRuns;
    hasMore.value = data.meta?.has_more === true;
  } catch (e) {
    error.value = e.message || 'load_failed';
  } finally {
    loading.value = false;
  }
};

const loadOlder = () => {
  const lastId = runs.value[runs.value.length - 1]?.id;
  if (lastId) fetchPage(lastId);
};

onMounted(() => fetchPage());
</script>

<template>
  <div class="space-y-1">
    <!-- Global history link (top, right-aligned) -->
    <div
      v-if="globalLinkVisible && runs.length > 0"
      class="flex justify-end pb-2"
    >
      <RouterLink
        :to="`/settings/automation/history?rule_id=${ruleId}`"
        class="text-sm text-n-brand hover:underline"
      >
        {{ t('AUTOMATION.RUNS.SEE_GLOBAL_HISTORY') }}
      </RouterLink>
    </div>

    <!-- Loading skeleton -->
    <div v-if="loading && runs.length === 0" class="space-y-2">
      <div
        v-for="i in 3"
        :key="i"
        class="h-10 bg-n-alpha-1 rounded animate-pulse"
      />
    </div>

    <!-- Error -->
    <div
      v-else-if="error"
      class="py-8 text-center text-body-main text-n-ruby-9"
    >
      {{ t('AUTOMATION.RUNS.LOAD_ERROR') }}
      <button
        type="button"
        class="ml-2 text-n-brand underline"
        @click="fetchPage()"
      >
        {{ t('AUTOMATION.RUNS.RETRY') }}
      </button>
    </div>

    <!-- Empty -->
    <div v-else-if="runs.length === 0" class="py-12 text-center">
      <Icon
        icon="i-lucide-history"
        class="size-8 text-n-slate-7 mx-auto"
        aria-hidden="true"
      />
      <p class="text-heading-3 text-n-slate-11 mt-2">
        {{ t('AUTOMATION.RUNS.EMPTY_TITLE') }}
      </p>
      <p class="text-body-main text-n-slate-9 mt-1">
        {{ t('AUTOMATION.RUNS.EMPTY_STATE') }}
      </p>
    </div>

    <!-- Table -->
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
