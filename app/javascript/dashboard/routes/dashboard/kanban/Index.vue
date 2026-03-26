<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { FEATURE_FLAGS } from 'dashboard/featureFlags.js';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Paywall from 'dashboard/components-next/Paywall.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CreateFunnelModal from './components/CreateFunnelModal.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const accountId = computed(() => route.params.accountId);

const isKanbanEnabled = computed(() =>
  store.getters['accounts/isFeatureEnabledonAccount'](
    accountId.value,
    FEATURE_FLAGS.KANBAN
  )
);

const boards = computed(() => store.getters['kanban/allBoards']);
const isLoadingBoards = computed(
  () => store.getters['kanban/uiFlags'].fetchingBoards
);
const hasBoardInRoute = computed(() => !!route.params.boardId);

const showCreateModal = ref(false);
const isCreating = ref(false);

const goToBoard = boardId => {
  router.push(frontendURL(`accounts/${accountId.value}/kanban/boards/${boardId}`));
};

const goToBoardSettings = (event, boardId) => {
  event.stopPropagation();
  router.push(frontendURL(`accounts/${accountId.value}/kanban/boards/${boardId}/settings`));
};

const createFunnel = async ({ name, template }) => {
  isCreating.value = true;
  try {
    const board = await store.dispatch('kanban/createBoard', { name, template });
    showCreateModal.value = false;
    useAlert(t('KANBAN.OVERVIEW.CREATED_SUCCESS'));
    goToBoard(board.id);
  } catch {
    useAlert(t('KANBAN.OVERVIEW.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

onMounted(async () => {
  if (!isKanbanEnabled.value) return;
  await store.dispatch('kanban/fetchBoards');
});
</script>

<template>
  <!-- Feature disabled — show paywall -->
  <Paywall
    v-if="!isKanbanEnabled"
    title-key="KANBAN.PAYWALL.TITLE"
    description-key="KANBAN.PAYWALL.DESCRIPTION"
    upgrade-prompt-key="KANBAN.PAYWALL.UPGRADE_PROMPT"
    feature="kanban"
  />

  <!-- Board view — render child route full-screen -->
  <router-view v-else-if="hasBoardInRoute" />

  <!-- Overview -->
  <div v-else class="flex flex-col w-full h-full overflow-hidden">
    <!-- Header -->
    <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak bg-n-solid-1 flex-shrink-0">
      <h1 class="text-base font-semibold text-n-slate-12">
        {{ t('KANBAN.OVERVIEW.TITLE') }}
      </h1>
      <div class="flex items-center gap-2">
        <button class="p-1.5 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2">
          <Icon icon="i-lucide-arrow-up-down" class="size-4" />
        </button>
        <button
          class="flex items-center gap-1.5 px-3 py-1.5 text-sm font-semibold rounded-lg bg-n-brand text-white hover:bg-n-brand/90"
          @click="showCreateModal = true"
        >
          <Icon icon="i-lucide-plus" class="size-4" />
          {{ t('KANBAN.OVERVIEW.ADD_FUNNEL') }}
        </button>
      </div>
    </div>

    <!-- Body -->
    <div class="flex-1 overflow-y-auto p-6">
      <!-- Loading -->
      <div v-if="isLoadingBoards" class="flex items-center justify-center h-32">
        <span class="text-sm text-n-slate-10">{{ t('KANBAN.BOARD.LOADING') }}</span>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="boards.length === 0"
        class="flex flex-col items-center justify-center gap-4 h-64"
      >
        <div class="p-4 rounded-2xl bg-n-alpha-2">
          <Icon icon="i-lucide-layout-kanban" class="size-10 text-n-slate-8" />
        </div>
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('KANBAN.OVERVIEW.EMPTY_TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-10">
          {{ t('KANBAN.OVERVIEW.EMPTY_DESCRIPTION') }}
        </p>
        <button
          class="flex items-center gap-2 px-4 py-2 text-sm rounded-lg bg-n-brand text-white hover:bg-n-brand/90"
          @click="showCreateModal = true"
        >
          <Icon icon="i-lucide-plus" class="size-4" />
          {{ t('KANBAN.OVERVIEW.ADD_FUNNEL') }}
        </button>
      </div>

      <!-- Funnel cards list -->
      <div v-else class="flex flex-col gap-3 max-w-3xl">
        <div
          v-for="board in boards"
          :key="board.id"
          class="flex flex-col gap-3 p-4 rounded-xl border border-n-weak bg-n-solid-1 hover:border-n-brand/40 cursor-pointer transition-colors"
          @click="goToBoard(board.id)"
        >
          <!-- Top row: name + count + settings -->
          <div class="flex items-center justify-between gap-2">
            <div class="flex items-center gap-2">
              <span class="text-sm font-semibold text-n-slate-12">{{ board.name }}</span>
              <span
                v-if="board.cards_total != null"
                class="text-xs bg-n-alpha-2 text-n-slate-10 px-1.5 py-0.5 rounded-full font-medium"
              >
                {{ board.cards_total }}
              </span>
              <span
                v-if="board.is_default"
                class="text-[10px] px-1.5 py-0.5 rounded-full bg-n-brand/10 text-n-brand font-medium"
              >
                {{ t('KANBAN.OVERVIEW.DEFAULT_BADGE') }}
              </span>
            </div>
            <button
              class="p-1 rounded text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 flex-shrink-0"
              @click="goToBoardSettings($event, board.id)"
            >
              <Icon icon="i-lucide-settings" class="size-4" />
            </button>
          </div>

          <!-- Stage pills -->
          <div v-if="board.columns?.length" class="flex flex-wrap gap-2">
            <span
              v-for="col in board.columns"
              :key="col.id"
              class="inline-flex items-center gap-1.5 text-xs text-n-slate-11"
            >
              <span
                class="w-2 h-2 rounded-full flex-shrink-0"
                :style="{ backgroundColor: col.color || '#6B7280' }"
              />
              {{ col.name }}
              <span class="text-n-slate-9 font-medium">{{ col.cards_count ?? 0 }}</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Create Funnel Modal -->
  <CreateFunnelModal
    v-if="showCreateModal"
    @close="showCreateModal = false"
    @create="createFunnel"
  />
</template>
