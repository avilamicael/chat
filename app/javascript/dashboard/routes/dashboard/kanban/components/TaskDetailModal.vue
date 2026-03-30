<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import DatePicker from 'vue-datepicker-next';
import 'vue-datepicker-next/index.css';
import { frontendURL } from 'dashboard/helper/URLHelper.js';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';
import OutcomeReasonModal from './OutcomeReasonModal.vue';

const props = defineProps({
  card: { type: Object, required: true },
  boardId: { type: [String, Number], required: true },
  accountId: { type: [String, Number], required: true },
  columns: { type: Array, default: () => [] },
});

const emit = defineEmits(['close', 'deleted']);

const { t } = useI18n();
const store = useStore();

const localTitle = ref(props.card.title || '');
const localDescription = ref(props.card.description || '');
const isSaving = ref(false);

const conversation = computed(() => props.card.conversation);
const contactName = computed(() =>
  conversation.value?.meta?.sender?.name || t('KANBAN.CARD.NO_NAME')
);
const isStandaloneTask = computed(() => !conversation.value?.id);

const columnOptions = computed(() =>
  props.columns.map(c => ({ value: c.id, label: c.name }))
);

const priorityOptions = computed(() => [
  { value: 'low', label: t('KANBAN.TASK.PRIORITY_LOW') },
  { value: 'medium', label: t('KANBAN.TASK.PRIORITY_MEDIUM') },
  { value: 'high', label: t('KANBAN.TASK.PRIORITY_HIGH') },
  { value: 'urgent', label: t('KANBAN.TASK.PRIORITY_URGENT') },
]);

const statusOptions = computed(() => [
  { value: 'open', label: t('KANBAN.TASK.STATUS_OPEN') },
  { value: 'pending', label: t('KANBAN.TASK.STATUS_PENDING') },
  { value: 'resolved', label: t('KANBAN.TASK.STATUS_RESOLVED') },
  { value: 'snoozed', label: t('KANBAN.TASK.STATUS_SNOOZED') },
]);

// Agents — TagInput pattern (same as CollaboratorsPage)
const agents = useMapGetter('agents/getAgents');
const selectedAssigneeIds = ref([...(props.card.assignee_ids || [])]);

const selectedAssigneeNames = computed(() =>
  selectedAssigneeIds.value.map(id => agents.value.find(a => a.id === id)?.name ?? '')
);

const agentMenuItems = computed(() =>
  agents.value
    .filter(({ id }) => !selectedAssigneeIds.value.includes(id))
    .map(({ id, name, thumbnail, avatar_url }) => ({
      label: name,
      value: id,
      action: 'select',
      thumbnail: { name, src: thumbnail || avatar_url || '' },
    }))
);

const handleAssigneeAdd = ({ value }) => {
  if (!selectedAssigneeIds.value.includes(value)) {
    selectedAssigneeIds.value.push(value);
    saveField('assignee_ids', [...selectedAssigneeIds.value]);
  }
};

const handleAssigneeRemove = index => {
  selectedAssigneeIds.value.splice(index, 1);
  saveField('assignee_ids', [...selectedAssigneeIds.value]);
};

// Teams — TagInput pattern (multiple)
const teams = useMapGetter('teams/getTeams');
const selectedTeamIds = ref([...(props.card.team_ids || (props.card.team_id ? [props.card.team_id] : []))]);

const selectedTeamNames = computed(() =>
  selectedTeamIds.value.map(id => teams.value.find(tm => tm.id === id)?.name ?? '')
);

const teamMenuItems = computed(() =>
  teams.value
    .filter(({ id }) => !selectedTeamIds.value.includes(id))
    .map(({ id, name }) => ({
      label: name,
      value: id,
      action: 'select',
    }))
);

const handleTeamAdd = ({ value }) => {
  if (!selectedTeamIds.value.includes(value)) {
    selectedTeamIds.value.push(value);
    saveField('team_ids', [...selectedTeamIds.value]);
  }
};

const handleTeamRemove = index => {
  selectedTeamIds.value.splice(index, 1);
  saveField('team_ids', [...selectedTeamIds.value]);
};

onMounted(() => store.dispatch('teams/get'));

const selectedColumnId = ref(props.card.kanban_column_id);
const pendingColumnId = ref(null);
const pendingColumnObject = computed(() => props.columns.find(c => c.id === pendingColumnId.value));

const handleColumnChange = newVal => {
  const targetCol = props.columns.find(c => c.id === newVal);
  if (targetCol && ['won', 'lost'].includes(targetCol.column_type)) {
    pendingColumnId.value = newVal;
  } else {
    selectedColumnId.value = newVal;
    saveField('kanban_column_id', newVal);
  }
};

const confirmColumnMove = async reason => {
  const targetId = pendingColumnId.value;
  pendingColumnId.value = null;
  selectedColumnId.value = targetId;
  await store.dispatch('kanban/moveCard', {
    boardId: Number(props.boardId),
    cardId: props.card.id,
    columnId: targetId,
    position: 0,
    outcomeReason: reason || null,
  });
};

const cancelColumnMove = () => {
  pendingColumnId.value = null;
};

const selectedPriority = ref(props.card.priority || null);
const selectedStatus = ref(props.card.task_status || 'open');

const toDateInputValue = iso => (iso ? new Date(iso).toISOString().slice(0, 10) : '');
const localDueDate = ref(toDateInputValue(props.card.due_date));

const timeOpen = computed(() => {
  const createdAt = props.card.created_at;
  if (!createdAt) return null;
  const diffMs = Date.now() - new Date(createdAt).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
});

const saveField = async (field, value) => {
  if (isSaving.value) return;
  isSaving.value = true;
  try {
    await store.dispatch('kanban/updateCard', {
      boardId: props.boardId,
      cardId: props.card.id,
      [field]: value,
    });
  } finally {
    isSaving.value = false;
  }
};

watch(selectedPriority, val => saveField('priority', val));
watch(selectedStatus, val => saveField('task_status', val));
watch(localDueDate, val => saveField('due_date', val ? new Date(val).toISOString() : null));

const saveTitle = () => {
  const trimmed = localTitle.value.trim();
  if (trimmed !== (props.card.title || '')) {
    saveField('title', trimmed || null);
  }
};

const saveDescription = () => {
  if (localDescription.value !== props.card.description) {
    saveField('description', localDescription.value);
  }
};

const isDeleting = ref(false);
const deleteCard = async () => {
  if (!window.confirm(t('KANBAN.CARD.DELETE_CONFIRM'))) return;
  isDeleting.value = true;
  try {
    await store.dispatch('kanban/deleteCard', {
      boardId: props.boardId,
      cardId: props.card.id,
    });
    emit('deleted');
    emit('close');
  } finally {
    isDeleting.value = false;
  }
};

const openConversation = () => {
  if (!conversation.value?.id) return;
  window.open(
    frontendURL(`accounts/${props.accountId}/conversations/${conversation.value.id}`),
    '_blank',
    'noopener,noreferrer'
  );
};

const CHANNEL_COLORS = {
  'Channel::Whatsapp': '#25D366',
  'Channel::Baileys': '#25D366',
  'Channel::Email': '#60A5FA',
  'Channel::TikTok': '#69C9D0',
  'Channel::Instagram': '#E1306C',
  'Channel::FacebookPage': '#1877F2',
  'Channel::Telegram': '#2CA5E0',
};
const CHANNEL_LABELS = {
  'Channel::Whatsapp': 'whatsapp',
  'Channel::Baileys': 'whatsapp',
  'Channel::Email': 'email',
  'Channel::TikTok': 'tiktok',
  'Channel::Instagram': 'instagram',
  'Channel::FacebookPage': 'facebook',
  'Channel::Telegram': 'telegram',
};

const channelColor = computed(() => CHANNEL_COLORS[conversation.value?.channel] || '#94A3B8');
const channelLabel = computed(() => CHANNEL_LABELS[conversation.value?.channel] || '');
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-xl bg-n-solid-1 rounded-2xl shadow-xl overflow-hidden max-h-[90vh] flex flex-col"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0"
      >
        <div class="flex items-center gap-2 flex-1 min-w-0">
          <span
            v-if="isStandaloneTask"
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium bg-n-alpha-2 text-n-slate-11 flex-shrink-0"
          >
            <Icon icon="i-lucide-clipboard-list" class="size-3" />
            {{ t('KANBAN.TASK.STANDALONE_BADGE') }}
          </span>
          <CardPriorityIcon v-if="card.priority" :priority="card.priority" />
          <span v-if="timeOpen" class="text-xs text-n-slate-9 ml-auto flex items-center gap-1">
            <Icon icon="i-lucide-clock" class="size-3" />
            {{ timeOpen }}
          </span>
        </div>
        <button
          class="ml-2 p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-slate-10 flex-shrink-0"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto px-6 py-5 space-y-4">

        <!-- Title (standalone tasks) -->
        <div v-if="isStandaloneTask">
          <input
            v-model="localTitle"
            type="text"
            class="w-full text-lg font-semibold text-n-slate-12 bg-transparent border-0 outline-none focus:bg-n-alpha-2 rounded px-2 -mx-2 py-1 transition-colors placeholder:text-n-slate-8"
            :placeholder="t('KANBAN.TASK.TITLE_PLACEHOLDER')"
            @blur="saveTitle"
            @keydown.enter.prevent="saveTitle"
          />
        </div>

        <!-- Conversation block -->
        <div
          v-if="conversation?.id"
          class="flex items-center gap-3 p-3 rounded-xl border border-n-weak bg-n-solid-2"
        >
          <Avatar
            :name="contactName"
            :src="conversation.meta?.sender?.thumbnail || ''"
            :size="36"
            class="flex-shrink-0"
          />
          <div class="flex-1 min-w-0">
            <input
              v-model="localTitle"
              type="text"
              class="w-full text-sm font-medium text-n-slate-12 bg-transparent border-0 outline-none focus:bg-n-alpha-1 rounded px-1 -mx-1 truncate placeholder:text-n-slate-9"
              :placeholder="contactName"
              @blur="saveTitle"
              @keydown.enter.prevent="saveTitle"
            />
            <div class="flex items-center gap-2 mt-0.5">
              <span
                v-if="channelLabel"
                class="inline-flex items-center gap-1 text-xs px-1.5 py-0.5 rounded"
                :style="{ backgroundColor: channelColor + '22', color: channelColor }"
              >
                <span
                  class="w-1.5 h-1.5 rounded-full"
                  :style="{ backgroundColor: channelColor }"
                />
                {{ channelLabel }}
              </span>
              <span class="text-xs text-n-slate-9">#{{ conversation.display_id }}</span>
            </div>
          </div>
          <button
            class="text-xs text-n-brand hover:underline flex-shrink-0"
            @click="openConversation"
          >
            {{ t('KANBAN.TASK.OPEN_CONV') }}
          </button>
        </div>

        <!-- Column + Priority -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.COLUMN_LABEL') }}
            </label>
            <ComboBox
              :model-value="selectedColumnId"
              :options="columnOptions"
              :placeholder="t('KANBAN.TASK.COLUMN_LABEL')"
              @update:model-value="handleColumnChange"
            />
          </div>
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.PRIORITY_LABEL') }}
            </label>
            <ComboBox
              v-model="selectedPriority"
              :options="priorityOptions"
              :placeholder="t('KANBAN.TASK.NO_PRIORITY')"
            />
          </div>
        </div>

        <!-- Status + Due date — side by side -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.STATUS_LABEL') }}
            </label>
            <ComboBox
              v-model="selectedStatus"
              :options="statusOptions"
              :placeholder="t('KANBAN.TASK.STATUS_LABEL')"
            />
          </div>
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.DUE_DATE_LABEL') }}
            </label>
            <DatePicker
              v-model:value="localDueDate"
              type="date"
              value-type="YYYY-MM-DD"
              format="DD/MM/YYYY"
              :placeholder="t('KANBAN.TASK.DUE_DATE_LABEL')"
              :disabled-date="date => date < new Date(new Date().setHours(0, 0, 0, 0))"
              append-to-body
              class="!w-full [&_.mx-input-wrapper]:w-full [&_.mx-input]:w-full"
            />
          </div>
        </div>

        <!-- Assignees + Teams — side by side with TagInput -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.ASSIGNEE_LABEL') }}
            </label>
            <div
              class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong px-2 py-1.5 min-h-[38px]"
            >
              <TagInput
                :model-value="selectedAssigneeNames"
                :placeholder="t('KANBAN.TASK.NO_ASSIGNEE')"
                :menu-items="agentMenuItems"
                show-dropdown
                skip-label-dedup
                :auto-open-dropdown="false"
                @add="handleAssigneeAdd"
                @remove="handleAssigneeRemove"
              />
            </div>
          </div>
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.TEAM_LABEL') }}
            </label>
            <div
              class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong px-2 py-1.5 min-h-[38px]"
            >
              <TagInput
                :model-value="selectedTeamNames"
                :placeholder="t('KANBAN.TASK.NO_TEAM')"
                :menu-items="teamMenuItems"
                show-dropdown
                :auto-open-dropdown="false"
                @add="handleTeamAdd"
                @remove="handleTeamRemove"
              />
            </div>
          </div>
        </div>

        <!-- Description -->
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
            {{ t('KANBAN.TASK.DESCRIPTION_LABEL') }}
          </label>
          <textarea
            v-model="localDescription"
            rows="4"
            :placeholder="t('KANBAN.TASK.DESCRIPTION_PLACEHOLDER')"
            class="w-full px-3 py-2 text-sm rounded-xl border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand resize-y min-h-[96px]"
            @blur="saveDescription"
          />
        </div>
      </div>

      <!-- Footer -->
      <div
        class="flex items-center justify-between px-6 py-3 border-t border-n-weak bg-n-solid-1 flex-shrink-0"
      >
        <button
          class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-lg border border-red-300 dark:border-red-800 text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors disabled:opacity-50"
          :disabled="isDeleting"
          @click="deleteCard"
        >
          <Icon icon="i-lucide-trash-2" class="size-3.5" />
          {{ t('KANBAN.CARD.DELETE') }}
        </button>
        <div class="flex items-center gap-3">
          <span v-if="isSaving" class="text-xs text-n-slate-9">Saving...</span>
          <span class="text-xs text-n-slate-9">#{{ card.id }}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Outcome Reason Modal (won/lost column change) -->
  <OutcomeReasonModal
    v-if="pendingColumnId"
    :column-type="pendingColumnObject.column_type"
    :card-title="card.title || (card.conversation ? `#${card.conversation.display_id}` : '')"
    @confirm="confirmColumnMove"
    @cancel="cancelColumnMove"
  />
</template>
