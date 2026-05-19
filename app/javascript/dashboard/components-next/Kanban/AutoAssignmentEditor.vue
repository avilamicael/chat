<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  modelValue: {
    type: Object,
    required: true,
    // shape: { enabled, online_only, override, reassign_on_return, max_cards_per_agent }
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();

const update = (key, value) => {
  emit('update:modelValue', { ...props.modelValue, [key]: value });
};

const subDisabled = computed(() => !props.modelValue.enabled);

const maxCardsValue = computed({
  get: () => {
    const v = props.modelValue.max_cards_per_agent;
    return v === null || v === undefined ? '' : v;
  },
  set: v => {
    if (v === '' || v === null || v === undefined) {
      update('max_cards_per_agent', null);
      return;
    }
    const n = Number(v);
    update('max_cards_per_agent', Number.isFinite(n) ? n : null);
  },
});
</script>

<template>
  <div class="space-y-3">
    <SettingsToggleSection
      :model-value="modelValue.enabled"
      :header="t('KANBAN.COLUMN.AUTO_ASSIGN_ENABLE_HEADER')"
      :description="t('KANBAN.COLUMN.AUTO_ASSIGN_ENABLE_DESC')"
      @update:model-value="v => update('enabled', v)"
    />
    <div
      class="space-y-3"
      :class="[{ 'opacity-50 pointer-events-none': subDisabled }]"
      :aria-disabled="subDisabled"
    >
      <SettingsToggleSection
        :model-value="modelValue.online_only"
        :header="t('KANBAN.COLUMN.AUTO_ASSIGN_ONLINE_ONLY_HEADER')"
        :description="t('KANBAN.COLUMN.AUTO_ASSIGN_ONLINE_ONLY_DESC')"
        @update:model-value="v => update('online_only', v)"
      />
      <SettingsToggleSection
        :model-value="modelValue.override"
        :header="t('KANBAN.COLUMN.AUTO_ASSIGN_OVERRIDE_HEADER')"
        :description="t('KANBAN.COLUMN.AUTO_ASSIGN_OVERRIDE_DESC')"
        @update:model-value="v => update('override', v)"
      />
      <SettingsToggleSection
        :model-value="modelValue.reassign_on_return"
        :header="t('KANBAN.COLUMN.AUTO_ASSIGN_REASSIGN_ON_RETURN_HEADER')"
        :description="t('KANBAN.COLUMN.AUTO_ASSIGN_REASSIGN_ON_RETURN_DESC')"
        @update:model-value="v => update('reassign_on_return', v)"
      />
      <div
        class="px-4 py-3 outline outline-1 -outline-offset-1 outline-n-weak rounded-xl"
      >
        <label
          for="auto-assign-max-cards"
          class="text-heading-3 text-n-slate-12 block mb-1"
        >
          {{ t('KANBAN.COLUMN.AUTO_ASSIGN_MAX_CARDS_LABEL') }}
        </label>
        <Input
          id="auto-assign-max-cards"
          v-model="maxCardsValue"
          type="number"
          min="1"
          :placeholder="t('KANBAN.COLUMN.AUTO_ASSIGN_MAX_CARDS_PLACEHOLDER')"
          custom-input-class="max-w-xs"
        />
        <p class="text-label-small text-n-slate-11 mt-1">
          {{ t('KANBAN.COLUMN.AUTO_ASSIGN_MAX_CARDS_HINT') }}
        </p>
      </div>
    </div>
  </div>
</template>
