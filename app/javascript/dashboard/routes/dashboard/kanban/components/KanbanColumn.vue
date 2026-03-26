<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store.js';
import { useRouter } from 'vue-router';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Draggable from 'vuedraggable';
import KanbanCard from './KanbanCard.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  column: { type: Object, required: true },
  boardId: { type: [String, Number], required: true },
  accountId: { type: [String, Number], required: true },
  filteredCards: { type: Array, default: null },
});

const emit = defineEmits(['add-card', 'open-card-detail']);

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const storeCards = computed(() =>
  store.getters['kanban/cardsByColumn'](Number(props.boardId), props.column.id)
);

const sourceCards = computed(() =>
  props.filteredCards !== null
    ? props.filteredCards
        .filter(c => c.kanban_column_id === props.column.id)
        .sort((a, b) => a.position - b.position)
    : storeCards.value
);

// Track card IDs in drag order — decoupled from card data.
// This is the ONLY thing that controls visual order.
const localCardIds = ref(sourceCards.value.map(c => c.id));

// Watch for cards entering or leaving this column (membership change only).
// Uses a sorted ID string as a stable key so data-only updates don't trigger this.
watch(
  () => sourceCards.value.map(c => c.id).sort().join(','),
  () => {
    const sourceIdSet = new Set(sourceCards.value.map(c => c.id));
    // Remove IDs that left the column
    const kept = localCardIds.value.filter(id => sourceIdSet.has(id));
    // Append any newly arrived cards (in their initial sorted order)
    const keptSet = new Set(kept);
    const added = sourceCards.value.filter(c => !keptSet.has(c.id)).map(c => c.id);
    localCardIds.value = [...kept, ...added];
  }
);

// Card data is always fresh from source — no stale copies.
const cardDataMap = computed(() =>
  Object.fromEntries(sourceCards.value.map(c => [c.id, c]))
);

// localCards: getter returns fresh data in drag order; setter lets vuedraggable update order.
const localCards = computed({
  get: () => localCardIds.value.map(id => cardDataMap.value[id]).filter(Boolean),
  set: newCards => {
    localCardIds.value = newCards.map(c => c.id);
  },
});

const computeFractionalPosition = (list, newIndex) => {
  const prev = list[newIndex - 1]?.position ?? 0;
  const nextCard = list[newIndex + 1];
  const next = nextCard !== undefined ? nextCard.position : prev + 2;
  return (prev + next) / 2;
};

const onDragChange = async event => {
  const moved = event.added || event.moved;
  if (!moved) return;
  const { element: card, newIndex } = moved;
  const position = computeFractionalPosition(localCards.value, newIndex);
  try {
    await store.dispatch('kanban/moveCard', {
      boardId: Number(props.boardId),
      cardId: card.id,
      columnId: props.column.id,
      position,
    });
  } catch {
    // Revert to source order on error
    localCardIds.value = sourceCards.value.map(c => c.id);
  }
};

const goToSettings = () => {
  router.push(frontendURL(`accounts/${props.accountId}/kanban/boards/${props.boardId}/settings`));
};
</script>

<template>
  <!-- Column card -->
  <div
    class="flex flex-col w-72 flex-shrink-0 rounded-xl overflow-hidden border border-n-weak self-stretch"
  >
    <!-- Colored header -->
    <div
      class="flex items-center justify-between px-3 py-2.5 flex-shrink-0"
      :style="{ backgroundColor: column.color || '#6B7280' }"
    >
      <div class="flex items-center gap-2">
        <span class="text-sm font-semibold text-white">{{ column.name }}</span>
        <span class="text-xs text-white bg-white/20 px-1.5 py-0.5 rounded font-medium">
          {{ localCards.length }}
        </span>
      </div>
      <div class="flex items-center gap-1">
        <button
          class="p-1 rounded text-white opacity-70 hover:opacity-100 hover:bg-white/10 transition-opacity"
          @click.stop="goToSettings"
        >
          <Icon icon="i-lucide-settings" class="size-3.5" />
        </button>
        <button
          class="p-1 rounded text-white opacity-70 hover:opacity-100 hover:bg-white/10 transition-opacity"
          @click.stop="emit('add-card', column.id)"
        >
          <Icon icon="i-lucide-plus" class="size-3.5" />
        </button>
      </div>
    </div>

    <!-- Column body -->
    <div class="flex-1 overflow-y-auto p-2 bg-n-solid-2 min-h-16 relative">
      <div
        v-if="localCards.length === 0"
        class="absolute inset-0 flex flex-col items-center justify-center gap-1.5 pointer-events-none"
      >
        <Icon icon="i-lucide-inbox" class="size-5 text-n-slate-7" />
        <span class="text-xs text-n-slate-8">{{ t('KANBAN.COLUMN.EMPTY') }}</span>
      </div>
      <Draggable
        v-model="localCards"
        group="kanban-cards"
        item-key="id"
        :animation="200"
        ghost-class="opacity-30"
        class="space-y-2 min-h-8 h-full"
        @change="onDragChange"
      >
        <template #item="{ element }">
          <KanbanCard
            :card="element"
            :account-id="accountId"
            @open-detail="emit('open-card-detail', $event)"
          />
        </template>
      </Draggable>
    </div>
  </div>
</template>
