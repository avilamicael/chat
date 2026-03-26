<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import { useAlert } from 'dashboard/composables';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';

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

const parseEnterActions = actions => {
  const form = {
    auto_create_task: false,
    auto_assign_agent: false,
    auto_assign_conversation: false,
    auto_resolve: false,
    send_webhook: false,
    webhook_url: '',
    assign_agent: false,
    agent_id: null,
    assign_team: false,
    team_id: null,
  };
  (actions || []).forEach(action => {
    if (!action?.action_name) return;
    switch (action.action_name) {
      case 'auto_create_task': form.auto_create_task = true; break;
      case 'auto_assign_agent': form.auto_assign_agent = true; break;
      case 'auto_assign_conversation': form.auto_assign_conversation = true; break;
      case 'auto_resolve': form.auto_resolve = true; break;
      case 'send_webhook':
        form.send_webhook = true;
        form.webhook_url = action.url || '';
        break;
      case 'assign_agent':
        form.assign_agent = true;
        form.agent_id = action.agent_id || null;
        break;
      case 'assign_team':
        form.assign_team = true;
        form.team_id = action.team_id || null;
        break;
    }
  });
  return form;
};

const parseExitActions = actions => {
  const form = { send_webhook: false, webhook_url: '' };
  (actions || []).forEach(action => {
    if (action?.action_name === 'send_webhook') {
      form.send_webhook = true;
      form.webhook_url = action.url || '';
    }
  });
  return form;
};

const buildEnterActions = form => {
  const actions = [];
  if (form.auto_create_task) actions.push({ action_name: 'auto_create_task' });
  if (form.auto_assign_agent) actions.push({ action_name: 'auto_assign_agent' });
  if (form.auto_assign_conversation) actions.push({ action_name: 'auto_assign_conversation' });
  if (form.auto_resolve) actions.push({ action_name: 'auto_resolve' });
  if (form.send_webhook && form.webhook_url) actions.push({ action_name: 'send_webhook', url: form.webhook_url });
  if (form.assign_agent && form.agent_id) actions.push({ action_name: 'assign_agent', agent_id: form.agent_id });
  if (form.assign_team && form.team_id) actions.push({ action_name: 'assign_team', team_id: form.team_id });
  return actions;
};

const buildExitActions = form => {
  const actions = [];
  if (form.send_webhook && form.webhook_url) actions.push({ action_name: 'send_webhook', url: form.webhook_url });
  return actions;
};

const enterForm = ref(parseEnterActions(props.column.enter_actions));
const exitForm = ref(parseExitActions(props.column.exit_actions));
const isSaving = ref(false);

const save = async () => {
  isSaving.value = true;
  try {
    await store.dispatch('kanban/updateColumn', {
      boardId: props.boardId,
      columnId: props.column.id,
      enter_actions: buildEnterActions(enterForm.value),
      exit_actions: buildExitActions(exitForm.value),
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
    <div class="w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-xl overflow-hidden flex flex-col max-h-[85vh]">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0">
        <div class="flex items-center gap-2">
          <span class="w-3 h-3 rounded-full" :style="{ backgroundColor: column.color || '#6B7280' }" />
          <h2 class="text-base font-semibold text-n-slate-12">{{ column.name }}</h2>
        </div>
        <button class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-slate-10" @click="emit('close')">
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto px-6 py-4 space-y-3">

        <!-- Enter Actions -->
        <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
          {{ t('KANBAN.COLUMN.ENTER_ACTIONS_LABEL') }}
        </p>

        <SettingsToggleSection
          v-model="enterForm.auto_create_task"
          :header="t('KANBAN.COLUMN.ACTION_AUTO_CREATE_TASK')"
          :description="t('KANBAN.COLUMN.ACTION_AUTO_CREATE_TASK_DESC')"
        />

        <SettingsToggleSection
          v-model="enterForm.auto_assign_agent"
          :header="t('KANBAN.COLUMN.ACTION_AUTO_ASSIGN_AGENT')"
          :description="t('KANBAN.COLUMN.ACTION_AUTO_ASSIGN_AGENT_DESC')"
        />

        <SettingsToggleSection
          v-model="enterForm.auto_assign_conversation"
          :header="t('KANBAN.COLUMN.ACTION_AUTO_ASSIGN_CONV')"
          :description="t('KANBAN.COLUMN.ACTION_AUTO_ASSIGN_CONV_DESC')"
        />

        <SettingsToggleSection
          v-model="enterForm.auto_resolve"
          :header="t('KANBAN.COLUMN.ACTION_AUTO_RESOLVE')"
          :description="t('KANBAN.COLUMN.ACTION_AUTO_RESOLVE_DESC')"
        />

        <SettingsToggleSection
          v-model="enterForm.send_webhook"
          :header="t('KANBAN.COLUMN.ACTION_WEBHOOK_ENTER')"
          :description="t('KANBAN.COLUMN.ACTION_WEBHOOK_ENTER_DESC')"
        >
          <template v-if="enterForm.send_webhook" #editor>
            <Input
              v-model="enterForm.webhook_url"
              type="url"
              :placeholder="t('KANBAN.COLUMN.WEBHOOK_URL_PLACEHOLDER')"
            />
            <p class="mt-2 text-xs text-n-slate-9">{{ t('KANBAN.COLUMN.WEBHOOK_FUTURE_NOTE') }}</p>
          </template>
        </SettingsToggleSection>

        <SettingsToggleSection
          v-model="enterForm.assign_agent"
          :header="t('KANBAN.COLUMN.ACTION_ASSIGN_AGENT')"
          :description="t('KANBAN.COLUMN.ACTION_ASSIGN_AGENT_DESC')"
        >
          <template v-if="enterForm.assign_agent" #editor>
            <ComboBox
              v-model="enterForm.agent_id"
              :options="agentOptions"
              :placeholder="t('KANBAN.TASK.NO_ASSIGNEE')"
            />
          </template>
        </SettingsToggleSection>

        <SettingsToggleSection
          v-model="enterForm.assign_team"
          :header="t('KANBAN.COLUMN.ACTION_ASSIGN_TEAM')"
          :description="t('KANBAN.COLUMN.ACTION_ASSIGN_TEAM_DESC')"
        >
          <template v-if="enterForm.assign_team" #editor>
            <ComboBox
              v-model="enterForm.team_id"
              :options="teamOptions"
              :placeholder="t('KANBAN.COLUMN.SELECT_TEAM')"
            />
          </template>
        </SettingsToggleSection>

        <!-- Exit Actions -->
        <p class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide pt-2">
          {{ t('KANBAN.COLUMN.EXIT_ACTIONS_LABEL') }}
        </p>

        <SettingsToggleSection
          v-model="exitForm.send_webhook"
          :header="t('KANBAN.COLUMN.ACTION_WEBHOOK_EXIT')"
          :description="t('KANBAN.COLUMN.ACTION_WEBHOOK_EXIT_DESC')"
        >
          <template v-if="exitForm.send_webhook" #editor>
            <Input
              v-model="exitForm.webhook_url"
              type="url"
              :placeholder="t('KANBAN.COLUMN.WEBHOOK_URL_PLACEHOLDER')"
            />
            <p class="mt-2 text-xs text-n-slate-9">{{ t('KANBAN.COLUMN.WEBHOOK_FUTURE_NOTE') }}</p>
          </template>
        </SettingsToggleSection>
      </div>

      <!-- Footer -->
      <div class="flex justify-end gap-2 px-6 py-4 border-t border-n-weak flex-shrink-0">
        <button
          class="px-4 py-2 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          {{ t('KANBAN.TEMPLATE.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
          :disabled="isSaving"
          @click="save"
        >
          {{ isSaving ? '...' : t('KANBAN.SETTINGS.SAVE') }}
        </button>
      </div>
    </div>
  </div>
</template>
