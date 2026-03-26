<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import ReportHeader from './components/ReportHeader.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import KanbanCardDetailModal from './KanbanCardDetailModal.vue';
import { useStore } from 'dashboard/composables/store.js';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper.js';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const accountId = computed(() => route.params.accountId);

const allBoards = useMapGetter('kanban/allBoards');

const selectedBoardId = ref(null);
const outcomeFilter = ref('all');
const isLoading = ref(false);

const archivedCards = computed(() => {
  if (!selectedBoardId.value) return [];
  return store.getters['kanban/archivedCardsByBoard'](selectedBoardId.value);
});

const filteredCards = computed(() => {
  if (outcomeFilter.value === 'all') return archivedCards.value;
  return archivedCards.value.filter(c => c.outcome === outcomeFilter.value);
});

const wonCount = computed(
  () => archivedCards.value.filter(c => c.outcome === 'won').length
);
const lostCount = computed(
  () => archivedCards.value.filter(c => c.outcome === 'lost').length
);
const total = computed(() => archivedCards.value.length);
const winRate = computed(() =>
  total.value > 0 ? Math.round((wonCount.value / total.value) * 100) : 0
);

const pipelineDaysLabel = card => {
  if (!card.archived_at || !card.created_at) return '—';
  const days = Math.round(
    (new Date(card.archived_at) - new Date(card.created_at)) / (1000 * 60 * 60 * 24)
  );
  if (days === 1) return `1 ${t('KANBAN.REPORTS.COLUMNS.DAY')}`;
  return `${days} ${t('KANBAN.REPORTS.COLUMNS.DAYS')}`;
};

const loadArchive = async boardId => {
  if (!boardId) return;
  isLoading.value = true;
  try {
    await store.dispatch('kanban/fetchArchivedCards', { boardId });
  } finally {
    isLoading.value = false;
  }
};

const onBoardChange = event => {
  const id = Number(event.target.value);
  selectedBoardId.value = id || null;
  if (id) loadArchive(id);
};

const setFilter = value => {
  outcomeFilter.value = value;
};

const selectedCard = ref(null);
const openCard = card => { selectedCard.value = card; };
const closeCard = () => { selectedCard.value = null; };

const formatDate = dateStr => {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const priorityClasses = {
  urgent: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
  high: 'bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400',
  medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
  low: 'bg-n-alpha-2 text-n-slate-10',
};

const priorityIcon = {
  urgent: 'i-lucide-zap',
  high: 'i-lucide-alert-triangle',
  medium: 'i-lucide-minus',
  low: 'i-lucide-minus',
};

onMounted(async () => {
  if (!allBoards.value.length) {
    await store.dispatch('kanban/fetchBoards');
  }
  if (allBoards.value.length) {
    selectedBoardId.value = allBoards.value[0].id;
    loadArchive(selectedBoardId.value);
  }
});
</script>

<template>
  <div class="flex flex-col px-6 pb-8">
    <ReportHeader
      :header-title="t('KANBAN.REPORTS.TITLE')"
      :header-description="t('KANBAN.REPORTS.DESCRIPTION')"
    />

    <div class="flex flex-wrap items-center gap-3 mb-4">
      <select
        class="px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :value="selectedBoardId"
        @change="onBoardChange"
      >
        <option value="">{{ t('KANBAN.REPORTS.SELECT_BOARD') }}</option>
        <option v-for="board in allBoards" :key="board.id" :value="board.id">
          {{ board.name }}
        </option>
      </select>

      <div class="flex items-center gap-1">
        <button
          v-for="tab in [
            { value: 'all', label: t('KANBAN.HISTORY.FILTER.ALL') },
            { value: 'won', label: t('KANBAN.HISTORY.FILTER.WON') },
            { value: 'lost', label: t('KANBAN.HISTORY.FILTER.LOST') },
          ]"
          :key="tab.value"
          class="px-3 py-1.5 text-sm rounded-lg transition-colors"
          :class="
            outcomeFilter === tab.value
              ? 'bg-n-brand text-white font-medium'
              : 'text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2'
          "
          @click="setFilter(tab.value)"
        >
          {{ tab.label }}
        </button>
      </div>
    </div>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mt-4">
      <div class="border border-n-weak rounded-xl p-4 bg-n-solid-1">
        <p class="text-3xl font-bold text-n-slate-12">{{ total }}</p>
        <p class="text-sm text-n-slate-10 mt-1">
          {{ t('KANBAN.REPORTS.METRICS.TOTAL') }}
        </p>
      </div>
      <div class="border border-green-200 rounded-xl p-4 bg-green-50 dark:bg-green-900/20 dark:border-green-800">
        <p class="text-3xl font-bold text-green-700 dark:text-green-400">{{ wonCount }}</p>
        <p class="text-sm text-green-700 dark:text-green-500 mt-1">
          {{ t('KANBAN.REPORTS.METRICS.WON') }}
        </p>
      </div>
      <div class="border border-red-200 rounded-xl p-4 bg-red-50 dark:bg-red-900/20 dark:border-red-800">
        <p class="text-3xl font-bold text-red-700 dark:text-red-400">{{ lostCount }}</p>
        <p class="text-sm text-red-700 dark:text-red-500 mt-1">
          {{ t('KANBAN.REPORTS.METRICS.LOST') }}
        </p>
      </div>
      <div class="border border-n-weak rounded-xl p-4 bg-n-solid-1">
        <p class="text-3xl font-bold text-n-slate-12">{{ winRate }}%</p>
        <p class="text-sm text-n-slate-10 mt-1">
          {{ t('KANBAN.REPORTS.METRICS.WIN_RATE') }}
        </p>
      </div>
    </div>

    <div v-if="total > 0" class="mt-4">
      <div class="w-full h-2.5 rounded-full bg-n-alpha-3 overflow-hidden">
        <div
          class="h-full rounded-full bg-green-500 transition-all duration-500"
          :style="{ width: `${winRate}%` }"
        />
      </div>
    </div>

    <div v-if="isLoading" class="flex items-center justify-center py-16">
      <span class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.LOADING') }}</span>
    </div>

    <div
      v-else-if="!isLoading && filteredCards.length === 0"
      class="flex flex-col items-center justify-center gap-3 py-16"
    >
      <Icon icon="i-lucide-archive" class="size-10 text-n-slate-8" />
      <p class="text-sm text-n-slate-10">{{ t('KANBAN.HISTORY.EMPTY') }}</p>
    </div>

    <div v-else class="mt-6 flex flex-col gap-2">
      <div class="grid grid-cols-7 gap-3 px-3 py-2 text-xs font-medium text-n-slate-9 uppercase tracking-wide">
        <span>{{ t('KANBAN.REPORTS.COLUMNS.CARD') }}</span>
        <span>{{ t('KANBAN.REPORTS.COLUMNS.PRIORITY') }}</span>
        <span>{{ t('KANBAN.REPORTS.COLUMNS.ASSIGNEES') }}</span>
        <span>{{ t('KANBAN.REPORTS.COLUMNS.TEAM') }}</span>
        <span class="text-center">{{ t('KANBAN.OUTCOME.WON') }} / {{ t('KANBAN.OUTCOME.LOST') }}</span>
        <span>{{ t('KANBAN.ARCHIVE.REASON') }}</span>
        <span class="text-right">{{ t('KANBAN.REPORTS.COLUMNS.TIME_IN_PIPELINE') }}</span>
      </div>

      <div
        v-for="card in filteredCards"
        :key="card.id"
        class="grid grid-cols-7 gap-3 items-center px-3 py-3 rounded-lg border border-n-weak bg-n-solid-1 hover:bg-n-solid-2 transition-colors cursor-pointer"
        @click="openCard(card)"
      >
        <div class="flex flex-col min-w-0">
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{
              card.title ||
              (card.conversation
                ? `#${card.conversation.display_id}`
                : t('KANBAN.CARD.NO_NAME'))
            }}
          </span>
          <span
            v-if="card.conversation?.meta?.sender?.name"
            class="text-xs text-n-slate-9 truncate mt-0.5"
          >
            {{ card.conversation.meta.sender.name }}
          </span>
          <a
            v-if="card.conversation"
            :href="frontendURL(`accounts/${accountId}/conversations/${card.conversation.id}`)"
            target="_blank"
            class="mt-1 inline-flex items-center gap-1 text-xs text-n-brand hover:underline"
            @click.stop
          >
            <Icon icon="i-lucide-external-link" class="size-3" />
            #{{ card.conversation.display_id }}
          </a>
        </div>

        <div>
          <span
            v-if="card.priority"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium"
            :class="priorityClasses[card.priority]"
          >
            <Icon :icon="priorityIcon[card.priority]" class="size-3" />
            {{ card.priority.charAt(0).toUpperCase() + card.priority.slice(1) }}
          </span>
          <span v-else class="text-xs text-n-slate-8">—</span>
        </div>

        <span class="text-sm text-n-slate-10 truncate">
          {{
            card.assignees.length
              ? card.assignees.map(a => a.name).join(', ')
              : t('KANBAN.CARD.UNASSIGNED')
          }}
        </span>

        <span class="text-sm text-n-slate-10 truncate">
          {{ card.teams.length ? card.teams[0].name : '—' }}
        </span>

        <div class="flex justify-center">
          <span
            v-if="card.outcome === 'won'"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
          >
            <Icon icon="i-lucide-trophy" class="size-3" />
            {{ t('KANBAN.OUTCOME.WON') }}
          </span>
          <span
            v-else-if="card.outcome === 'lost'"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"
          >
            <Icon icon="i-lucide-x-circle" class="size-3" />
            {{ t('KANBAN.OUTCOME.LOST') }}
          </span>
          <span v-else class="text-xs text-n-slate-8">—</span>
        </div>

        <span class="text-sm text-n-slate-9 truncate">
          {{ card.outcome_reason || '—' }}
        </span>

        <div class="flex flex-col items-end">
          <span class="text-sm font-medium text-n-slate-11">
            {{ pipelineDaysLabel(card) }}
          </span>
          <span class="text-xs text-n-slate-9 mt-0.5">
            {{ formatDate(card.archived_at) }}
          </span>
        </div>
      </div>
    </div>

    <KanbanCardDetailModal
      v-if="selectedCard"
      :card="selectedCard"
      :account-id="accountId"
      @close="closeCard"
    />
  </div>
</template>
