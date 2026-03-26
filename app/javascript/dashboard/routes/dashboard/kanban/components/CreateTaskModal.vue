<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store.js';
import DatePicker from 'vue-datepicker-next';
import 'vue-datepicker-next/index.css';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import searchAPI from 'dashboard/api/search.js';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  columns: { type: Array, required: true },
  preselectedColumnId: { type: [String, Number], default: null },
});

const emit = defineEmits(['close', 'created']);

const { t } = useI18n();
const store = useStore();
const agents = useMapGetter('agents/getAgents');

// Form state
const title = ref('');
const description = ref('');
const selectedColumnId = ref(props.preselectedColumnId || props.columns[0]?.id || null);
const selectedPriority = ref(null);
const dueDate = ref('');
const isCreating = ref(false);
const errorMessage = ref('');

// Assignees — TagInput pattern (same as CollaboratorsPage)
const selectedAssigneeIds = ref([]);

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
  }
};

const handleAssigneeRemove = index => {
  selectedAssigneeIds.value.splice(index, 1);
};

// Conversation search
const showConvSearch = ref(false);
const convSearchQuery = ref('');
const convSearchResults = ref([]);
const isSearching = ref(false);
const linkedConversation = ref(null);
let searchTimer = null;

const columnOptions = computed(() =>
  props.columns.map(c => ({ value: c.id, label: c.name }))
);

const priorityOptions = computed(() => [
  { value: 'low', label: t('KANBAN.TASK.PRIORITY_LOW') },
  { value: 'medium', label: t('KANBAN.TASK.PRIORITY_MEDIUM') },
  { value: 'high', label: t('KANBAN.TASK.PRIORITY_HIGH') },
  { value: 'urgent', label: t('KANBAN.TASK.PRIORITY_URGENT') },
]);

const canCreate = computed(() =>
  (title.value.trim() || linkedConversation.value) && selectedColumnId.value
);

const doSearch = async q => {
  if (!q.trim()) {
    convSearchResults.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const { data } = await searchAPI.conversations({ q: q.trim(), page: 1 });
    const convs =
      data?.payload?.conversations || data?.conversations || data?.payload || [];
    convSearchResults.value = Array.isArray(convs) ? convs.slice(0, 6) : [];
  } catch {
    convSearchResults.value = [];
  } finally {
    isSearching.value = false;
  }
};

watch(convSearchQuery, q => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => doSearch(q), 300);
});

const selectConversation = conv => {
  linkedConversation.value = conv;
  convSearchQuery.value = '';
  convSearchResults.value = [];
  if (!title.value.trim()) {
    title.value = conv.meta?.sender?.name || `#${conv.display_id || conv.id}`;
  }
};

const contactName = conv =>
  conv.meta?.sender?.name || conv.contact?.name || `#${conv.id}`;

const createTask = async () => {
  if (!canCreate.value) return;
  isCreating.value = true;
  errorMessage.value = '';
  try {
    const payload = { column_id: selectedColumnId.value };
    if (linkedConversation.value) {
      payload.conversation_id = linkedConversation.value.id;
    } else {
      payload.title = title.value.trim();
    }
    if (description.value.trim()) payload.description = description.value.trim();
    if (selectedPriority.value) payload.priority = selectedPriority.value;
    if (dueDate.value) payload.due_date = new Date(dueDate.value).toISOString();
    if (selectedAssigneeIds.value.length)
      payload.assignee_ids = [...selectedAssigneeIds.value];

    await store.dispatch('kanban/addCard', { boardId: props.boardId, ...payload });
    emit('created');
    emit('close');
  } catch (e) {
    errorMessage.value = e?.response?.data?.message || t('KANBAN.TASK.ERROR_CREATE');
  } finally {
    isCreating.value = false;
  }
};
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-n-slate-12/40"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-xl overflow-hidden">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ t('KANBAN.TASK.CREATE_TITLE') }}
        </h2>
        <button
          class="p-1.5 rounded-lg hover:bg-n-alpha-2 text-n-slate-10"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- Body -->
      <div class="px-6 py-5 space-y-4 max-h-[70vh] overflow-y-auto">
        <!-- Title -->
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
            {{ t('KANBAN.TASK.TITLE_LABEL') }}
          </label>
          <Input
            v-model="title"
            type="text"
            :placeholder="t('KANBAN.TASK.TITLE_PLACEHOLDER')"
            autofocus
          />
        </div>

        <!-- Column + Priority -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
              {{ t('KANBAN.TASK.COLUMN_LABEL') }}
            </label>
            <ComboBox
              v-model="selectedColumnId"
              :options="columnOptions"
              :placeholder="t('KANBAN.TASK.COLUMN_LABEL')"
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

        <!-- Assignees (TagInput — same as inbox agents) -->
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

        <!-- Due date -->
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
            {{ t('KANBAN.TASK.DUE_DATE_LABEL') }}
          </label>
          <DatePicker
            v-model:value="dueDate"
            type="date"
            value-type="YYYY-MM-DD"
            format="DD/MM/YYYY"
            :placeholder="t('KANBAN.TASK.DUE_DATE_LABEL')"
            :disabled-date="date => date < new Date(new Date().setHours(0, 0, 0, 0))"
            append-to-body
            class="w-full"
          />
        </div>

        <!-- Description -->
        <div>
          <label class="block mb-1.5 text-xs font-medium text-n-slate-10">
            {{ t('KANBAN.TASK.DESCRIPTION_LABEL') }}
          </label>
          <textarea
            v-model="description"
            rows="3"
            :placeholder="t('KANBAN.TASK.DESCRIPTION_PLACEHOLDER')"
            class="w-full px-3 py-2 text-sm rounded-xl border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand resize-y min-h-[72px]"
          />
        </div>

        <!-- Link conversation (collapsible) -->
        <div>
          <button
            class="flex items-center gap-1.5 text-xs font-medium text-n-slate-10 hover:text-n-slate-12 mb-2"
            @click="showConvSearch = !showConvSearch"
          >
            <Icon
              :icon="showConvSearch ? 'i-lucide-chevron-down' : 'i-lucide-chevron-right'"
              class="size-3.5"
            />
            {{ t('KANBAN.TASK.LINK_CONVERSATION') }}
          </button>

          <div v-if="showConvSearch" class="relative">
            <!-- Selected conversation chip -->
            <div
              v-if="linkedConversation"
              class="flex items-center gap-2 px-3 py-2 mb-2 rounded-xl border border-n-brand/30 bg-n-brand/5"
            >
              <Icon
                icon="i-lucide-check-circle"
                class="size-4 text-n-brand flex-shrink-0"
              />
              <span class="flex-1 text-sm text-n-slate-12 truncate">
                {{ contactName(linkedConversation) }}
              </span>
              <span class="text-xs text-n-slate-9">
                #{{ linkedConversation.display_id || linkedConversation.id }}
              </span>
              <button
                class="text-n-slate-9 hover:text-n-ruby-9"
                @click="linkedConversation = null"
              >
                <Icon icon="i-lucide-x" class="size-3.5" />
              </button>
            </div>

            <div v-else class="relative">
              <Icon
                icon="i-lucide-search"
                class="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9"
              />
              <input
                v-model="convSearchQuery"
                type="text"
                :placeholder="t('KANBAN.TASK.SEARCH_CONV_PLACEHOLDER')"
                class="w-full h-9 pl-9 pr-3 text-sm rounded-xl border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
              />
              <Icon
                v-if="isSearching"
                icon="i-lucide-loader-circle"
                class="absolute right-3 top-1/2 -translate-y-1/2 size-4 text-n-slate-9 animate-spin"
              />
            </div>

            <div
              v-if="convSearchResults.length"
              class="absolute z-10 mt-1 w-full rounded-xl border border-n-weak bg-n-solid-1 shadow-lg overflow-hidden"
            >
              <button
                v-for="conv in convSearchResults"
                :key="conv.id"
                class="w-full flex items-center gap-3 px-3 py-2.5 text-left hover:bg-n-alpha-2 transition-colors"
                @click="selectConversation(conv)"
              >
                <div class="flex flex-col flex-1 min-w-0">
                  <span class="text-sm font-medium text-n-slate-12 truncate">
                    {{ contactName(conv) }}
                  </span>
                  <span class="text-xs text-n-slate-9">
                    #{{ conv.display_id || conv.id }} · {{ conv.status }}
                  </span>
                </div>
              </button>
            </div>
          </div>
        </div>

        <!-- Error -->
        <p v-if="errorMessage" class="text-xs text-red-500">{{ errorMessage }}</p>
      </div>

      <!-- Footer -->
      <div class="flex justify-end gap-2 px-6 py-4 border-t border-n-weak bg-n-solid-1">
        <button
          class="px-4 py-2 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-alpha-2"
          @click="emit('close')"
        >
          {{ t('KANBAN.TEMPLATE.CANCEL') }}
        </button>
        <button
          class="px-4 py-2 text-sm font-medium rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
          :disabled="!canCreate || isCreating"
          @click="createTask"
        >
          {{ isCreating ? '...' : t('KANBAN.TASK.CREATE_BTN') }}
        </button>
      </div>
    </div>
  </div>
</template>
