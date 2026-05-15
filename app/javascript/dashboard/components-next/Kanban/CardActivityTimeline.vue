<script setup>
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import kanbanAPI from 'dashboard/api/kanban.js';

const props = defineProps({
  cardId: { type: [Number, String], required: true },
  boardId: { type: [Number, String], required: true },
});

const { t } = useI18n();

const PAGE_SIZE = 20;
const activities = ref([]);
const isLoading = ref(false);
const hasMore = ref(true);
const beforeId = ref(null);

const loadMore = async () => {
  if (isLoading.value || !hasMore.value) return;
  isLoading.value = true;
  try {
    const { data } = await kanbanAPI.getCardActivities(
      props.boardId,
      props.cardId,
      { before: beforeId.value, limit: PAGE_SIZE }
    );
    activities.value.push(...(data.activities || []));
    hasMore.value = Boolean(data.meta?.has_more);
    beforeId.value = data.meta?.next_before_id ?? null;
  } finally {
    isLoading.value = false;
  }
};

onMounted(loadMore);

const fieldKey = field => `KANBAN.ACTIVITY.FIELD.${field}`;

const formatRelative = iso => {
  if (!iso) return '';
  const date = new Date(iso);
  const diffSec = Math.floor((Date.now() - date.getTime()) / 1000);
  if (diffSec < 60) return `${diffSec}s`;
  const diffMin = Math.floor(diffSec / 60);
  if (diffMin < 60) return `${diffMin}m`;
  const diffHour = Math.floor(diffMin / 60);
  if (diffHour < 24) return `${diffHour}h`;
  const diffDay = Math.floor(diffHour / 24);
  if (diffDay < 30) return `${diffDay}d`;
  return date.toLocaleDateString();
};
</script>

<template>
  <section class="space-y-3">
    <h3 class="text-xs font-medium text-n-slate-11">
      {{ t('KANBAN.ACTIVITY.TITLE') }}
    </h3>
    <div
      v-for="entry in activities"
      :key="entry.id"
      class="flex gap-3 p-3 rounded-lg bg-n-alpha-1"
    >
      <Avatar
        :name="entry.user?.name || t('KANBAN.ACTIVITY.SYSTEM')"
        :src="entry.user?.thumbnail || ''"
        :size="32"
        class="flex-shrink-0"
      />
      <div class="flex-1 min-w-0">
        <div class="text-sm text-n-slate-12">
          <span class="font-medium">
            {{ entry.user?.name || t('KANBAN.ACTIVITY.SYSTEM') }}
          </span>
          <span class="text-n-slate-10">
            {{
              t('KANBAN.ACTIVITY.PERFORMED', {
                count: Object.keys(entry.changes || {}).length,
              })
            }}
          </span>
        </div>
        <ul class="mt-1 space-y-1 text-xs text-n-slate-11">
          <li v-for="(values, field) in entry.changes" :key="field">
            {{
              t(fieldKey(field), {
                from: Array.isArray(values) ? values[0] : '',
                to: Array.isArray(values) ? values[1] : values,
              })
            }}
          </li>
        </ul>
        <div class="mt-1 text-xs text-n-slate-9">
          {{ formatRelative(entry.created_at) }}
        </div>
      </div>
    </div>
    <button
      v-if="hasMore"
      class="w-full py-2 text-sm text-n-slate-10 hover:bg-n-alpha-1 rounded-lg disabled:opacity-50"
      :disabled="isLoading"
      @click="loadMore"
    >
      {{
        isLoading
          ? t('KANBAN.ACTIVITY.LOADING')
          : t('KANBAN.ACTIVITY.LOAD_MORE')
      }}
    </button>
    <p
      v-if="!hasMore && activities.length > 0"
      class="text-xs text-n-slate-9 text-center py-2"
    >
      {{ t('KANBAN.ACTIVITY.RETENTION_NOTICE') }}
    </p>
  </section>
</template>
