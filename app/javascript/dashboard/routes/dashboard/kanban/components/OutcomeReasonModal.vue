<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  columnType: { type: String, required: true }, // 'won' | 'lost'
  cardTitle: { type: String, default: '' },
});

const emit = defineEmits(['confirm', 'cancel']);

const { t } = useI18n();
const reason = ref('');
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40">
    <div class="w-full max-w-md bg-n-solid-1 rounded-2xl shadow-xl">
      <!-- Header -->
      <div class="flex items-center gap-3 px-6 pt-5 pb-4 border-b border-n-weak">
        <Icon
          :icon="columnType === 'won' ? 'i-lucide-trophy' : 'i-lucide-x-circle'"
          :class="columnType === 'won' ? 'text-green-500' : 'text-red-500'"
          class="size-5 flex-shrink-0"
        />
        <h2 class="text-base font-semibold text-n-slate-12">
          {{
            columnType === 'won'
              ? t('KANBAN.OUTCOME_REASON_MODAL.TITLE_WON')
              : t('KANBAN.OUTCOME_REASON_MODAL.TITLE_LOST')
          }}
        </h2>
      </div>

      <!-- Body -->
      <div class="px-6 py-4 flex flex-col gap-3">
        <p class="text-sm text-n-slate-10">
          {{ t('KANBAN.OUTCOME_REASON_MODAL.DESCRIPTION') }}
        </p>
        <p v-if="cardTitle" class="text-sm font-medium text-n-slate-12 truncate">
          {{ cardTitle }}
        </p>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-medium text-n-slate-10 uppercase tracking-wide">
            {{ t('KANBAN.OUTCOME_REASON_MODAL.REASON_LABEL') }}
          </label>
          <textarea
            v-model="reason"
            :placeholder="t('KANBAN.ARCHIVE.REASON_PLACEHOLDER')"
            class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand resize-none h-24"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-end gap-2 px-6 pb-5">
        <button
          class="px-4 py-2 text-sm font-medium rounded-lg text-n-slate-10 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="emit('cancel')"
        >
          {{ t('KANBAN.OUTCOME_REASON_MODAL.CANCEL') }}
        </button>
        <button
          :class="
            columnType === 'won'
              ? 'bg-green-600 hover:bg-green-700'
              : 'bg-red-600 hover:bg-red-700'
          "
          class="px-4 py-2 text-sm font-medium rounded-lg text-white transition-colors"
          @click="emit('confirm', reason)"
        >
          {{ t('KANBAN.OUTCOME_REASON_MODAL.CONFIRM') }}
        </button>
      </div>
    </div>
  </div>
</template>
