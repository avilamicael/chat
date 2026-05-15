<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store.js';
import { useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAlert } from 'dashboard/composables';
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
const { isAdmin } = useAdmin();

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

// Filters server-side (D-08: querystring efemera, sobrevive reload)
const toArray = value => {
  if (value === undefined || value === null || value === '') return [];
  return Array.isArray(value) ? value.slice() : [value];
};
const toScalar = value => {
  if (value === undefined || value === '') return null;
  if (Array.isArray(value)) return value[0] ?? null;
  return value;
};

const assigneeIds = ref(toArray(route.query.assignee_ids));
const teamIds = ref(toArray(route.query.team_ids));
const inboxIds = ref(toArray(route.query.inbox_ids));
const labelList = ref(toArray(route.query.label_list));
const priority = ref(toArray(route.query.priority));
const taskStatus = ref(toArray(route.query.task_status));
const q = ref(toScalar(route.query.q) || '');
const createdAtGte = ref(toScalar(route.query.created_at_gte));
const createdAtLte = ref(toScalar(route.query.created_at_lte));

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
  columnsRef.value.scrollLeft =
    scrollDragStartLeft - (e.clientX - scrollDragStartX);
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
    if (
      (overflowY === 'auto' || overflowY === 'scroll') &&
      el.scrollHeight > el.clientHeight
    )
      return;
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

// Backend ja filtra server-side; expoe allCards diretamente.
const filteredCards = computed(() => allCards.value);

// Selecionar un valor a partir do array; usado pelos ComboBox de agente/inbox.
const firstOrNull = arr => (arr.length > 0 ? arr[0] : null);

const agentFilter = computed({
  get: () => firstOrNull(assigneeIds.value),
  set: val => {
    assigneeIds.value = val == null || val === '' ? [] : [val];
  },
});

const inboxFilter = computed({
  get: () => firstOrNull(inboxIds.value),
  set: val => {
    inboxIds.value = val == null || val === '' ? [] : [val];
  },
});

const isTaskStatusActive = status => taskStatus.value.includes(status);

const toggleStatus = status => {
  if (isTaskStatusActive(status)) {
    taskStatus.value = taskStatus.value.filter(s => s !== status);
  } else {
    taskStatus.value = [...taskStatus.value, status];
  }
};

const filterParams = computed(() => ({
  assignee_ids: assigneeIds.value,
  team_ids: teamIds.value,
  inbox_ids: inboxIds.value,
  label_list: labelList.value,
  priority: priority.value,
  task_status: taskStatus.value,
  q: q.value || '',
  created_at_gte: createdAtGte.value || null,
  created_at_lte: createdAtLte.value || null,
}));

// Serializa filterParams para querystring (somente chaves nao-vazias).
const filterQueryObject = computed(() => {
  const out = {};
  const p = filterParams.value;
  if (p.assignee_ids.length) out.assignee_ids = p.assignee_ids.map(String);
  if (p.team_ids.length) out.team_ids = p.team_ids.map(String);
  if (p.inbox_ids.length) out.inbox_ids = p.inbox_ids.map(String);
  if (p.label_list.length) out.label_list = p.label_list.map(String);
  if (p.priority.length) out.priority = p.priority.map(String);
  if (p.task_status.length) out.task_status = p.task_status.map(String);
  if (p.q) out.q = p.q;
  if (p.created_at_gte) out.created_at_gte = p.created_at_gte;
  if (p.created_at_lte) out.created_at_lte = p.created_at_lte;
  return out;
});

const fetchWithFilters = async () => {
  if (!boardId.value) return;
  await store.dispatch('kanban/fetchCards', {
    boardId: boardId.value,
    ...filterParams.value,
  });
};

let pendingFetchHandle = null;
const scheduleFetch = (debounceMs = 0) => {
  if (pendingFetchHandle) clearTimeout(pendingFetchHandle);
  if (debounceMs === 0) {
    fetchWithFilters();
    return;
  }
  pendingFetchHandle = setTimeout(() => {
    pendingFetchHandle = null;
    fetchWithFilters();
  }, debounceMs);
};

// Watch filtros: sincroniza querystring + dispara fetch debounced (300ms para q,
// imediato para os demais).
watch(
  filterParams,
  () => {
    router.replace({ query: filterQueryObject.value }).catch(() => {});
    scheduleFetch(q.value ? 300 : 0);
  },
  { deep: true }
);

const loadBoard = async () => {
  if (!boardId.value) return;
  await Promise.all([
    store.dispatch('kanban/fetchBoard', boardId.value),
    fetchWithFilters(),
  ]);
};

onMounted(() => {
  loadBoard();
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
});
watch(boardId, loadBoard);

const goToSettings = () => {
  router.push(
    frontendURL(
      `accounts/${accountId.value}/kanban/boards/${boardId.value}/settings`
    )
  );
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
  } catch (e) {
    if (e?.code === 'KANBAN_CARD_STALE') {
      useAlert(t('KANBAN.CONFLICT_RELOAD'));
    }
    // other errors: silent — store already reverted optimistic move
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
      <span
        class="text-xs bg-n-alpha-2 text-n-slate-10 px-1.5 py-0.5 rounded-full"
      >
        {{ filteredCards.length }}
      </span>

      <button
        class="p-1.5 rounded transition-colors"
        :class="
          isTaskStatusActive('open')
            ? 'bg-n-brand/10 text-n-brand'
            : 'text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2'
        "
        :title="t('KANBAN.BOARD.FILTER_OPEN')"
        @click="toggleStatus('open')"
      >
        <Icon icon="i-lucide-circle-check" class="size-4" />
      </button>
      <button
        class="p-1.5 rounded transition-colors"
        :class="
          isTaskStatusActive('pending')
            ? 'bg-n-brand/10 text-n-brand'
            : 'text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2'
        "
        :title="t('KANBAN.BOARD.FILTER_PENDING')"
        @click="toggleStatus('pending')"
      >
        <Icon icon="i-lucide-clock" class="size-4" />
      </button>

      <div class="flex-1" />

      <!-- Search (q) -->
      <div class="relative w-48">
        <Icon
          icon="i-lucide-search"
          class="absolute left-2 top-1/2 -translate-y-1/2 size-3.5 text-n-slate-9 pointer-events-none"
        />
        <input
          v-model="q"
          type="search"
          :placeholder="t('KANBAN.FILTERS.SEARCH_PLACEHOLDER')"
          :aria-label="t('KANBAN.FILTERS.SEARCH_LABEL')"
          class="w-full h-9 pl-7 pr-2 text-sm rounded-lg bg-n-alpha-1 border border-n-weak text-n-slate-12 placeholder:text-n-slate-9 focus:outline-none focus:ring-1 focus:ring-n-brand"
        />
      </div>

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
        v-if="isAdmin"
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
      <span class="text-sm text-n-slate-10">{{
        t('KANBAN.BOARD.LOADING')
      }}</span>
    </div>

    <!-- Empty state -->
    <div
      v-else-if="columns.length === 0"
      class="flex-1 flex flex-col items-center justify-center gap-3"
    >
      <Icon icon="i-lucide-layout-kanban" class="size-10 text-n-slate-8" />
      <p class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.NO_COLUMNS') }}</p>
      <button
        v-if="isAdmin"
        class="text-sm text-n-brand hover:underline"
        @click="goToSettings"
      >
        {{ t('KANBAN.BOARD.ADD_COLUMNS') }}
      </button>
    </div>

    <!-- Kanban columns -->
    <div
      v-else
      ref="columnsRef"
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
    :card-title="
      pendingOutcomeMove.card.title ||
      `#${pendingOutcomeMove.card.conversation?.display_id}`
    "
    @confirm="confirmOutcomeMove"
    @cancel="cancelOutcomeMove"
  />
</template>
