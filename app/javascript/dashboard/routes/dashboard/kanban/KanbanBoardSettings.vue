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

const deleteColumn = async col => {
  if (!window.confirm(t('KANBAN.COLUMN.DELETE_CONFIRM'))) return;
  try {
    await kanbanAPI.deleteColumn(boardId.value, col.id);
    await store.dispatch('kanban/fetchBoard', boardId.value);
    useAlert(t('KANBAN.SETTINGS.COLUMN_DELETED'));
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
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

const selectedAgents = computed(() =>
  allAgents.value.filter(a => selectedAgentIds.value.includes(a.id))
);
const selectedInboxes = computed(() =>
  allInboxes.value.filter(i => selectedInboxIds.value.includes(i.id))
);
const availableAgents = computed(() =>
  allAgents.value.filter(a => !selectedAgentIds.value.includes(a.id))
);
const availableInboxes = computed(() =>
  allInboxes.value.filter(i => !selectedInboxIds.value.includes(i.id))
);

const selectedTeamIds = ref([]);

const selectedTeams = computed(() =>
  allTeams.value.filter(tm => selectedTeamIds.value.includes(tm.id))
);
const availableTeams = computed(() =>
  allTeams.value.filter(tm => !selectedTeamIds.value.includes(tm.id))
);

const addingAgentId = ref(null);
const addingInboxId = ref(null);
const addingTeamId = ref(null);

watch(addingAgentId, id => {
  if (id && !selectedAgentIds.value.includes(Number(id))) {
    selectedAgentIds.value = [...selectedAgentIds.value, Number(id)];
    useAlert(t('KANBAN.SETTINGS.AGENT_ADDED'));
  }
  addingAgentId.value = null;
});

watch(addingInboxId, id => {
  if (id && !selectedInboxIds.value.includes(Number(id))) {
    selectedInboxIds.value = [...selectedInboxIds.value, Number(id)];
    useAlert(t('KANBAN.SETTINGS.INBOX_ADDED'));
  }
  addingInboxId.value = null;
});

watch(addingTeamId, id => {
  if (id && !selectedTeamIds.value.includes(Number(id))) {
    selectedTeamIds.value = [...selectedTeamIds.value, Number(id)];
    useAlert(t('KANBAN.SETTINGS.TEAM_ADDED'));
  }
  addingTeamId.value = null;
});

const removeAgent = id => {
  selectedAgentIds.value = selectedAgentIds.value.filter(a => a !== id);
  useAlert(t('KANBAN.SETTINGS.AGENT_REMOVED'));
};

const removeInbox = id => {
  selectedInboxIds.value = selectedInboxIds.value.filter(i => i !== id);
  useAlert(t('KANBAN.SETTINGS.INBOX_REMOVED'));
};

const removeTeam = id => {
  selectedTeamIds.value = selectedTeamIds.value.filter(tm => tm !== id);
  useAlert(t('KANBAN.SETTINGS.TEAM_REMOVED'));
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
      <div class="flex flex-col gap-6 px-6 py-6 max-w-2xl">

        <!-- Board name + default -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-n-weak">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.BOARD_DETAILS') }}
          </h2>
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
          <label class="flex items-center gap-2 cursor-pointer">
            <input v-model="boardIsDefault" type="checkbox" class="rounded" />
            <span class="text-sm text-n-slate-12">
              {{ t('KANBAN.SETTINGS.SET_DEFAULT') }}
            </span>
          </label>
          <p class="text-xs text-n-slate-9 mt-0.5">
            {{ t('KANBAN.SETTINGS.DEFAULT_HINT') }}
          </p>
          <div v-if="localColumns.length" class="flex flex-col gap-1.5 pt-1 border-t border-n-weak">
            <label class="text-xs font-medium text-n-slate-11">
              {{ t('KANBAN.SETTINGS.INTAKE_COLUMN') }}
            </label>
            <p class="text-xs text-n-slate-9">{{ t('KANBAN.SETTINGS.INTAKE_COLUMN_HINT') }}</p>
            <ComboBox
              v-model="intakeColumnId"
              :options="intakeColumnOptions"
              :placeholder="t('KANBAN.SETTINGS.INTAKE_COLUMN_PLACEHOLDER')"
            />
          </div>
        </section>

        <!-- Columns -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-n-weak">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.COLUMNS') }}
          </h2>

          <Draggable
            v-model="localColumns"
            item-key="id"
            handle=".drag-handle"
            :animation="150"
            ghost-class="opacity-30"
            class="flex flex-col gap-1"
            @end="onColumnDragEnd"
          >
            <template #item="{ element: col }">
              <div
                class="flex items-center gap-2 px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2"
              >
                <!-- Drag handle -->
                <button class="drag-handle cursor-grab text-n-slate-8 hover:text-n-slate-11 flex-shrink-0">
                  <Icon icon="i-lucide-grip-vertical" class="size-4" />
                </button>

                <!-- Editing state -->
                <template v-if="editingColumnId === col.id">
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
                  <button
                    class="text-xs text-n-brand hover:underline flex-shrink-0"
                    @click="columnSettingsModalId = col.id"
                  >
                    {{ t('KANBAN.COLUMN.SETTINGS_TITLE') }}
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
                    class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-n-slate-12"
                    @click="startEdit(col)"
                  >
                    <Icon icon="i-lucide-pencil" class="size-3.5" />
                  </button>
                  <button
                    class="p-1 rounded hover:bg-n-alpha-2 text-n-slate-10 hover:text-red-500"
                    @click="deleteColumn(col)"
                  >
                    <Icon icon="i-lucide-trash-2" class="size-3.5" />
                  </button>
                </template>
              </div>
            </template>
          </Draggable>

          <!-- Add column -->
          <div class="flex items-center gap-2 pt-1 border-t border-n-weak">
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

        <!-- Agents -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-n-weak">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.AGENTS') }}
          </h2>
          <p class="text-xs text-n-slate-10 -mt-2">
            {{ t('KANBAN.SETTINGS.AGENTS_HINT') }}
          </p>

          <!-- Selected agent chips -->
          <div class="flex flex-wrap gap-2">
            <span
              v-for="agent in selectedAgents"
              :key="agent.id"
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs bg-n-alpha-2 text-n-slate-11 border border-n-weak"
            >
              {{ agent.name }}
              <button
                class="text-n-slate-9 hover:text-n-slate-12"
                @click="removeAgent(agent.id)"
              >
                <Icon icon="i-lucide-x" class="size-3" />
              </button>
            </span>

            <!-- Add agent dropdown -->
            <ComboBox
              v-if="availableAgents.length"
              v-model="addingAgentId"
              :options="availableAgents.map(a => ({ value: a.id, label: a.name }))"
              :placeholder="t('KANBAN.SETTINGS.ADD_AGENT')"
              :search-placeholder="t('KANBAN.SETTINGS.ADD_AGENT')"
            />
            <span v-else-if="!selectedAgents.length" class="text-xs text-n-slate-9 italic">
              {{ t('KANBAN.SETTINGS.ALL_AGENTS_ACCESS') }}
            </span>
          </div>
        </section>

        <!-- Teams -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-n-weak">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.TEAMS') }}
          </h2>
          <p class="text-xs text-n-slate-10 -mt-2">
            {{ t('KANBAN.SETTINGS.TEAMS_HINT') }}
          </p>

          <!-- Selected team chips -->
          <div class="flex flex-wrap gap-2">
            <span
              v-for="team in selectedTeams"
              :key="team.id"
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs bg-n-alpha-2 text-n-slate-11 border border-n-weak"
            >
              {{ team.name }}
              <button
                class="text-n-slate-9 hover:text-n-slate-12"
                @click="removeTeam(team.id)"
              >
                <Icon icon="i-lucide-x" class="size-3" />
              </button>
            </span>

            <!-- Add team dropdown -->
            <ComboBox
              v-if="availableTeams.length"
              v-model="addingTeamId"
              :options="availableTeams.map(tm => ({ value: tm.id, label: tm.name }))"
              :placeholder="t('KANBAN.SETTINGS.ADD_TEAM')"
              :search-placeholder="t('KANBAN.SETTINGS.ADD_TEAM')"
            />
            <span v-else-if="!selectedTeams.length" class="text-xs text-n-slate-9 italic">
              {{ t('KANBAN.SETTINGS.ALL_TEAMS_ACCESS') }}
            </span>
          </div>
        </section>

        <!-- Inboxes -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-n-weak">
          <h2 class="text-sm font-semibold text-n-slate-12">
            {{ t('KANBAN.SETTINGS.INBOXES') }}
          </h2>
          <p class="text-xs text-n-slate-10 -mt-2">
            {{ t('KANBAN.SETTINGS.INBOXES_HINT') }}
          </p>

          <!-- Selected inbox chips -->
          <div class="flex flex-wrap gap-2">
            <span
              v-for="inbox in selectedInboxes"
              :key="inbox.id"
              class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs bg-n-alpha-2 text-n-slate-11 border border-n-weak"
            >
              {{ inbox.name }}
              <button
                class="text-n-slate-9 hover:text-n-slate-12"
                @click="removeInbox(inbox.id)"
              >
                <Icon icon="i-lucide-x" class="size-3" />
              </button>
            </span>

            <!-- Add inbox dropdown -->
            <ComboBox
              v-if="availableInboxes.length"
              v-model="addingInboxId"
              :options="availableInboxes.map(i => ({ value: i.id, label: i.name }))"
              :placeholder="t('KANBAN.SETTINGS.ADD_INBOX')"
              :search-placeholder="t('KANBAN.SETTINGS.ADD_INBOX')"
            />
            <span v-else-if="!selectedInboxes.length" class="text-xs text-n-slate-9 italic">
              {{ t('KANBAN.SETTINGS.ALL_INBOXES_ACCESS') }}
            </span>
          </div>
        </section>

        <!-- Danger zone: delete funnel -->
        <section class="flex flex-col gap-4 p-5 bg-n-solid-1 rounded-xl border border-red-200 dark:border-red-900/40">
          <h2 class="text-sm font-semibold text-red-600 dark:text-red-400">
            {{ t('KANBAN.SETTINGS.DELETE_TITLE') }}
          </h2>
          <p class="text-xs text-n-slate-10">
            {{ t('KANBAN.SETTINGS.DELETE_WARNING') }}
          </p>

          <!-- Inline confirm -->
          <div v-if="showDeleteConfirm" class="flex items-center gap-3">
            <span class="text-xs text-n-slate-10">
              {{ t('KANBAN.SETTINGS.DELETE_CONFIRM_PROMPT') }}
            </span>
            <button
              class="px-3 py-1.5 text-sm font-medium rounded-lg bg-red-600 text-white hover:bg-red-700 disabled:opacity-60"
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
            class="flex items-center gap-2 self-start px-4 py-2 text-sm font-medium rounded-lg border border-red-300 dark:border-red-800 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
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
    @saved="loadBoard"
  />
</template>
