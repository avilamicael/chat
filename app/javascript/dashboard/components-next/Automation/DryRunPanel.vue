<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import automationsAPI from 'dashboard/api/automation';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import DryRunResultPanel from './DryRunResultPanel.vue';
import ManualScenarioForm from './ManualScenarioForm.vue';

const props = defineProps({
  rule: { type: Object, required: true },
});

const { t } = useI18n();

const selectedRealEventId = ref('');
const manualOpen = ref(false);
const manualScenario = ref({});
const result = ref(null);
const loading = ref(false);
const error = ref(null);

// Open Q #3 — reset manualScenario when event_name changes
watch(
  () => props.rule.event_name,
  () => {
    manualScenario.value = {};
    selectedRealEventId.value = '';
    result.value = null;
  }
);

// Real events list — bias UI-SPEC §6.6.1: planner pode usar /recent_events ou últimas audits.
// Backend Plan C não criou /recent_events; abordagem v1 = dropdown disabled + texto
// "No recent events to replay." (Open Q #4)
const recentEvents = ref([]);

const realEventsDisabled = computed(() => recentEvents.value.length === 0);

const realEventOptions = computed(() =>
  recentEvents.value.map(e => ({ value: e.id, label: e.label }))
);

const realEventsPlaceholder = computed(() =>
  realEventsDisabled.value
    ? t('AUTOMATION.DRY_RUN.NO_RECENT_EVENTS')
    : t('AUTOMATION.DRY_RUN.REAL_EVENT_PLACEHOLDER')
);

const runTest = async (source, payload) => {
  loading.value = true;
  error.value = null;
  try {
    const { data } = await automationsAPI.dryRun(props.rule.id, payload);
    result.value = { source, ...data.payload };
  } catch (e) {
    error.value = e.response?.data?.error || e.message;
    result.value = null;
  } finally {
    loading.value = false;
  }
};

const runWithRealEvent = () => {
  if (!selectedRealEventId.value) return;
  const event = recentEvents.value.find(
    e => e.id === selectedRealEventId.value
  );
  if (event) runTest('real', event.payload);
};

const runWithManual = () => {
  runTest('manual', manualScenario.value);
};

const manualDisabled = computed(
  () => loading.value || Object.keys(manualScenario.value).length === 0
);
</script>

<template>
  <div class="space-y-6">
    <!-- Path A: Real event -->
    <section>
      <h3
        class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide mb-2"
      >
        {{ t('AUTOMATION.DRY_RUN.REAL_EVENT_HEADER') }}
      </h3>
      <p class="text-body-main text-n-slate-11 mb-2">
        {{ t('AUTOMATION.DRY_RUN.REAL_EVENT_DESC') }}
      </p>
      <ComboBox
        v-model="selectedRealEventId"
        :options="realEventOptions"
        :placeholder="realEventsPlaceholder"
        :disabled="realEventsDisabled"
      />
      <button
        type="button"
        class="text-sm font-medium px-4 py-2 mt-2 rounded-lg bg-n-brand text-white disabled:opacity-50"
        :disabled="!selectedRealEventId || loading"
        @click="runWithRealEvent"
      >
        {{ t('AUTOMATION.DRY_RUN.RUN_BUTTON') }}
      </button>
    </section>

    <!-- Separator + Manual scenario -->
    <hr class="border-n-weak" />
    <section>
      <button
        type="button"
        class="text-sm text-n-brand hover:underline"
        @click="manualOpen = !manualOpen"
      >
        {{
          manualOpen
            ? t('AUTOMATION.DRY_RUN.MANUAL_LINK_CLOSE')
            : t('AUTOMATION.DRY_RUN.MANUAL_LINK')
        }}
      </button>
      <div v-if="manualOpen" class="mt-3 space-y-3">
        <h3 class="text-heading-3 text-n-slate-12">
          {{ t('AUTOMATION.DRY_RUN.MANUAL_HEADER') }}
        </h3>
        <p class="text-body-main text-n-slate-11">
          {{ t('AUTOMATION.DRY_RUN.MANUAL_DESC') }}
        </p>
        <ManualScenarioForm
          v-model="manualScenario"
          :event-name="rule.event_name"
        />
        <button
          type="button"
          class="text-sm font-medium px-4 py-2 rounded-lg bg-n-brand text-white disabled:opacity-50"
          :disabled="manualDisabled"
          @click="runWithManual"
        >
          {{ t('AUTOMATION.DRY_RUN.RUN_BUTTON') }}
        </button>
      </div>
    </section>

    <!-- Result -->
    <DryRunResultPanel :result="result" :loading="loading" :error="error" />
  </div>
</template>
