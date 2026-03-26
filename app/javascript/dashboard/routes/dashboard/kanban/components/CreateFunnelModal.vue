<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const emit = defineEmits(['close', 'create']);

const { t } = useI18n();

const TEMPLATES = [
  {
    key: 'empty',
    icon: 'i-lucide-layout-kanban',
    titleKey: 'KANBAN.TEMPLATE.EMPTY',
    descKey: 'KANBAN.TEMPLATE.EMPTY_DESC',
    disabled: false,
  },
  {
    key: 'sales_funnel',
    icon: 'i-lucide-trending-up',
    titleKey: 'KANBAN.TEMPLATE.SALES_FUNNEL',
    descKey: 'KANBAN.TEMPLATE.SALES_FUNNEL_DESC',
    disabled: false,
  },
  {
    key: 'support_funnel',
    icon: 'i-lucide-headphones',
    titleKey: 'KANBAN.TEMPLATE.SUPPORT',
    descKey: 'KANBAN.TEMPLATE.SUPPORT_DESC',
    disabled: false,
  },
  {
    key: 'others',
    icon: 'i-lucide-more-horizontal',
    titleKey: 'KANBAN.TEMPLATE.OTHERS',
    descKey: 'KANBAN.TEMPLATE.OTHERS_DESC',
    disabled: true,
  },
];

// Step 1 = template selection, Step 2 = name input
const step = ref(1);
const name = ref('');
const selectedTemplate = ref('empty');
const isCreating = ref(false);

const goToNameStep = () => {
  step.value = 2;
};

const handleCreate = async () => {
  if (isCreating.value || !name.value.trim()) return;
  isCreating.value = true;
  try {
    await emit('create', {
      name: name.value.trim(),
      template: selectedTemplate.value,
    });
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
    <div class="w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-xl p-6">
      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-base font-semibold text-n-slate-12">
          {{ step === 1 ? t('KANBAN.TEMPLATE.CHOOSE_TITLE') : t('KANBAN.OVERVIEW.ADD_FUNNEL') }}
        </h2>
        <button
          class="p-1 rounded-lg hover:bg-n-slate-3 text-n-slate-10"
          @click="emit('close')"
        >
          <Icon icon="i-lucide-x" class="size-4" />
        </button>
      </div>

      <!-- Step 1: Template selection -->
      <div v-if="step === 1" class="flex flex-col gap-4">
        <p class="text-sm text-n-slate-10">{{ t('KANBAN.TEMPLATE.CHOOSE_DESCRIPTION') }}</p>

        <div class="grid grid-cols-2 gap-3">
          <button
            v-for="tpl in TEMPLATES"
            :key="tpl.key"
            :disabled="tpl.disabled"
            class="flex flex-col gap-2 p-4 rounded-xl border text-left transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            :class="[
              selectedTemplate === tpl.key && !tpl.disabled
                ? 'border-n-brand bg-n-brand/5'
                : 'border-n-weak hover:border-n-brand/50',
            ]"
            @click="!tpl.disabled && (selectedTemplate = tpl.key)"
          >
            <Icon
              :icon="tpl.icon"
              class="size-5"
              :class="selectedTemplate === tpl.key ? 'text-n-brand' : 'text-n-slate-10'"
            />
            <div>
              <p class="text-sm font-medium text-n-slate-12">{{ t(tpl.titleKey) }}</p>
              <p class="text-xs text-n-slate-10 mt-0.5">{{ t(tpl.descKey) }}</p>
            </div>
          </button>
        </div>

        <div class="flex justify-end gap-2 mt-2">
          <button
            class="px-4 py-2 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-slate-3"
            @click="emit('close')"
          >
            {{ t('KANBAN.TEMPLATE.CANCEL') }}
          </button>
          <button
            class="px-4 py-2 text-sm rounded-lg bg-n-brand text-white hover:bg-n-brand/90"
            @click="goToNameStep"
          >
            {{ t('KANBAN.TEMPLATE.NEXT') }}
          </button>
        </div>
      </div>

      <!-- Step 2: Funnel name -->
      <div v-else class="flex flex-col gap-4">
        <div>
          <label class="block mb-1.5 text-sm font-medium text-n-slate-11">
            {{ t('KANBAN.TEMPLATE.FUNNEL_NAME_LABEL') }}
          </label>
          <input
            v-model="name"
            type="text"
            :placeholder="t('KANBAN.TEMPLATE.FUNNEL_NAME_PLACEHOLDER')"
            class="w-full px-3 py-2 text-sm rounded-lg border border-n-weak bg-n-solid-2 text-n-slate-12 focus:outline-none focus:border-n-brand"
            autofocus
            @keyup.enter="handleCreate"
          />
        </div>

        <div class="flex justify-between gap-2 mt-2">
          <button
            class="px-4 py-2 text-sm rounded-lg border border-n-weak text-n-slate-11 hover:bg-n-slate-3"
            @click="step = 1"
          >
            {{ t('KANBAN.TEMPLATE.BACK') }}
          </button>
          <button
            class="px-4 py-2 text-sm rounded-lg bg-n-brand text-white hover:bg-n-brand/90 disabled:opacity-50"
            :disabled="isCreating || !name.trim()"
            @click="handleCreate"
          >
            {{ t('KANBAN.TEMPLATE.CREATE') }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
