<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store.js';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import KanbanColumn from './components/KanbanColumn.vue';
import CreateTaskModal from './components/CreateTaskModal.vue';
import TaskDetailModal from './components/TaskDetailModal.vue';
import OutcomeReasonModal from './components/OutcomeReasonModal.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const accountId = computed(() => route.params.accountId);
const boardId = computed(() => route.params.boardId);

const board = computed(() => store.getters['kanban/boardById'](boardId.value));
const columns = computed(() =>
  store.getters['kanban/boardColumns'](Number(boardId.value))
);
const allCards = computed(() =>
  store.getters['kanban/boardCards'](Number(boardId.value))
);
const isLoading = computed(() => store.getters['kanban/uiFlags'].fetchingCards);

// Filters
const statusFilter = ref(null);
const agentFilter = ref(null);
const inboxFilter = ref(null);
const showCreateTask = ref(false);
const preselectedColumnId = ref(null);
const selectedCardId = ref(null);
const pendingOutcomeMove = ref(null);

const columnsRef = ref(null);
let isScrollDragging = false;
let scrollDragStartX = 0;
let scrollDragStartLeft = 0;

function onDragMove(e) {
  if (!isScrollDragging || !columnsRef.value) return;
  columnsRef.value.scrollLeft = scrollDragStartLeft - (e.clientX - scrollDragStartX);
}

function onDragEnd() {
  isScrollDragging = false;
  document.removeEventListener('mousemove', onDragMove);
  document.removeEventListener('mouseup', onDragEnd);
}

function onColumnsMousedown(e) {
  if (e.button !== 0) return;
  if (e.target.closest('button, a, input, [data-kanban-card]')) return;
  isScrollDragging = true;
  scrollDragStartX = e.clientX;
  scrollDragStartLeft = columnsRef.value?.scrollLeft ?? 0;
  document.addEventListener('mousemove', onDragMove);
  document.addEventListener('mouseup', onDragEnd);
}

function onColumnsWheel(e) {
  if (!columnsRef.value || e.deltaX !== 0) return;
  // Redirect vertical wheel to horizontal scroll only if not over a scrollable column body
  let el = e.target;
  while (el && el !== columnsRef.value) {
    const { overflowY } = window.getComputedStyle(el);
    if ((overflowY === 'auto' || overflowY === 'scroll') && el.scrollHeight > el.clientHeight) return;
    el = el.parentElement;
  }
  e.preventDefault();
  columnsRef.value.scrollLeft += e.deltaY;
}

// Always reflects the latest store data — no manual reload needed after updates.
const selectedCard = computed(() => {
  if (!selectedCardId.value) return null;
  return (
    store.getters['kanban/boardCards'](Number(boardId.value)).find(
      c => c.id === selectedCardId.value
    ) || null
  );
});

const inboxes = useMapGetter('inboxes/getInboxes');
const agents = useMapGetter('agents/getAgents');

const agentOptions = computed(() => [
  ...agents.value.map(a => ({ value: a.id, label: a.name })),
]);

const inboxOptions = computed(() => [
  ...inboxes.value.map(i => ({ value: i.id, label: i.name })),
]);

const filteredCards = computed(() => {
  return allCards.value.filter(card => {
    const conv = card.conversation;
    if (!conv) return true;
    if (statusFilter.value && conv.status !== statusFilter.value) return false;
    if (agentFilter.value && conv.meta?.assignee?.id !== Number(agentFilter.value))
      return false;
    if (inboxFilter.value && conv.inbox_id !== Number(inboxFilter.value))
      return false;
    return true;
  });
});

const toggleStatus = status => {
  statusFilter.value = statusFilter.value === status ? null : status;
};

const loadBoard = async () => {
  if (!boardId.value) return;
  await Promise.all([
    store.dispatch('kanban/fetchBoard', boardId.value),
    store.dispatch('kanban/fetchCards', boardId.value),
  ]);
};

onMounted(() => {
  loadBoard();
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
});
watch(boardId, loadBoard);

const goToSettings = () => {
  router.push(frontendURL(`accounts/${accountId.value}/kanban/boards/${boardId.value}/settings`));
};

const goToOverview = () => {
  router.push(frontendURL(`accounts/${accountId.value}/kanban`));
};

const openCreateTask = (columnId = null) => {
  preselectedColumnId.value = columnId;
  showCreateTask.value = true;
};

const onCardCreated = () => {
  // ADD_CARD mutation already updated the store; no full reload needed.
};

const openCardDetail = card => {
  selectedCardId.value = card.id;
};

const onOutcomeMovePending = moveData => {
  pendingOutcomeMove.value = moveData;
};

const confirmOutcomeMove = async reason => {
  const move = pendingOutcomeMove.value;
  pendingOutcomeMove.value = null;
  try {
    await store.dispatch('kanban/moveCard', {
      boardId: Number(boardId.value),
      cardId: move.card.id,
      columnId: move.targetColumnId,
      position: move.targetPosition,
      outcomeReason: reason || null,
    });
  } catch {
    // error already reverted by store
  }
};

const cancelOutcomeMove = () => {
  const move = pendingOutcomeMove.value;
  pendingOutcomeMove.value = null;
  store
    .dispatch('kanban/moveCard', {
      boardId: Number(boardId.value),
      cardId: move.card.id,
      columnId: move.sourceColumnId,
      position: move.sourcePosition,
    })
    .catch(() => {});
};
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden">
    <!-- Header -->
    <div
      class="flex items-center gap-2 px-4 py-2.5 border-b border-n-weak bg-n-solid-1 flex-shrink-0"
    >
      <!-- Left: back + name + count + status toggles -->
      <button
        class="flex items-center gap-1.5 text-n-slate-10 hover:text-n-slate-12"
        @click="goToOverview"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4" />
      </button>

      <span class="text-sm font-semibold text-n-slate-12">
        {{ board?.name || t('KANBAN.BOARD.LOADING') }}
      </span>
      <span class="text-xs bg-n-alpha-2 text-n-slate-10 px-1.5 py-0.5 rounded-full">
        {{ filteredCards.length }}
      </span>

      <button
        class="p-1.5 rounded transition-colors"
        :class="statusFilter === 'open' ? 'bg-n-brand/10 text-n-brand' : 'text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2'"
        :title="t('KANBAN.BOARD.FILTER_OPEN')"
        @click="toggleStatus('open')"
      >
        <Icon icon="i-lucide-circle-check" class="size-4" />
      </button>
      <button
        class="p-1.5 rounded transition-colors"
        :class="statusFilter === 'pending' ? 'bg-n-brand/10 text-n-brand' : 'text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2'"
        :title="t('KANBAN.BOARD.FILTER_PENDING')"
        @click="toggleStatus('pending')"
      >
        <Icon icon="i-lucide-clock" class="size-4" />
      </button>

      <div class="flex-1" />

      <!-- Right: ComboBox filters + icons + add task -->
      <div class="w-40">
        <ComboBox
          v-model="agentFilter"
          :options="agentOptions"
          :placeholder="t('KANBAN.BOARD.ALL_AGENTS')"
          :search-placeholder="t('KANBAN.BOARD.ALL_AGENTS')"
        />
      </div>

      <div class="w-40">
        <ComboBox
          v-model="inboxFilter"
          :options="inboxOptions"
          :placeholder="t('KANBAN.BOARD.ALL_INBOXES')"
          :search-placeholder="t('KANBAN.BOARD.ALL_INBOXES')"
        />
      </div>

      <button
        class="h-9 w-9 flex items-center justify-center rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2"
      >
        <Icon icon="i-lucide-arrow-up-down" class="size-4" />
      </button>

      <button
        class="h-9 w-9 flex items-center justify-center rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2"
        @click="goToSettings"
      >
        <Icon icon="i-lucide-settings" class="size-4" />
      </button>

      <button
        class="h-9 flex items-center gap-2 px-4 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 transition-colors flex-shrink-0"
        @click="openCreateTask()"
      >
        <Icon icon="i-lucide-plus" class="size-4" />
        {{ t('KANBAN.BOARD.ADD_TASK') }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="isLoading" class="flex-1 flex items-center justify-center">
      <span class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.LOADING') }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="columns.length === 0"
      class="flex-1 flex flex-col items-center justify-center gap-3"
    >
      <Icon icon="i-lucide-layout-kanban" class="size-10 text-n-slate-8" />
      <p class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.NO_COLUMNS') }}</p>
      <button class="text-sm text-n-brand hover:underline" @click="goToSettings">
        {{ t('KANBAN.BOARD.ADD_COLUMNS') }}
      </button>
    </div>

    <!-- Kanban columns -->
    <div
      ref="columnsRef"
      v-else
      class="flex-1 min-h-0 min-w-0 flex gap-3 p-4 overflow-x-auto select-none cursor-grab active:cursor-grabbing"
      @mousedown="onColumnsMousedown"
      @wheel="onColumnsWheel"
    >
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :board-id="boardId"
        :account-id="accountId"
        :filtered-cards="filteredCards"
        @add-card="openCreateTask"
        @open-card-detail="openCardDetail"
        @outcome-move-pending="onOutcomeMovePending"
      />
    </div>
  </div>

  <!-- Create Task Modal -->
  <CreateTaskModal
    v-if="showCreateTask"
    :board-id="boardId"
    :columns="columns"
    :preselected-column-id="preselectedColumnId"
    @close="showCreateTask = false"
    @created="onCardCreated"
  />

  <!-- Task Detail Modal -->
  <TaskDetailModal
    v-if="selectedCard"
    :card="selectedCard"
    :board-id="boardId"
    :account-id="accountId"
    :columns="columns"
    @close="selectedCardId = null"
    @deleted="selectedCardId = null"
  />

  <!-- Outcome Reason Modal -->
  <OutcomeReasonModal
    v-if="pendingOutcomeMove"
    :column-type="pendingOutcomeMove.columnType"
    :card-title="pendingOutcomeMove.card.title || `#${pendingOutcomeMove.card.conversation?.display_id}`"
    @confirm="confirmOutcomeMove"
    @cancel="cancelOutcomeMove"
  />
</template>
