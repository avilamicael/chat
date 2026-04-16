<script setup>
import { computed, ref, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store.js';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Draggable from 'vuedraggable';
import kanbanAPI from 'dashboard/api/kanban.js';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import KanbanColumnSettingsModal from './components/KanbanColumnSettingsModal.vue';
import FilterChipGroup from './components/FilterChipGroup.vue';

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

const allAgents = useMapGetter('agents/getAgents');
const allInboxes = useMapGetter('inboxes/getInboxes');
const allTeams = useMapGetter('teams/getTeams');

// Board form
const boardName = ref('');
const boardIsDefault = ref(false);
const isSavingBoard = ref(false);

// Column list (local copy for drag&drop)
const localColumns = ref([]);
watch(
  columns,
  cols => {
    localColumns.value = cols.map(c => ({ ...c }));
  },
  { immediate: true }
);

// Column settings modal
const columnSettingsModalId = ref(null);
const columnSettingsColumn = computed(() =>
  localColumns.value.find(c => c.id === columnSettingsModalId.value) || null
);

// Column editing
const editingColumnId = ref(null);
const editName = ref('');
const editColor = ref('');

const startEdit = col => {
  editingColumnId.value = col.id;
  editName.value = col.name;
  editColor.value = col.color || '#6B7280';
};
const cancelEdit = () => {
  editingColumnId.value = null;
};
const saveColumn = async col => {
  if (!editName.value.trim()) return;
  try {
    await kanbanAPI.updateColumn(boardId.value, col.id, {
      name: editName.value.trim(),
      color: editColor.value,
    });
    editingColumnId.value = null;
    await store.dispatch('kanban/fetchBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.SAVED_SUCCESS'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  }
};

// Column reorder (after drag)
const onColumnDragEnd = async () => {
  const reordered = localColumns.value.map((col, idx) => ({
    id: col.id,
    position: idx + 1,
  }));
  try {
    await kanbanAPI.reorderColumns(boardId.value, reordered);
    await store.dispatch('kanban/fetchBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.SAVED_SUCCESS'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  }
};

// New column form
const newColumnName = ref('');
const newColumnColor = ref('#6B7280');
const isAddingColumn = ref(false);

const addColumn = async () => {
  if (!newColumnName.value.trim()) return;
  isAddingColumn.value = true;
  try {
    await kanbanAPI.createColumn(boardId.value, {
      name: newColumnName.value.trim(),
      color: newColumnColor.value,
      position: localColumns.value.length + 1,
    });
    newColumnName.value = '';
    newColumnColor.value = '#6B7280';
    await store.dispatch('kanban/fetchBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.COLUMN_ADDED'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  } finally {
    isAddingColumn.value = false;
  }
};

const deletingColumnId = ref(null);
const requestDeleteColumn = col => {
  deletingColumnId.value = col.id;
};
const cancelDeleteColumn = () => {
  deletingColumnId.value = null;
};
const confirmDeleteColumn = async col => {
  try {
    await kanbanAPI.deleteColumn(boardId.value, col.id);
    await store.dispatch('kanban/fetchBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.COLUMN_DELETED'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  } finally {
    deletingColumnId.value = null;
  }
};

// Intake column
const intakeColumnId = ref(null);
const intakeColumnOptions = computed(() =>
  localColumns.value.map(c => ({ value: c.id, label: c.name }))
);

// Agents/Inboxes
const selectedAgentIds = ref([]);
const selectedInboxIds = ref([]);

const selectedTeamIds = ref([]);

// Filters group — collapsible with summary
const isFiltersOpen = ref(false);

const filterSummary = computed(() => {
  const parts = [];
  const agents = selectedAgentIds.value.length;
  const teams = selectedTeamIds.value.length;
  const inboxes = selectedInboxIds.value.length;
  if (agents) parts.push(t('KANBAN.SETTINGS.FILTER_SUMMARY_AGENTS', { count: agents }));
  if (teams) parts.push(t('KANBAN.SETTINGS.FILTER_SUMMARY_TEAMS', { count: teams }));
  if (inboxes) parts.push(t('KANBAN.SETTINGS.FILTER_SUMMARY_INBOXES', { count: inboxes }));
  return parts.join(' · ');
});

const addAgent = id => {
  if (!selectedAgentIds.value.includes(id)) {
    selectedAgentIds.value = [...selectedAgentIds.value, id];
    useAlert(t('KANBAN.SETTINGS.AGENT_ADDED'));
  }
};
const addTeam = id => {
  if (!selectedTeamIds.value.includes(id)) {
    selectedTeamIds.value = [...selectedTeamIds.value, id];
    useAlert(t('KANBAN.SETTINGS.TEAM_ADDED'));
  }
};
const addInbox = id => {
  if (!selectedInboxIds.value.includes(id)) {
    selectedInboxIds.value = [...selectedInboxIds.value, id];
    useAlert(t('KANBAN.SETTINGS.INBOX_ADDED'));
  }
};
const removeAgent = id => {
  selectedAgentIds.value = selectedAgentIds.value.filter(a => a !== id);
  useAlert(t('KANBAN.SETTINGS.AGENT_REMOVED'));
};
const removeTeam = id => {
  selectedTeamIds.value = selectedTeamIds.value.filter(tm => tm !== id);
  useAlert(t('KANBAN.SETTINGS.TEAM_REMOVED'));
};
const removeInbox = id => {
  selectedInboxIds.value = selectedInboxIds.value.filter(i => i !== id);
  useAlert(t('KANBAN.SETTINGS.INBOX_REMOVED'));
};

// Save board (name + default + agents + inboxes)
const saveBoard = async () => {
  if (!boardName.value.trim()) return;
  isSavingBoard.value = true;
  try {
    await store.dispatch('kanban/updateBoard', {
      boardId: boardId.value,
      name: boardName.value.trim(),
      is_default: boardIsDefault.value,
      filters: {
        agent_ids: selectedAgentIds.value,
        team_ids: selectedTeamIds.value,
        inbox_ids: selectedInboxIds.value,
        intake_column_id: intakeColumnId.value || null,
      },
    });
    useAlert(t('KANBAN.SETTINGS.SAVED_SUCCESS'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  } finally {
    isSavingBoard.value = false;
  }
};

// Delete funnel
const showDeleteConfirm = ref(false);
const isDeleting = ref(false);

const confirmDelete = async () => {
  isDeleting.value = true;
  try {
    await store.dispatch('kanban/deleteBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.DELETED_SUCCESS'));
    router.push(frontendURL(`accounts/${accountId.value}/kanban`));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  } finally {
    isDeleting.value = false;
  }
};

const loadBoard = async () => {
  if (!boardId.value) return;
  await store.dispatch('kanban/fetchBoard', boardId.value);
  boardName.value = board.value?.name || '';
  boardIsDefault.value = board.value?.is_default || false;
  selectedAgentIds.value = board.value?.filters?.agent_ids || [];
  selectedTeamIds.value = board.value?.filters?.team_ids || [];
  selectedInboxIds.value = board.value?.filters?.inbox_ids || [];
  intakeColumnId.value = board.value?.filters?.intake_column_id || null;
};

onMounted(async () => {
  await Promise.all([
    loadBoard(),
    store.dispatch('agents/get'),
    store.dispatch('inboxes/get'),
    store.dispatch('teams/get'),
  ]);
});

const goBack = () => {
  router.push(frontendURL(`accounts/${accountId.value}/kanban/boards/${boardId.value}`));
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
      <h1 class="flex-1 text-base font-semibold text-n-slate-12">
        {{ board?.name || t('KANBAN.BOARD.SETTINGS') }}
      </h1>
      <button
        class="flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 transition-colors disabled:opacity-60"
        :disabled="isSavingBoard"
        @click="saveBoard"
      >
        {{ t('KANBAN.SETTINGS.SAVE') }}
      </button>
    </div>

    <!-- Body -->
    <div class="flex-1 overflow-y-auto">
      <div class="flex flex-col gap-8 px-6 py-8 max-w-3xl mx-auto">

        <!-- ============ GROUP 1 — Geral (essencial) ============ -->
        <section class="flex flex-col gap-5 p-6 bg-n-solid-1 rounded-2xl border border-n-weak shadow-sm">
          <header class="flex flex-col gap-1">
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ t('KANBAN.SETTINGS.GENERAL_TITLE') }}
            </h2>
            <p class="text-xs text-n-slate-10">
              {{ t('KANBAN.SETTINGS.GENERAL_DESC') }}
            </p>
          </header>

          <div class="flex flex-col gap-1.5">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.BOARD_NAME') }}
            </label>
            <input
              v-model="boardName"
              type="text"
              class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
              :placeholder="t('KANBAN.BOARD.UNTITLED')"
            />
          </div>

          <div class="flex flex-col gap-2 p-3 rounded-lg bg-n-alpha-1 border border-n-weak">
            <label class="flex items-start gap-2.5 cursor-pointer">
              <input v-model="boardIsDefault" type="checkbox" class="mt-0.5 rounded" />
              <span class="flex flex-col gap-0.5">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.SETTINGS.SET_DEFAULT') }}
                </span>
                <span class="text-xs text-n-slate-10">
                  {{ t('KANBAN.SETTINGS.DEFAULT_HINT') }}
                </span>
              </span>
            </label>

            <div v-if="boardIsDefault && localColumns.length" class="flex flex-col gap-1.5 pt-3 mt-1 border-t border-n-weak">
              <label class="text-xs font-medium text-n-slate-11">
                {{ t('KANBAN.SETTINGS.INTAKE_COLUMN') }}
              </label>
              <p class="text-xs text-n-slate-10">{{ t('KANBAN.SETTINGS.INTAKE_COLUMN_HINT') }}</p>
              <ComboBox
                v-model="intakeColumnId"
                :options="intakeColumnOptions"
                :placeholder="t('KANBAN.SETTINGS.INTAKE_COLUMN_PLACEHOLDER')"
              />
            </div>
          </div>
        </section>

        <!-- ============ GROUP 2 — Etapas (essencial) ============ -->
        <section class="flex flex-col gap-5 p-6 bg-n-solid-1 rounded-2xl border border-n-weak shadow-sm">
          <header class="flex flex-col gap-1">
            <h2 class="text-base font-semibold text-n-slate-12">
              {{ t('KANBAN.SETTINGS.COLUMNS') }}
            </h2>
            <p class="text-xs text-n-slate-10">
              {{ t('KANBAN.SETTINGS.COLUMNS_DESC') }}
            </p>
          </header>

          <Draggable
            v-model="localColumns"
            item-key="id"
            handle=".drag-handle"
            :animation="150"
            ghost-class="opacity-30"
            class="flex flex-col gap-1.5"
            @end="onColumnDragEnd"
          >
            <template #item="{ element: col }">
              <div
                class="group flex items-center gap-2 px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 hover:border-n-slate-7 transition-colors"
              >
                <!-- Drag handle -->
                <button class="drag-handle cursor-grab text-n-slate-8 hover:text-n-slate-11 flex-shrink-0">
                  <Icon icon="i-lucide-grip-vertical" class="size-4" />
                </button>

                <!-- Delete confirm state -->
                <template v-if="deletingColumnId === col.id">
                  <span
                    class="w-3 h-3 rounded-full flex-shrink-0"
                    :style="{ backgroundColor: col.color || '#6B7280' }"
                  />
                  <span class="flex-1 text-sm text-n-slate-11 truncate">
                    {{ t('KANBAN.COLUMN.DELETE_CONFIRM_INLINE', { name: col.name }) }}
                  </span>
                  <button
                    class="px-2 py-1 text-xs font-medium rounded bg-n-ruby-9 text-white hover:bg-n-ruby-10"
                    @click="confirmDeleteColumn(col)"
                  >
                    {{ t('KANBAN.SETTINGS.DELETE_CONFIRM_BTN_SHORT') }}
                  </button>
                  <button
                    class="px-2 py-1 text-xs rounded border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
                    @click="cancelDeleteColumn"
                  >
                    {{ t('KANBAN.SETTINGS.CANCEL') }}
                  </button>
                </template>

                <!-- Editing state -->
                <template v-else-if="editingColumnId === col.id">
                  <input
                    v-model="editColor"
                    type="color"
                    class="w-7 h-7 rounded cursor-pointer border-0 p-0 flex-shrink-0"
                  />
                  <input
                    v-model="editName"
                    type="text"
                    class="flex-1 px-2 py-1 text-sm border rounded border-n-weak bg-n-solid-1 text-n-slate-12 focus:outline-none focus:border-n-brand"
                    @keyup.enter="saveColumn(col)"
                    @keyup.escape="cancelEdit"
                  />
                  <button
                    class="px-2 py-1 text-xs rounded bg-n-brand text-white hover:bg-n-brand/90"
                    @click="saveColumn(col)"
                  >
                    {{ t('KANBAN.SETTINGS.SAVE_COL') }}
                  </button>
                  <button
                    class="px-2 py-1 text-xs rounded border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
                    @click="cancelEdit"
                  >
                    {{ t('KANBAN.SETTINGS.CANCEL') }}
                  </button>
                </template>

                <!-- Display state -->
                <template v-else>
                  <span
                    class="w-3 h-3 rounded-full flex-shrink-0"
                    :style="{ backgroundColor: col.color || '#6B7280' }"
                  />
                  <span class="flex-1 text-sm text-n-slate-12">{{ col.name }}</span>
                  <span class="text-xs text-n-slate-9 mr-1">
                    {{ col.cards_count ?? 0 }}
                  </span>
                  <button
                    class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-slate-12 opacity-0 group-hover:opacity-100 transition-opacity"
                    :title="t('KANBAN.COLUMN.SETTINGS_TITLE')"
                    @click="columnSettingsModalId = col.id"
                  >
                    <Icon icon="i-lucide-sliders-horizontal" class="size-3.5" />
                  </button>
                  <button
                    class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-slate-12"
                    :title="t('KANBAN.COLUMN.RENAME')"
                    @click="startEdit(col)"
                  >
                    <Icon icon="i-lucide-pencil" class="size-3.5" />
                  </button>
                  <button
                    class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-ruby-10"
                    :title="t('KANBAN.COLUMN.DELETE')"
                    @click="requestDeleteColumn(col)"
                  >
                    <Icon icon="i-lucide-trash-2" class="size-3.5" />
                  </button>
                </template>
              </div>
            </template>
          </Draggable>

          <!-- Add column -->
          <div class="flex items-center gap-2 pt-3 border-t border-n-weak">
            <input
              v-model="newColumnColor"
              type="color"
              class="w-8 h-8 rounded cursor-pointer border-0 p-0 flex-shrink-0"
            />
            <input
              v-model="newColumnName"
              type="text"
              class="flex-1 px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
              :placeholder="t('KANBAN.COLUMN.ADD')"
              @keyup.enter="addColumn"
            />
            <button
              class="flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-60 flex-shrink-0"
              :disabled="isAddingColumn || !newColumnName.trim()"
              @click="addColumn"
            >
              <Icon icon="i-lucide-plus" class="size-4" />
              {{ t('KANBAN.COLUMN.ADD') }}
            </button>
          </div>
        </section>

        <!-- ============ GROUP 3 — Filtros (colapsável) ============ -->
        <section class="flex flex-col bg-n-solid-1 rounded-2xl border border-n-weak shadow-sm overflow-hidden">
          <button
            class="flex items-center gap-3 p-6 text-left hover:bg-n-alpha-1 transition-colors"
            @click="isFiltersOpen = !isFiltersOpen"
          >
            <div class="flex-1 flex flex-col gap-1">
              <h2 class="text-base font-semibold text-n-slate-12">
                {{ t('KANBAN.SETTINGS.FILTERS_TITLE') }}
              </h2>
              <p class="text-xs text-n-slate-10">
                <template v-if="filterSummary">
                  {{ filterSummary }}
                </template>
                <template v-else>
                  {{ t('KANBAN.SETTINGS.FILTERS_EMPTY') }}
                </template>
              </p>
            </div>
            <Icon
              :icon="isFiltersOpen ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
              class="size-4 text-n-slate-10 flex-shrink-0"
            />
          </button>

          <div v-if="isFiltersOpen" class="flex flex-col gap-6 px-6 pb-6 pt-1">
            <div
              v-if="!boardIsDefault"
              class="flex items-start gap-2 p-3 rounded-lg bg-n-amber-3 border border-n-amber-5"
            >
              <Icon icon="i-lucide-info" class="size-4 text-n-amber-11 flex-shrink-0 mt-0.5" />
              <p class="text-xs text-n-amber-12">
                {{ t('KANBAN.SETTINGS.FILTERS_INACTIVE_HINT') }}
              </p>
            </div>
            <FilterChipGroup
              :title="t('KANBAN.SETTINGS.AGENTS')"
              :hint="t('KANBAN.SETTINGS.AGENTS_HINT')"
              :items="allAgents"
              :selected-ids="selectedAgentIds"
              :add-placeholder="t('KANBAN.SETTINGS.ADD_AGENT')"
              :empty-label="t('KANBAN.SETTINGS.ALL_AGENTS_ACCESS')"
              @add="addAgent"
              @remove="removeAgent"
            />

            <FilterChipGroup
              :title="t('KANBAN.SETTINGS.TEAMS')"
              :hint="t('KANBAN.SETTINGS.TEAMS_HINT')"
              :items="allTeams"
              :selected-ids="selectedTeamIds"
              :add-placeholder="t('KANBAN.SETTINGS.ADD_TEAM')"
              :empty-label="t('KANBAN.SETTINGS.ALL_TEAMS_ACCESS')"
              @add="addTeam"
              @remove="removeTeam"
            />

            <FilterChipGroup
              :title="t('KANBAN.SETTINGS.INBOXES')"
              :hint="t('KANBAN.SETTINGS.INBOXES_HINT')"
              :items="allInboxes"
              :selected-ids="selectedInboxIds"
              :add-placeholder="t('KANBAN.SETTINGS.ADD_INBOX')"
              :empty-label="t('KANBAN.SETTINGS.ALL_INBOXES_ACCESS')"
              @add="addInbox"
              @remove="removeInbox"
            />
          </div>
        </section>

        <!-- ============ GROUP 4 — Zona de perigo ============ -->
        <section class="flex flex-col gap-4 p-6 bg-n-solid-1 rounded-2xl border border-n-weak shadow-sm">
          <header class="flex flex-col gap-1">
            <h2 class="text-base font-semibold text-n-ruby-11">
              {{ t('KANBAN.SETTINGS.DELETE_TITLE') }}
            </h2>
            <p class="text-xs text-n-slate-10">
              {{ t('KANBAN.SETTINGS.DELETE_WARNING') }}
            </p>
          </header>

          <div v-if="showDeleteConfirm" class="flex items-center gap-3">
            <span class="text-xs text-n-slate-10">
              {{ t('KANBAN.SETTINGS.DELETE_CONFIRM_PROMPT') }}
            </span>
            <button
              class="px-3 py-1.5 text-sm font-medium rounded-lg bg-n-ruby-9 text-white hover:bg-n-ruby-10 disabled:opacity-60"
              :disabled="isDeleting"
              @click="confirmDelete"
            >
              {{ t('KANBAN.SETTINGS.DELETE_CONFIRM_BTN') }}
            </button>
            <button
              class="px-3 py-1.5 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
              @click="showDeleteConfirm = false"
            >
              {{ t('KANBAN.SETTINGS.CANCEL') }}
            </button>
          </div>

          <button
            v-else
            class="flex items-center gap-2 self-start px-4 py-2 text-sm font-medium rounded-lg border border-n-ruby-7 text-n-ruby-11 hover:bg-n-ruby-3 transition-colors"
            @click="showDeleteConfirm = true"
          >
            <Icon icon="i-lucide-trash-2" class="size-4" />
            {{ t('KANBAN.SETTINGS.DELETE_BTN') }}
          </button>
        </section>

      </div>
    </div>
  </div>

  <KanbanColumnSettingsModal
    v-if="columnSettingsColumn"
    :column="columnSettingsColumn"
    :board-id="boardId"
    @close="columnSettingsModalId = null"
  />
</template>
