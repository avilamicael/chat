<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import kanbanAPI from 'dashboard/api/kanban.js';
import searchAPI from 'dashboard/api/search.js';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  columns: { type: Array, required: true },
});

const emit = defineEmits(['close', 'added']);

const { t } = useI18n();

const selectedColumnId = ref(props.columns[0]?.id ?? null);
const columnOptions = computed(() => props.columns.map(c => ({ value: c.id, label: c.name })));
const searchQuery = ref('');
const searchResults = ref([]);
const selectedConversation = ref(null);
const isSearching = ref(false);
const isAdding = ref(false);
const errorMessage = ref('');

let searchTimer = null;

const doSearch = async q => {
  if (!q.trim()) {
    searchResults.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const { data } = await searchAPI.conversations({ q: q.trim(), page: 1 });
    // API returns { payload: { conversations: [...] } } or just an array
    const convs =
      data?.payload?.conversations ||
      data?.conversations ||
      data?.payload ||
      [];
    searchResults.value = Array.isArray(convs) ? convs.slice(0, 8) : [];
  } catch {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

watch(searchQuery, q => {
  selectedConversation.value = null;
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => doSearch(q), 300);
});

const selectConversation = conv => {
  selectedConversation.value = conv;
  searchQuery.value =
    conv.meta?.sender?.name ||
    `#${conv.id}`;
  searchResults.value = [];
};

const contactName = conv =>
  conv.meta?.sender?.name || conv.contact?.name || `#${conv.id}`;

const addCard = async () => {
  if (!selectedConversation.value || !selectedColumnId.value) return;
  isAdding.value = true;
  errorMessage.value = '';
  try {
    await kanbanAPI.addCard(props.boardId, {
      column_id: selectedColumnId.value,
      conversation_id: selectedConversation.value.id,
    });
    emit('added');
    emit('close');
  } catch (e) {
    const msg = e?.response?.data?.message || e?.response?.data?.error;
    errorMessage.value = msg || t('KANBAN.ADD_CARD.ERROR');
  } finally {
    isAdding.value = false;
  }
};

const canAdd = computed(
  () => !!selectedConversation.value && !!selectedColumnId.value
);
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-md bg-n-solid-1 rounded-2xl shadow-xl p-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-5">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('KANBAN.ADD_CARD.TITLE') }}
        </h2>
        <button
          class="p-1 rounded-lg hover:bg-n-alpha-2 text-n-slate-10"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- Column select -->
      <div class="mb-4">
        <label class="block mb-1.5 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.ADD_CARD.COLUMN') }}
        </label>
        <ComboBox
          v-model="selectedColumnId"
          :options="columnOptions"
          :placeholder="t('KANBAN.ADD_CARD.COLUMN')"
        />
      </div>

      <!-- Conversation search -->
      <div class="mb-2 relative">
        <label class="block mb-1.5 text-xs font-medium text-n-slate-11">
          {{ t('KANBAN.ADD_CARD.SEARCH_CONVERSATION') }}
        </label>
        <div class="relative">
          <Icon
            icon="i-lucide-search"
            class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9"
          />
          <input
            v-model="searchQuery"
            type="text"
            class="w-full h-9 pl-9 pr-3 text-sm rounded-lg border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
            :placeholder="t('KANBAN.ADD_CARD.SEARCH_PLACEHOLDER')"
            autofocus
          />
          <Icon
            v-if="isSearching"
            icon="i-lucide-loader-circle"
            class="absolute right-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9 animate-spin"
          />
        </div>

        <!-- Dropdown results -->
        <div
          v-if="searchResults.length"
          class="absolute z-10 mt-1 w-full rounded-lg border border-n-weak bg-n-solid-1 shadow-lg overflow-hidden"
        >
          <button
            v-for="conv in searchResults"
            :key="conv.id"
            class="w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-n-alpha-2 transition-colors"
            @click="selectConversation(conv)"
          >
            <div class="flex flex-col flex-1 min-w-0">
              <span class="text-sm font-medium text-n-slate-12 truncate">
                {{ contactName(conv) }}
              </span>
              <span class="text-xs text-n-slate-9">
                #{{ conv.display_id || conv.id }} ·
                {{ conv.status }}
              </span>
            </div>
          </button>
        </div>

        <!-- No results -->
        <p
          v-else-if="searchQuery.trim() && !isSearching && !selectedConversation"
          class="mt-1.5 text-xs text-n-slate-9"
        >
          {{ t('KANBAN.ADD_CARD.NO_RESULTS') }}
        </p>
      </div>

      <!-- Selected conversation preview -->
      <div
        v-if="selectedConversation"
        class="mb-4 flex items-center gap-2 px-3 py-2 rounded-lg border border-n-brand/30 bg-n-brand/5"
      >
        <Icon icon="i-lucide-check-circle" class="size-4 text-n-brand flex-shrink-0" />
        <span class="text-sm text-n-slate-12 truncate">
          {{ contactName(selectedConversation) }}
        </span>
        <span class="text-xs text-n-slate-9 ml-auto flex-shrink-0">
          #{{ selectedConversation.display_id || selectedConversation.id }}
        </span>
      </div>

      <!-- Error -->
      <p v-if="errorMessage" class="mb-3 text-xs text-red-500">
        {{ errorMessage }}
      </p>

      <!-- Actions -->
      <div class="flex justify-end gap-2">
        <button
          class="px-4 py-2 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          {{ t('KANBAN.TEMPLATE.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
          :disabled="!canAdd || isAdding"
          @click="addCard"
        >
          {{ t('KANBAN.ADD_CARD.ADD_BTN') }}
        </button>
      </div>
    </div>
  </div>
</template>
