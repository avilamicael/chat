<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  result: { type: Object, default: null },
  loading: { type: Boolean, default: false },
  error: { type: String, default: null },
});

const { t } = useI18n();

const previewActions = computed(() => props.result?.actions_preview || []);

const resolvedJsonOf = action =>
  action?.resolved_params
    ? JSON.stringify(action.resolved_params, null, 2)
    : '';
</script>

<template>
  <section aria-live="polite" class="space-y-3">
    <h3 class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide">
      {{ t('AUTOMATION.DRY_RUN.RESULT_HEADING') }}
    </h3>

    <div v-if="loading" class="py-6 text-center text-body-main text-n-slate-9">
      <Icon
        icon="i-lucide-loader-2"
        class="size-5 animate-spin text-n-brand mx-auto"
        aria-hidden="true"
      />
      <p class="mt-2">{{ t('AUTOMATION.DRY_RUN.LOADING') }}</p>
    </div>

    <div
      v-else-if="error"
      class="py-4 px-3 rounded-lg bg-red-500/10 text-body-main text-n-ruby-9"
    >
      {{ t('AUTOMATION.DRY_RUN.ERROR_PREFIX') }} {{ error }}
    </div>

    <div v-else-if="!result" class="py-12 text-center">
      <Icon
        icon="i-lucide-play-circle"
        class="size-8 text-n-slate-7 mx-auto"
        aria-hidden="true"
      />
      <p class="text-heading-3 text-n-slate-11 mt-2">
        {{ t('AUTOMATION.DRY_RUN.EMPTY_TITLE') }}
      </p>
      <p class="text-body-main text-n-slate-9 mt-1">
        {{ t('AUTOMATION.DRY_RUN.EMPTY_STATE') }}
      </p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-if="result.matched"
        class="flex items-center gap-2 text-emerald-500"
      >
        <Icon
          icon="i-lucide-check-circle-2"
          class="size-4"
          aria-hidden="true"
        />
        <span class="text-heading-3">
          {{ t('AUTOMATION.DRY_RUN.CONDITIONS_MATCHED') }}
        </span>
      </div>
      <div v-else class="flex items-center gap-2 text-n-slate-9">
        <Icon icon="i-lucide-x-circle" class="size-4" aria-hidden="true" />
        <span class="text-heading-3">
          {{ t('AUTOMATION.DRY_RUN.CONDITIONS_NOT_MATCHED') }}
        </span>
      </div>

      <div v-if="result.matched && previewActions.length > 0">
        <p class="text-body-main text-n-slate-11 mb-2">
          {{ t('AUTOMATION.DRY_RUN.ACTIONS_HEADER') }}
        </p>
        <div
          v-for="action in previewActions"
          :key="action.action_index"
          class="outline outline-1 outline-n-weak rounded-xl p-4 bg-n-solid-2 mb-2"
        >
          <p class="text-heading-3 text-n-slate-12">
            {{ action.action_name }}
          </p>
          <p
            v-if="action.resolved_content"
            class="text-body-main text-n-slate-11 mt-1"
          >
            {{ `"${action.resolved_content}"` }}
          </p>
          <details v-if="action.resolved_params" class="mt-2">
            <summary class="text-xs text-n-brand cursor-pointer">
              {{ t('AUTOMATION.DRY_RUN.RESOLVED_PAYLOAD_LABEL') }}
            </summary>
            <pre
              class="text-xs font-mono mt-2 p-2 bg-n-alpha-1 rounded overflow-x-auto whitespace-pre-wrap"
            ><code>{{ resolvedJsonOf(action) }}</code></pre>
          </details>
          <p
            v-if="action.would_block_24h"
            class="text-xs text-amber-600 mt-1 inline-flex items-center gap-1"
          >
            <Icon icon="i-lucide-shield" class="size-3" aria-hidden="true" />
            {{ t('AUTOMATION.DRY_RUN.WOULD_BLOCK_24H') }}
          </p>
        </div>
      </div>

      <p class="text-xs text-n-slate-9 italic">
        {{ t('AUTOMATION.DRY_RUN.NOT_PERSISTED_HINT') }}
      </p>
    </div>
  </section>
</template>
