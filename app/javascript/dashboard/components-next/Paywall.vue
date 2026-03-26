<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store.js';
import { useBilling } from 'shared/composables/useBilling.js';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  titleKey: { type: String, required: true },
  descriptionKey: { type: String, required: true },
  upgradePromptKey: { type: String, default: '' },
  nonAdminKey: { type: String, default: '' },
  feature: { type: String, default: '' },
});

const { t } = useI18n();
const { openUpgradePage, hasBillingUrl } = useBilling();

const currentUser = useMapGetter('getCurrentUser');
const isSuperAdmin = computed(() => currentUser.value?.type === 'SuperAdmin');

const showUpgradeButton = computed(() => isSuperAdmin.value && hasBillingUrl.value);

const onUpgradeClick = () => openUpgradePage(props.feature);
</script>

<template>
  <section
    class="flex flex-col items-center justify-center w-full h-full bg-n-surface-1"
  >
    <div
      class="flex flex-col max-w-md px-6 py-6 border shadow bg-n-solid-1 rounded-xl border-n-weak"
    >
      <div class="flex items-center w-full gap-2 mb-4">
        <span
          class="flex items-center justify-center w-6 h-6 rounded-full bg-n-solid-blue"
        >
          <Icon
            class="flex-shrink-0 text-n-brand size-[14px]"
            icon="i-lucide-lock-keyhole"
          />
        </span>
        <span class="text-base font-medium text-n-slate-12">
          {{ t(titleKey) }}
        </span>
      </div>

      <template v-if="isSuperAdmin">
        <p class="mb-3 text-sm font-normal text-n-slate-11">
          {{ t(descriptionKey) }}
        </p>
        <p v-if="upgradePromptKey" class="mb-4 text-sm font-normal text-n-slate-11">
          {{ t(upgradePromptKey) }}
        </p>
        <Button
          v-if="showUpgradeButton"
          solid
          blue
          md
          class="w-full"
          @click="onUpgradeClick"
        >
          {{ t('KANBAN.PAYWALL.UPGRADE_NOW') }}
        </Button>
      </template>

      <template v-else>
        <p class="mb-4 text-sm font-normal text-n-slate-11">
          {{ nonAdminKey ? t(nonAdminKey) : t('KANBAN.PAYWALL.NON_ADMIN_MESSAGE') }}
        </p>
      </template>
    </div>
  </section>
</template>
