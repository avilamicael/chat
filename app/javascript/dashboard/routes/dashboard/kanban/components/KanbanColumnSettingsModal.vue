<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import AutoAssignmentEditor from 'dashboard/components-next/Kanban/AutoAssignmentEditor.vue';
import ColumnActionsEditor from 'dashboard/components-next/Kanban/ColumnActionsEditor.vue';

const props = defineProps({
  column: { type: Object, required: true },
  boardId: { type: [String, Number], required: true },
});

const emit = defineEmits(['close', 'saved']);

const { t } = useI18n();
const store = useStore();

const agents = useMapGetter('agents/getAgents');
const teams = useMapGetter('teams/getTeams');

const agentOptions = computed(() =>
  agents.value.map(a => ({ value: a.id, label: a.name }))
);

const teamOptions = computed(() =>
  teams.value.map(tm => ({ value: tm.id, label: tm.name }))
);

// Split incoming actions into General-tab-managed ones (auto_resolve,
// assign_agent, assign_team) and the rest (Actions tab — webhook/message).
const splitActions = (actions = []) => {
  const general = {
    auto_resolve: false,
    assign_agent: false,
    agent_id: null,
    assign_team: false,
    team_id: null,
  };
  const remaining = [];
  (actions || []).forEach(action => {
    if (!action || !action.action_name) return;
    switch (action.action_name) {
      case 'auto_resolve':
        general.auto_resolve = true;
        break;
      case 'assign_agent':
        general.assign_agent = true;
        general.agent_id =
          action.agent_id || action.action_params?.agent_id || null;
        break;
      case 'assign_team':
        general.assign_team = true;
        general.team_id =
          action.team_id || action.action_params?.team_id || null;
        break;
      default:
        remaining.push(action);
    }
  });
  return { general, remaining };
};

// Rebuild the General-tab actions back into jsonb entries
const buildGeneralActions = general => {
  const arr = [];
  if (general.auto_resolve) arr.push({ action_name: 'auto_resolve' });
  if (general.assign_agent && general.agent_id) {
    arr.push({ action_name: 'assign_agent', agent_id: general.agent_id });
  }
  if (general.assign_team && general.team_id) {
    arr.push({ action_name: 'assign_team', team_id: general.team_id });
  }
  return arr;
};

// Initial split
const enterSplit = splitActions(props.column.enter_actions);
const exitSplit = splitActions(props.column.exit_actions);

const enterGeneral = ref(enterSplit.general);
// exit_actions historically never carried assign_agent/team/auto_resolve in the legacy modal,
// but we preserve the split for correctness if backend ever does.
const exitGeneral = ref(exitSplit.general);

const enterActions = ref(enterSplit.remaining);
const exitActions = ref(exitSplit.remaining);

const isSaving = ref(false);

const columnType = ref(props.column.column_type || 'normal');
const isWon = computed({
  get: () => columnType.value === 'won',
  set: val => {
    columnType.value = val ? 'won' : 'normal';
  },
});
const isLost = computed({
  get: () => columnType.value === 'lost',
  set: val => {
    columnType.value = val ? 'lost' : 'normal';
  },
});

const conversationStatus = ref(props.column.conversation_status || null);
const conversationStatusOptions = [
  { value: null, label: t('KANBAN.COLUMN.CONV_STATUS_NONE') },
  { value: 'open', label: t('KANBAN.COLUMN.CONV_STATUS_OPEN') },
  { value: 'pending', label: t('KANBAN.COLUMN.CONV_STATUS_PENDING') },
  { value: 'resolved', label: t('KANBAN.COLUMN.CONV_STATUS_RESOLVED') },
  { value: 'snoozed', label: t('KANBAN.COLUMN.CONV_STATUS_SNOOZED') },
];

const wipLimit = ref(props.column.wip_limit ?? null);
const agingWarnDays = ref(props.column.aging_warn_days ?? null);
const agingDangerDays = ref(props.column.aging_danger_days ?? null);

// Auto-assignment v-model object (5 fields from Plan A backend)
const autoAssignment = ref({
  enabled: props.column.auto_assignment_enabled ?? false,
  online_only: props.column.auto_assignment_online_only ?? false,
  override: props.column.auto_assignment_override ?? false,
  reassign_on_return: props.column.auto_assignment_reassign_on_return ?? false,
  max_cards_per_agent: props.column.auto_assignment_max_cards_per_agent ?? null,
});

const updateAutoAssignment = v => {
  autoAssignment.value = v;
};

// Tabs (Mockup B LOCKED — UI-SPEC §1.2)
const activeTab = ref(0);

const tabs = computed(() => {
  const actionsCount =
    (enterActions.value?.length || 0) + (exitActions.value?.length || 0);
  return [
    { id: 'general', label: t('KANBAN.SETTINGS.TAB_GENERAL') },
    { id: 'wip-aging', label: t('KANBAN.SETTINGS.TAB_WIP_AGING') },
    { id: 'auto-assign', label: t('KANBAN.SETTINGS.TAB_AUTO_ASSIGN') },
    {
      id: 'actions',
      label: t('KANBAN.SETTINGS.TAB_ACTIONS'),
      count: actionsCount > 0 ? actionsCount : undefined,
    },
  ];
});

const onTabChanged = tab => {
  const idx = tabs.value.findIndex(x => x.id === tab.id);
  if (idx >= 0) activeTab.value = idx;
};

const normalizeNumberInput = value => {
  if (value === '' || value === null || value === undefined) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
};

const save = async () => {
  isSaving.value = true;
  try {
    const finalEnterActions = [
      ...buildGeneralActions(enterGeneral.value),
      ...enterActions.value,
    ];
    const finalExitActions = [
      ...buildGeneralActions(exitGeneral.value),
      ...exitActions.value,
    ];
    await store.dispatch('kanban/updateColumn', {
      boardId: props.boardId,
      columnId: props.column.id,
      column_type: columnType.value,
      conversation_status: conversationStatus.value,
      wip_limit: normalizeNumberInput(wipLimit.value),
      aging_warn_days: normalizeNumberInput(agingWarnDays.value),
      aging_danger_days: normalizeNumberInput(agingDangerDays.value),
      auto_assignment_enabled: autoAssignment.value.enabled,
      auto_assignment_online_only: autoAssignment.value.online_only,
      auto_assignment_override: autoAssignment.value.override,
      auto_assignment_reassign_on_return:
        autoAssignment.value.reassign_on_return,
      auto_assignment_max_cards_per_agent: normalizeNumberInput(
        autoAssignment.value.max_cards_per_agent
      ),
      enter_actions: finalEnterActions,
      exit_actions: finalExitActions,
    });
    useAlert(t('KANBAN.SETTINGS.SAVED_SUCCESS'));
    emit('saved');
    emit('close');
  } catch {
    useAlert(t('KANBAN.SETTINGS.SAVE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-2xl bg-n-solid-1 rounded-2xl shadow-xl overflow-hidden flex flex-col max-h-[85vh]"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0"
      >
        <div class="flex items-center gap-2">
          <span
            class="w-3 h-3 rounded-full"
            :style="{ backgroundColor: column.color || '#6B7280' }"
          />
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ column.name }}
          </h2>
        </div>
        <button
          class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-slate-11"
          :aria-label="t('KANBAN.SETTINGS.CANCEL')"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- TabBar sticky (Mockup B) -->
      <div class="px-6 py-3 border-b border-n-weak bg-n-solid-1 flex-shrink-0">
        <TabBar
          :tabs="tabs"
          :initial-active-tab="activeTab"
          @tab-changed="onTabChanged"
        />
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto px-6 py-4">
        <!-- TAB: General -->
        <div v-show="activeTab === 0" class="space-y-3">
          <p
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide"
          >
            {{ t('KANBAN.COLUMN.TYPE_LABEL') }}
          </p>

          <SettingsToggleSection
            v-model="isWon"
            :header="t('KANBAN.COLUMN.TYPE_WON')"
            :description="t('KANBAN.COLUMN.TYPE_WON_DESC')"
          />

          <SettingsToggleSection
            v-model="isLost"
            :header="t('KANBAN.COLUMN.TYPE_LOST')"
            :description="t('KANBAN.COLUMN.TYPE_LOST_DESC')"
          />

          <p
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide pt-2"
          >
            {{ t('KANBAN.COLUMN.CONV_STATUS_LABEL') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('KANBAN.COLUMN.CONV_STATUS_DESC') }}
          </p>
          <ComboBox
            v-model="conversationStatus"
            :options="conversationStatusOptions"
            :placeholder="t('KANBAN.COLUMN.CONV_STATUS_NONE')"
          />

          <p
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide pt-2"
          >
            {{ t('KANBAN.COLUMN.DEFAULT_BEHAVIOR_LABEL') }}
          </p>

          <SettingsToggleSection
            v-model="enterGeneral.auto_resolve"
            :header="t('KANBAN.COLUMN.ACTION_AUTO_RESOLVE')"
            :description="t('KANBAN.COLUMN.ACTION_AUTO_RESOLVE_DESC')"
          />

          <SettingsToggleSection
            v-model="enterGeneral.assign_agent"
            :header="t('KANBAN.COLUMN.DEFAULT_ASSIGNEE')"
            :description="t('KANBAN.COLUMN.DEFAULT_ASSIGNEE_DESC')"
          >
            <template v-if="enterGeneral.assign_agent" #editor>
              <ComboBox
                v-model="enterGeneral.agent_id"
                :options="agentOptions"
                :placeholder="t('KANBAN.TASK.NO_ASSIGNEE')"
              />
            </template>
          </SettingsToggleSection>

          <SettingsToggleSection
            v-model="enterGeneral.assign_team"
            :header="t('KANBAN.COLUMN.DEFAULT_TEAM')"
            :description="t('KANBAN.COLUMN.DEFAULT_TEAM_DESC')"
          >
            <template v-if="enterGeneral.assign_team" #editor>
              <ComboBox
                v-model="enterGeneral.team_id"
                :options="teamOptions"
                :placeholder="t('KANBAN.COLUMN.SELECT_TEAM')"
              />
            </template>
          </SettingsToggleSection>
        </div>

        <!-- TAB: WIP & Aging -->
        <div v-show="activeTab === 1" class="space-y-3">
          <p
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide"
          >
            {{ t('KANBAN.COLUMN.WIP_LIMIT_LABEL') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('KANBAN.COLUMN.WIP_LIMIT_DESC') }}
          </p>
          <Input
            v-model="wipLimit"
            type="number"
            min="1"
            :placeholder="t('KANBAN.COLUMN.WIP_LIMIT_PLACEHOLDER')"
          />

          <p
            class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide pt-2"
          >
            {{ t('KANBAN.COLUMN.AGING_LABEL') }}
          </p>
          <p class="text-xs text-n-slate-11">
            {{ t('KANBAN.COLUMN.AGING_DESC') }}
          </p>
          <div class="grid grid-cols-2 gap-2">
            <div>
              <p class="text-xs text-n-slate-11 mb-1">
                {{ t('KANBAN.COLUMN.AGING_WARN_DAYS_LABEL') }}
              </p>
              <Input
                v-model="agingWarnDays"
                type="number"
                min="1"
                :placeholder="t('KANBAN.COLUMN.AGING_DAYS_PLACEHOLDER')"
              />
            </div>
            <div>
              <p class="text-xs text-n-slate-11 mb-1">
                {{ t('KANBAN.COLUMN.AGING_DANGER_DAYS_LABEL') }}
              </p>
              <Input
                v-model="agingDangerDays"
                type="number"
                min="1"
                :placeholder="t('KANBAN.COLUMN.AGING_DAYS_PLACEHOLDER')"
              />
            </div>
          </div>
        </div>

        <!-- TAB: Auto-assign -->
        <div v-show="activeTab === 2">
          <AutoAssignmentEditor
            :model-value="autoAssignment"
            @update:model-value="updateAutoAssignment"
          />
        </div>

        <!-- TAB: Actions -->
        <div v-show="activeTab === 3">
          <ColumnActionsEditor
            v-model:enter-actions="enterActions"
            v-model:exit-actions="exitActions"
          />
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex justify-end gap-2 px-6 py-4 border-t border-n-weak flex-shrink-0 bg-n-solid-1"
      >
        <button
          class="px-4 py-2 text-sm rounded-lg outline outline-1 -outline-offset-1 outline-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          {{ t('KANBAN.SETTINGS.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
          :disabled="isSaving"
          :aria-busy="isSaving"
          @click="save"
        >
          {{
            isSaving
              ? t('KANBAN.SETTINGS.STATUS_SAVING')
              : t('KANBAN.SETTINGS.SAVE')
          }}
        </button>
      </div>
    </div>
  </div>
</template>
