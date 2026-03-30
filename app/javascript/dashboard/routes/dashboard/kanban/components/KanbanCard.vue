<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import CardPriorityIcon from 'dashboard/components-next/Conversation/ConversationCard/CardPriorityIcon.vue';

const props = defineProps({
  card: { type: Object, required: true },
  accountId: { type: [String, Number], required: true },
});

const emit = defineEmits(['open-detail']);

const { t } = useI18n();

const conversation = computed(() => props.card.conversation);
const isStandaloneTask = computed(() => !conversation.value?.id);

const sender = computed(() => conversation.value?.meta?.sender);
const assignee = computed(() => conversation.value?.meta?.assignee);

const displayName = computed(() => {
  if (props.card.title) return props.card.title;
  if (!isStandaloneTask.value) return sender.value?.name || t('KANBAN.CARD.NO_NAME');
  return t('KANBAN.CARD.NO_NAME');
});

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

const channelType = computed(() => conversation.value?.channel);
const channelColor = computed(() => CHANNEL_COLORS[channelType.value] || '#94A3B8');
const channelLabel = computed(
  () => CHANNEL_LABELS[channelType.value] ||
    channelType.value?.split('::')[1]?.toLowerCase() || ''
);

const timeOpen = computed(() => {
  const createdAt = props.card.created_at || conversation.value?.created_at;
  if (!createdAt) return null;
  const diffMs = Date.now() - new Date(createdAt).getTime();
  const mins = Math.floor(diffMs / 60000);
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
});

const parseLocalDate = iso => {
  const dateStr = String(iso).slice(0, 10);
  return new Date(`${dateStr}T00:00:00`);
};

const dueDateFormatted = computed(() => {
  if (!props.card.due_date) return null;
  const d = parseLocalDate(props.card.due_date);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  if (d.toDateString() === today.toDateString()) return t('KANBAN.CARD.TODAY');
  if (d.toDateString() === tomorrow.toDateString()) return t('KANBAN.CARD.TOMORROW');
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
});

const isDueSoon = computed(() => {
  if (!props.card.due_date) return false;
  return parseLocalDate(props.card.due_date).getTime() - Date.now() < 86400000;
});

const openDetail = () => emit('open-detail', props.card);
</script>

<template>
  <div
    data-kanban-card
    class="bg-n-solid-2 rounded-lg p-3 cursor-pointer hover:bg-n-solid-3 transition-colors border border-n-weak"
    @click="openDetail"
  >
    <!-- Top row: avatar/icon + name + assignee avatar -->
    <div class="flex items-start gap-2 mb-2">
      <template v-if="isStandaloneTask">
        <div class="flex-shrink-0 w-8 h-8 rounded-full bg-n-alpha-2 flex items-center justify-center">
          <Icon icon="i-lucide-clipboard-list" class="size-4 text-n-slate-10" />
        </div>
      </template>
      <Avatar
        v-else
        :name="displayName"
        :src="sender?.thumbnail || ''"
        :size="32"
        class="flex-shrink-0"
      />
      <span class="flex-1 text-sm font-medium text-n-slate-12 truncate leading-snug mt-0.5">
        {{ displayName }}
      </span>
      <Avatar
        v-if="assignee"
        :name="assignee.name"
        :src="assignee.thumbnail || ''"
        :size="24"
        class="flex-shrink-0"
      />
    </div>

    <!-- Channel badge (only for conversation cards) -->
    <div v-if="channelLabel && !isStandaloneTask" class="mb-2">
      <span
        class="inline-flex items-center gap-1 text-xs px-1.5 py-0.5 rounded"
        :style="{ backgroundColor: channelColor + '22', color: channelColor }"
      >
        <span class="w-1.5 h-1.5 rounded-full flex-shrink-0" :style="{ backgroundColor: channelColor }" />
        {{ channelLabel }}
      </span>
    </div>

    <!-- Priority badge (for tasks with priority) -->
    <div v-if="card.priority" class="mb-2">
      <CardPriorityIcon :priority="card.priority" />
    </div>

    <!-- Separator + metadata row -->
    <div v-if="timeOpen || dueDateFormatted" class="border-t border-n-weak mt-2 pt-2 flex items-center justify-between gap-1">
      <div
        v-if="dueDateFormatted"
        class="flex items-center gap-1 text-xs"
        :class="isDueSoon ? 'text-n-ruby-9' : 'text-n-slate-10'"
      >
        <Icon icon="i-lucide-calendar" class="size-3" />
        <span>{{ dueDateFormatted }}</span>
      </div>
      <div v-if="timeOpen" class="flex items-center gap-1 text-xs text-n-slate-10 ml-auto">
        <Icon icon="i-lucide-clock" class="size-3" />
        <span>{{ timeOpen }}</span>
      </div>
    </div>
  </div>
</template>
