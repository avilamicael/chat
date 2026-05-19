<script setup>
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
</script>

<template>
  <span
    :title="t('AUTOMATION.LIST.RISK_TOOLTIP')"
    :aria-label="t('AUTOMATION.LIST.RISK_TOOLTIP')"
    class="inline-flex items-center"
  >
    <Icon
      icon="i-lucide-alert-triangle"
      class="size-4 text-amber-500"
      aria-hidden="true"
    />
  </span>
</template>
