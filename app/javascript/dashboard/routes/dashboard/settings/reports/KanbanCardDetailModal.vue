<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import KanbanAPI from 'dashboard/api/kanban.js';
import { frontendURL } from 'dashboard/helper/URLHelper.js';

const props = defineProps({
  card: { type: Object, required: true },
  accountId: { type: [Number, String], required: true },
});

const emit = defineEmits(['close']);

const { t } = useI18n();

const activities = ref([]);
const isLoadingActivities = ref(false);

const priorityClasses = {
  urgent: 'bg-red-100 text-red-700',
  high: 'bg-orange-100 text-orange-700',
  medium: 'bg-yellow-100 text-yellow-700',
  low: 'bg-n-alpha-2 text-n-slate-10',
};

const outcomeClasses = {
  won: 'bg-green-100 text-green-700',
  lost: 'bg-red-100 text-red-700',
};

const formatDate = dateStr => {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
};

const formatDateTime = dateStr => {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const activityLabel = activity => {
  if (activity.action === 'create') return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_CREATED');
  if (activity.action === 'update') {
    const changes = activity.changes || {};
    if (changes.kanban_column_id) return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_MOVED');
    if (changes.assignee_id) return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_ASSIGNEE_CHANGED');
    if (changes.priority) {
      return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_PRIORITY_CHANGED', { priority: changes.priority[1] });
    }
    if (changes.outcome) {
      const label = changes.outcome[1] === 'won' ? t('KANBAN.OUTCOME.WON') : t('KANBAN.OUTCOME.LOST');
      return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_ARCHIVED_AS', { outcome: label });
    }
    return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_UPDATED');
  }
  return t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY_UPDATED');
};

const userInitial = user => {
  if (!user?.name) return '?';
  return user.name.charAt(0).toUpperCase();
};

const sortedActivities = computed(() =>
  [...activities.value].sort(
    (a, b) => new Date(b.created_at) - new Date(a.created_at)
  )
);

onMounted(async () => {
  const boardId = props.card.kanban_board_id;
  if (!boardId) return;
  isLoadingActivities.value = true;
  try {
    const response = await KanbanAPI.getCardActivities(boardId, props.card.id);
    activities.value = response.data?.activities || [];
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('[KanbanCardDetailModal] Failed to load activities:', e);
    activities.value = [];
  } finally {
    isLoadingActivities.value = false;
  }
});
</script>

<template>
  <div
    class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center"
    @click.self="emit('close')"
  >
    <div class="bg-n-solid-1 rounded-2xl shadow-xl w-full max-w-2xl max-h-[85vh] flex flex-col overflow-hidden">
      <!-- Header -->
      <div class="flex items-center gap-3 px-6 py-4 border-b border-n-weak">
        <span class="flex-1 text-base font-semibold text-n-slate-12 truncate">
          {{
            card.title ||
            (card.conversation ? `#${card.conversation.display_id}` : t('KANBAN.CARD.NO_NAME'))
          }}
        </span>
        <span
          v-if="card.outcome"
          class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
          :class="outcomeClasses[card.outcome]"
        >
          {{ card.outcome === 'won' ? t('KANBAN.OUTCOME.WON') : t('KANBAN.OUTCOME.LOST') }}
        </span>
        <button
          class="ml-1 text-n-slate-9 hover:text-n-slate-12 transition-colors"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-5" />
        </button>
      </div>

      <!-- Body -->
      <div class="overflow-y-auto px-6 py-4 flex flex-col gap-6">
        <!-- Conversation link -->
        <a
          v-if="card.conversation"
          :href="frontendURL(`accounts/${accountId}/conversations/${card.conversation.id}`)"
          target="_blank"
          class="inline-flex items-center gap-1.5 text-sm text-n-brand hover:underline w-fit"
        >
          <Icon icon="i-lucide-external-link" class="size-4" />
          {{ t('KANBAN.REPORTS.CARD_DETAIL.OPEN_CONVERSATION') }} #{{ card.conversation.display_id }}
        </a>

        <!-- Details section -->
        <div>
          <p class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide mb-3">
            {{ t('KANBAN.REPORTS.CARD_DETAIL.DETAILS') }}
          </p>
          <div class="grid grid-cols-2 gap-x-6 gap-y-3">
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.TASK.ASSIGNEE_LABEL') }}</p>
              <p class="text-sm text-n-slate-12">
                {{
                  card.assignees?.length
                    ? card.assignees.map(a => a.name).join(', ')
                    : t('KANBAN.CARD.UNASSIGNED')
                }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.TASK.TEAM_LABEL') }}</p>
              <p class="text-sm text-n-slate-12">
                {{ card.teams?.length ? card.teams[0].name : '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.TASK.PRIORITY_LABEL') }}</p>
              <span
                v-if="card.priority"
                class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
                :class="priorityClasses[card.priority]"
              >
                {{ card.priority.charAt(0).toUpperCase() + card.priority.slice(1) }}
              </span>
              <span v-else class="text-sm text-n-slate-8">—</span>
            </div>
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.TASK.STATUS_LABEL') }}</p>
              <p class="text-sm text-n-slate-12">{{ card.task_status || '—' }}</p>
            </div>
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.TASK.DUE_DATE_LABEL') }}</p>
              <p class="text-sm text-n-slate-12">{{ formatDate(card.due_date) }}</p>
            </div>
            <div>
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.ARCHIVE.ARCHIVED_AT') }}</p>
              <p class="text-sm text-n-slate-12">{{ formatDate(card.archived_at) }}</p>
            </div>
            <div v-if="card.outcome_reason" class="col-span-2">
              <p class="text-xs text-n-slate-9 mb-0.5">{{ t('KANBAN.ARCHIVE.REASON') }}</p>
              <p class="text-sm text-n-slate-12">{{ card.outcome_reason }}</p>
            </div>
          </div>
        </div>

        <!-- Description section -->
        <div>
          <p class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide mb-3">
            {{ t('KANBAN.TASK.DESCRIPTION_LABEL') }}
          </p>
          <p class="text-sm text-n-slate-11 whitespace-pre-wrap">
            {{ card.description || '—' }}
          </p>
        </div>

        <!-- Activity section -->
        <div>
          <p class="text-xs font-semibold text-n-slate-9 uppercase tracking-wide mb-3">
            {{ t('KANBAN.REPORTS.CARD_DETAIL.ACTIVITY') }}
          </p>
          <div v-if="isLoadingActivities" class="text-sm text-n-slate-9">
            {{ t('KANBAN.REPORTS.CARD_DETAIL.LOADING') }}
          </div>
          <div v-else-if="sortedActivities.length === 0" class="text-sm text-n-slate-8">
            {{ t('KANBAN.REPORTS.CARD_DETAIL.NO_ACTIVITY') }}
          </div>
          <div v-else class="flex flex-col gap-3 max-h-64 overflow-y-auto pr-1">
            <div
              v-for="activity in sortedActivities"
              :key="activity.id"
              class="flex gap-3 items-start"
            >
              <div
                v-if="activity.user?.thumbnail"
                class="size-7 rounded-full overflow-hidden flex-shrink-0"
              >
                <img
                  :src="activity.user.thumbnail"
                  :alt="activity.user.name"
                  class="size-7 object-cover"
                />
              </div>
              <div
                v-else
                class="size-7 rounded-full bg-n-alpha-3 flex items-center justify-center flex-shrink-0 text-xs font-medium text-n-slate-11"
              >
                {{ userInitial(activity.user) }}
              </div>
              <div class="flex flex-col gap-0.5 min-w-0">
                <p class="text-sm text-n-slate-12">
                  <span class="font-medium">{{ activity.user?.name || t('KANBAN.REPORTS.CARD_DETAIL.SYSTEM') }}</span>
                  {{ ' ' + activityLabel(activity) }}
                </p>
                <p class="text-xs text-n-slate-9">{{ formatDateTime(activity.created_at) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
