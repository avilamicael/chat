import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store.js';

export function useBilling() {
  const globalConfig = useMapGetter('globalConfig/get');

  const billingBaseUrl = computed(() => globalConfig.value?.billingBaseUrl || '');

  const getBillingUrl = (feature = '') => {
    const base = billingBaseUrl.value;
    if (!base) return '';
    return feature ? `${base}?feature=${feature}` : base;
  };

  const openUpgradePage = (feature = '') => {
    const url = getBillingUrl(feature);
    if (url) window.open(url, '_blank', 'noopener,noreferrer');
  };

  const hasBillingUrl = computed(() => !!billingBaseUrl.value);

  return { billingBaseUrl, getBillingUrl, openUpgradePage, hasBillingUrl };
}
