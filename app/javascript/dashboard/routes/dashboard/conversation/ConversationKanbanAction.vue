<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const store = useStore();

const boards = useMapGetter('kanban/allBoards');
const isLoading = ref(true);
const currentCard = ref(null); // { card_id, board_id, board_name, column_id, column_name, columns[] }
const selectedColumnId = ref(null);

// For "add to board" mode
const isAdding = ref(false);
const selectedBoardId = ref(null);
const selectedColumnForAdd = ref(null);

const isInBoard = computed(() => !!currentCard.value);

const columnOptions = computed(() =>
  (currentCard.value?.columns || []).map(c => ({ value: c.id, label: c.name }))
);

const boardOptions = computed(() =>
  boards.value.map(b => ({ value: b.id, label: b.name }))
);

const addColumnOptions = computed(() => {
  if (!selectedBoardId.value) return [];
  const cols = store.getters['kanban/boardColumns'](Number(selectedBoardId.value));
  return cols.map(c => ({ value: c.id, label: c.name }));
});

const canAdd = computed(() => selectedBoardId.value && selectedColumnForAdd.value);

const loadData = async () => {
  isLoading.value = true;
  try {
    if (boards.value.length === 0) {
      await store.dispatch('kanban/fetchBoards');
    }
    const card = await store.dispatch('kanban/fetchConversationCard', props.conversationId);
    currentCard.value = card;
    if (card) {
      selectedColumnId.value = card.column_id;
      // Load cards for this board into store for real-time updates
      store.dispatch('kanban/fetchCards', card.board_id);
    }
  } finally {
    isLoading.value = false;
  }
};

// Real-time: when store cards change for the current board, update selectedColumnId
const boardCards = computed(() => {
  if (!currentCard.value) return null;
  return store.getters['kanban/boardCards'](currentCard.value.board_id);
});

watch(boardCards, cards => {
  if (!currentCard.value || !cards) return;
  const updated = cards.find(c => c.id === currentCard.value.card_id);
  if (updated && updated.kanban_column_id !== selectedColumnId.value) {
    selectedColumnId.value = updated.kanban_column_id;
  }
});

watch(selectedBoardId, async val => {
  selectedColumnForAdd.value = null;
  if (val) await store.dispatch('kanban/fetchBoard', val);
});

onMounted(loadData);

const moveColumn = async newColumnId => {
  if (!currentCard.value || newColumnId === selectedColumnId.value) return;
  try {
    await store.dispatch('kanban/updateCard', {
      boardId: currentCard.value.board_id,
      cardId: currentCard.value.card_id,
      kanban_column_id: newColumnId,
    });
    selectedColumnId.value = newColumnId;
    const col = currentCard.value.columns.find(c => c.id === newColumnId);
    if (col) currentCard.value = { ...currentCard.value, column_id: newColumnId, column_name: col.name };
    useAlert(t('KANBAN.CONVERSATION_ACTION.MOVED_SUCCESS'));
  } catch {
    useAlert(t('KANBAN.CONVERSATION_ACTION.ADD_ERROR'));
  }
};

const addToFunnel = async () => {
  if (!canAdd.value || isAdding.value) return;
  isAdding.value = true;
  try {
    await store.dispatch('kanban/addCard', {
      boardId: Number(selectedBoardId.value),
      column_id: Number(selectedColumnForAdd.value),
      conversation_id: props.conversationId,
    });
    useAlert(t('KANBAN.CONVERSATION_ACTION.ADDED_SUCCESS'));
    selectedBoardId.value = null;
    selectedColumnForAdd.value = null;
  } catch {
    useAlert(t('KANBAN.CONVERSATION_ACTION.ADD_ERROR'));
  } finally {
    isAdding.value = false;
    loadData();
  }
};
</script>

<template>
  <div class="space-y-1.5 mt-1">
    <!-- Loading state -->
    <div v-if="isLoading" class="flex items-center gap-1.5 text-xs text-n-slate-9 py-1">
      <Icon icon="i-lucide-loader-circle" class="size-3.5 animate-spin" />
      <span>{{ t('KANBAN.CONVERSATION_ACTION.LOADING') }}</span>
    </div>

    <!-- Already in a board: show current status + column changer -->
    <template v-else-if="isInBoard">
      <div class="flex items-center gap-1.5 text-xs text-n-slate-10 py-0.5">
        <Icon icon="i-lucide-layout-kanban" class="size-3.5 flex-shrink-0" />
        <span class="font-medium text-n-slate-11 truncate">{{ currentCard.board_name }}</span>
      </div>
      <ComboBox
        v-model="selectedColumnId"
        :options="columnOptions"
        :placeholder="t('KANBAN.CONVERSATION_ACTION.SELECT_COLUMN')"
        @update:model-value="moveColumn"
      />
    </template>

    <!-- Not in any board: show add UI -->
    <template v-else>
      <ComboBox
        v-model="selectedBoardId"
        :options="boardOptions"
        :placeholder="t('KANBAN.CONVERSATION_ACTION.SELECT_FUNNEL')"
      />
      <ComboBox
        v-if="selectedBoardId"
        v-model="selectedColumnForAdd"
        :options="addColumnOptions"
        :placeholder="t('KANBAN.CONVERSATION_ACTION.SELECT_COLUMN')"
      />
      <button
        v-if="selectedBoardId && selectedColumnForAdd"
        class="w-full h-8 flex items-center justify-center gap-1.5 text-xs font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50 transition-colors"
        :disabled="!canAdd || isAdding"
        @click="addToFunnel"
      >
        <Icon icon="i-lucide-plus" class="size-3.5" />
        {{ isAdding ? '...' : t('KANBAN.CONVERSATION_ACTION.ADD_BTN') }}
      </button>
    </template>
  </div>
</template>
