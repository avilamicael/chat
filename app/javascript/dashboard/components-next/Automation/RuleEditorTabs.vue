<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const props = defineProps({
  runsCount: { type: Number, default: 0 },
});

const emit = defineEmits(['tabChanged']);
const { t } = useI18n();

const activeTab = ref(0);

const tabs = computed(() => [
  {
    id: 'edit',
    label: t('AUTOMATION.FORM.TAB_EDIT'),
    panelId: 'panel-edit',
  },
  {
    id: 'runs',
    label: t('AUTOMATION.FORM.TAB_RUNS'),
    count: props.runsCount || undefined,
    panelId: 'panel-runs',
  },
  {
    id: 'test',
    label: t('AUTOMATION.FORM.TAB_TEST'),
    panelId: 'panel-test',
  },
]);

const onTabChanged = tab => {
  const idx = tabs.value.findIndex(x => x.id === tab.id);
  if (idx >= 0) activeTab.value = idx;
  emit('tabChanged', tab.id);
};
</script>

<template>
  <div>
    <div class="px-6 pt-4">
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTab"
        @tab-changed="onTabChanged"
      />
    </div>
    <div class="px-6 py-4 space-y-6">
      <section
        v-show="activeTab === 0"
        id="panel-edit"
        role="tabpanel"
        aria-labelledby="tab-edit"
      >
        <slot name="edit" />
      </section>
      <section
        v-show="activeTab === 1"
        id="panel-runs"
        role="tabpanel"
        aria-labelledby="tab-runs"
      >
        <slot name="runs" />
      </section>
      <section
        v-show="activeTab === 2"
        id="panel-test"
        role="tabpanel"
        aria-labelledby="tab-test"
      >
        <slot name="test" />
      </section>
    </div>
  </div>
</template>
