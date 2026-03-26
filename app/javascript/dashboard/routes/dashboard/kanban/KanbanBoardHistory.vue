<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const accountId = computed(() => route.params.accountId);
const boardId = computed(() => route.params.boardId);

const board = computed(() => store.getters['kanban/boardById'](boardId.value));
const archivedCards = computed(() =>
  store.getters['kanban/archivedCardsByBoard'](Number(boardId.value))
);

const outcomeFilter = ref('all');

const filteredCards = computed(() => {
  if (outcomeFilter.value === 'all') return archivedCards.value;
  return archivedCards.value.filter(c => c.outcome === outcomeFilter.value);
});

const isLoading = ref(false);

const loadArchive = async () => {
  isLoading.value = true;
  try {
    await store.dispatch('kanban/fetchArchivedCards', { boardId: boardId.value });
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  if (!board.value) {
    store.dispatch('kanban/fetchBoard', boardId.value);
  }
  loadArchive();
});

const goBack = () => {
  router.push(frontendURL(`accounts/${accountId.value}/kanban/boards/${boardId.value}`));
};

const formatDate = dateStr => {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const setFilter = value => {
  outcomeFilter.value = value;
};
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden">
    <!-- Header -->
    <div
      class="flex items-center gap-3 px-6 py-3.5 border-b border-n-weak bg-n-solid-1 flex-shrink-0"
    >
      <button
        class="flex items-center justify-center w-8 h-8 rounded-lg hover:bg-n-alpha-2"
        @click="goBack"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4 text-n-slate-11" />
      </button>
      <div class="flex flex-col">
        <h1 class="text-base font-semibold text-n-slate-12">
          {{ t('KANBAN.HISTORY.TITLE') }}
        </h1>
        <span v-if="board?.name" class="text-xs text-n-slate-9">{{ board.name }}</span>
      </div>
      <div class="flex-1" />
      <button
        class="text-sm text-n-brand hover:underline"
        @click="goBack"
      >
        {{ t('KANBAN.ARCHIVE.BACK_TO_BOARD') }}
      </button>
    </div>

    <!-- Filter tabs -->
    <div class="flex items-center gap-1 px-6 pt-4 pb-2 flex-shrink-0">
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

    <!-- Loading -->
    <div v-if="isLoading" class="flex-1 flex items-center justify-center">
      <span class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="filteredCards.length === 0"
      class="flex-1 flex flex-col items-center justify-center gap-3"
    >
      <Icon icon="i-lucide-archive" class="size-10 text-n-slate-8" />
      <p class="text-sm text-n-slate-10">{{ t('KANBAN.HISTORY.EMPTY') }}</p>
    </div>

    <!-- Cards table -->
    <div v-else class="flex-1 overflow-y-auto px-6 py-4">
      <div class="flex flex-col gap-2">
        <!-- Table header -->
        <div class="grid grid-cols-5 gap-4 px-3 py-2 text-xs font-medium text-n-slate-9 uppercase tracking-wide">
          <span>{{ t('KANBAN.TASK.TITLE_LABEL') }}</span>
          <span>{{ t('KANBAN.TASK.ASSIGNEE_LABEL') }}</span>
          <span class="text-center">{{ t('KANBAN.OUTCOME.WON') }} / {{ t('KANBAN.OUTCOME.LOST') }}</span>
          <span>{{ t('KANBAN.ARCHIVE.REASON') }}</span>
          <span class="text-right">{{ t('KANBAN.ARCHIVE.ARCHIVED_AT') }}</span>
        </div>

        <!-- Card rows -->
        <div
          v-for="card in filteredCards"
          :key="card.id"
          class="grid grid-cols-5 gap-4 items-center px-3 py-3 rounded-lg border border-n-weak bg-n-solid-1 hover:bg-n-solid-2 transition-colors"
        >
          <!-- Title -->
          <span class="text-sm text-n-slate-12 truncate">
            {{ card.title || (card.conversation ? `#${card.conversation.display_id}` : t('KANBAN.CARD.NO_NAME')) }}
          </span>

          <!-- Assignee -->
          <span class="text-sm text-n-slate-10 truncate">
            {{ card.assignee?.name || t('KANBAN.CARD.UNASSIGNED') }}
          </span>

          <!-- Outcome badge -->
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

          <!-- Reason -->
          <span class="text-sm text-n-slate-10 truncate">
            {{ card.outcome_reason || '—' }}
          </span>

          <!-- Archived at -->
          <span class="text-sm text-n-slate-9 text-right">
            {{ formatDate(card.archived_at) }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
