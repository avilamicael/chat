<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import ColumnActionItem from './ColumnActionItem.vue';
import ColumnActionWebhookForm from './ColumnActionWebhookForm.vue';
import ColumnActionMessageForm from './ColumnActionMessageForm.vue';

const props = defineProps({
  enterActions: { type: Array, default: () => [] },
  exitActions: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:enterActions', 'update:exitActions']);

const { t } = useI18n();

const SUPPORTED_TYPES = ['send_webhook_event', 'send_message'];
const LEGACY_TYPES = [
  'auto_create_task',
  'auto_assign_agent',
  'auto_assign_conversation',
  'send_webhook',
];

const isLegacyAction = a => LEGACY_TYPES.includes(a?.action_name);
const isSupportedAction = a => SUPPORTED_TYPES.includes(a?.action_name);
const isEditableAction = a => isSupportedAction(a) || isLegacyAction(a);

const visibleEnterActions = computed(() =>
  props.enterActions.filter(isEditableAction)
);
const visibleExitActions = computed(() =>
  props.exitActions.filter(isEditableAction)
);

const hasLegacyActions = computed(() =>
  [...props.enterActions, ...props.exitActions].some(isLegacyAction)
);

const ACTION_TYPES = computed(() => [
  {
    id: 'send_webhook_event',
    label: t('KANBAN.COLUMN.ACTION_TYPE_WEBHOOK'),
    description: t('KANBAN.COLUMN.ACTION_TYPE_WEBHOOK_DESC'),
    icon: 'i-lucide-webhook',
    disabled: false,
  },
  {
    id: 'send_message',
    label: t('KANBAN.COLUMN.ACTION_TYPE_SEND_MESSAGE'),
    description: t('KANBAN.COLUMN.ACTION_TYPE_SEND_MESSAGE_DESC'),
    icon: 'i-lucide-message-square',
    disabled: false,
  },
  {
    id: 'call_external_api',
    label: t('KANBAN.COLUMN.ACTION_TYPE_EXTERNAL_API'),
    description: t('KANBAN.COLUMN.ACTION_TYPE_EXTERNAL_API_DESC'),
    icon: 'i-lucide-globe',
    disabled: true,
    comingSoonTooltip: t('KANBAN.COLUMN.ACTION_TYPE_EXTERNAL_API_TOOLTIP'),
  },
  {
    id: 'start_workflow',
    label: t('KANBAN.COLUMN.ACTION_TYPE_WORKFLOW'),
    description: t('KANBAN.COLUMN.ACTION_TYPE_WORKFLOW_DESC'),
    icon: 'i-lucide-git-branch',
    disabled: true,
    comingSoonTooltip: t('KANBAN.COLUMN.ACTION_TYPE_WORKFLOW_TOOLTIP'),
  },
]);

// Editing state: { section: 'enter'|'exit', index: number|'new', type, draft }
const editing = ref(null);

// Which section's picker is currently open ('enter' | 'exit' | null)
const pickerOpen = ref(null);

const defaultDraft = type => {
  if (type === 'send_webhook_event') {
    return { url: '', method: 'POST', headers: {}, body: '' };
  }
  if (type === 'send_message') {
    return { content: '', inbox_id: null };
  }
  return {};
};

const sectionActions = section =>
  section === 'enter' ? props.enterActions : props.exitActions;

const updateSection = (section, list) => {
  if (section === 'enter') {
    emit('update:enterActions', list);
  } else {
    emit('update:exitActions', list);
  }
};

const startNewAction = (section, type) => {
  if (type.disabled) return;
  pickerOpen.value = null;
  editing.value = {
    section,
    index: 'new',
    type: type.id,
    draft: defaultDraft(type.id),
  };
};

const editAction = (section, index) => {
  const list = sectionActions(section);
  const action = list[index];
  if (!action) return;
  if (!isSupportedAction(action)) return; // legacy — not editable
  editing.value = {
    section,
    index,
    type: action.action_name,
    draft: { ...(action.action_params || {}) },
  };
};

const saveAction = () => {
  if (!editing.value) return;
  const { section, index, type, draft } = editing.value;
  const list = [...sectionActions(section)];
  const newAction = { action_name: type, action_params: draft };
  if (index === 'new') {
    list.push(newAction);
  } else {
    list[index] = newAction;
  }
  updateSection(section, list);
  editing.value = null;
};

const cancelEditing = () => {
  editing.value = null;
};

// eslint-disable-next-line no-alert
const confirmRemove = () =>
  window.confirm(t('KANBAN.COLUMN.ACTION_REMOVE_CONFIRM_BODY'));

const removeAction = (section, index) => {
  if (!confirmRemove()) return;
  const list = [...sectionActions(section)];
  list.splice(index, 1);
  updateSection(section, list);
  if (
    editing.value &&
    editing.value.section === section &&
    editing.value.index === index
  ) {
    editing.value = null;
  }
};

const togglePicker = section => {
  pickerOpen.value = pickerOpen.value === section ? null : section;
};

const closePicker = () => {
  pickerOpen.value = null;
};

const updateDraft = value => {
  if (editing.value) editing.value.draft = value;
};

const formComponent = type =>
  type === 'send_webhook_event'
    ? ColumnActionWebhookForm
    : ColumnActionMessageForm;
</script>

<template>
  <div class="space-y-6">
    <p
      v-if="hasLegacyActions"
      class="text-label-small text-n-amber-11 italic px-1"
    >
      {{ t('KANBAN.COLUMN.LEGACY_ACTION_WARNING') }}
    </p>

    <section
      v-for="section in ['enter', 'exit']"
      :key="section"
      class="space-y-3"
    >
      <h3 class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
        {{
          section === 'enter'
            ? t('KANBAN.COLUMN.ENTER_ACTIONS_HEADING')
            : t('KANBAN.COLUMN.EXIT_ACTIONS_HEADING')
        }}
      </h3>

      <div
        v-if="
          (section === 'enter' ? visibleEnterActions : visibleExitActions)
            .length === 0
        "
        class="px-4 py-8 text-center text-body-main text-n-slate-11 outline outline-1 -outline-offset-1 outline-dashed outline-n-weak rounded-xl"
      >
        {{ t('KANBAN.COLUMN.ACTIONS_EMPTY') }}
      </div>

      <div v-else class="space-y-2" role="list">
        <template
          v-for="(action, idx) in section === 'enter'
            ? props.enterActions
            : props.exitActions"
          :key="`${section}-${idx}`"
        >
          <template v-if="isEditableAction(action)">
            <ColumnActionItem
              :action="action"
              :is-editing="
                editing && editing.section === section && editing.index === idx
              "
              :is-legacy="isLegacyAction(action)"
              @edit="editAction(section, idx)"
              @remove="removeAction(section, idx)"
            />
            <component
              :is="formComponent(editing.type)"
              v-if="
                editing && editing.section === section && editing.index === idx
              "
              :model-value="editing.draft"
              @update:model-value="updateDraft"
              @save="saveAction"
              @cancel="cancelEditing"
            />
          </template>
        </template>
      </div>

      <component
        :is="formComponent(editing.type)"
        v-if="editing && editing.section === section && editing.index === 'new'"
        :model-value="editing.draft"
        @update:model-value="updateDraft"
        @save="saveAction"
        @cancel="cancelEditing"
      />

      <div class="relative">
        <button
          type="button"
          class="px-3 py-1.5 text-sm rounded-lg text-n-brand hover:bg-n-alpha-1 inline-flex items-center gap-1"
          aria-haspopup="menu"
          :aria-expanded="pickerOpen === section"
          @click="togglePicker(section)"
        >
          <Icon icon="i-lucide-plus" class="size-3.5" />
          {{ t('KANBAN.COLUMN.ADD_ACTION') }}
        </button>

        <OnClickOutside
          v-if="pickerOpen === section"
          :options="{ ignore: [] }"
          @trigger="closePicker"
        >
          <div
            role="menu"
            class="absolute left-0 top-full mt-1 z-20 w-80 bg-n-solid-1 border border-n-weak rounded-xl shadow-lg overflow-hidden"
          >
            <p
              class="px-4 py-3 text-xs font-semibold text-n-slate-11 uppercase tracking-wide border-b border-n-weak"
            >
              {{ t('KANBAN.COLUMN.ACTION_PICKER_TITLE') }}
            </p>
            <button
              v-for="type in ACTION_TYPES"
              :key="type.id"
              type="button"
              role="menuitem"
              :title="type.comingSoonTooltip || ''"
              :aria-disabled="type.disabled ? 'true' : undefined"
              :tabindex="type.disabled ? -1 : 0"
              class="flex items-start gap-3 px-4 py-3 w-full text-left transition-colors duration-150 border-0"
              :class="
                type.disabled
                  ? 'cursor-not-allowed bg-n-alpha-1 text-n-slate-11'
                  : 'cursor-pointer hover:bg-n-alpha-2 text-n-slate-12'
              "
              :disabled="type.disabled"
              @click="startNewAction(section, type)"
            >
              <Icon
                :icon="type.icon"
                class="size-4 mt-0.5 flex-shrink-0"
                :class="type.disabled ? 'text-n-slate-10' : 'text-n-slate-11'"
              />
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-heading-3">{{ type.label }}</span>
                  <span
                    v-if="type.disabled"
                    class="text-xs px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-11"
                  >
                    {{ t('KANBAN.COLUMN.COMING_SOON_CHIP') }}
                  </span>
                </div>
                <p class="text-label-small text-n-slate-11 mt-0.5">
                  {{ type.description }}
                </p>
              </div>
            </button>
          </div>
        </OnClickOutside>
      </div>
    </section>
  </div>
</template>
