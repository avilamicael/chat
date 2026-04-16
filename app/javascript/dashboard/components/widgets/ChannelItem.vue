<script setup>
import { computed } from 'vue';
import ChannelSelector from '../ChannelSelector.vue';

const props = defineProps({
  channel: {
    type: Object,
    required: true,
  },
  enabledFeatures: {
    type: Object,
    required: true,
  },
  allowedChannels: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['channelItemClick']);

const hasFbConfigured = computed(() => {
  return window.chatwootConfig?.fbAppId;
});

const hasInstagramConfigured = computed(() => {
  return window.chatwootConfig?.instagramAppId;
});

const hasTiktokConfigured = computed(() => {
  return window.chatwootConfig?.tiktokAppId;
});

const isActive = computed(() => {
  const { key } = props.channel;
  if (Object.keys(props.enabledFeatures).length === 0) {
    return false;
  }
  if (key === 'website') {
    return props.enabledFeatures.channel_website;
  }
  if (key === 'facebook') {
    return props.enabledFeatures.channel_facebook && hasFbConfigured.value;
  }
  if (key === 'email') {
    return props.enabledFeatures.channel_email;
  }

  if (key === 'instagram') {
    return (
      props.enabledFeatures.channel_instagram && hasInstagramConfigured.value
    );
  }

  if (key === 'tiktok') {
    return props.enabledFeatures.channel_tiktok && hasTiktokConfigured.value;
  }

  if (key === 'voice') {
    return props.enabledFeatures.channel_voice;
  }

  // Channels gated per plan via account.custom_attributes.allowed_channels.
  // An empty/missing array means "no restriction" (backwards compatible).
  const GATED_CHANNELS = ['whatsapp', 'telegram', 'sms', 'api', 'line'];
  if (GATED_CHANNELS.includes(key)) {
    const allowed = props.allowedChannels;
    if (Array.isArray(allowed) && allowed.length > 0) {
      return allowed.includes(key);
    }
    return true;
  }

  return ['website', 'twilio'].includes(key);
});

const isComingSoon = computed(() => {
  const { key } = props.channel;
  // Show "Coming Soon" only if the channel is marked as coming soon
  // and the corresponding feature flag is not enabled yet.
  return ['voice'].includes(key) && !isActive.value;
});

const onItemClick = () => {
  if (isActive.value) {
    emit('channelItemClick', props.channel.key);
  }
};
</script>

<template>
  <ChannelSelector
    :title="channel.title"
    :description="channel.description"
    :icon="channel.icon"
    :is-coming-soon="isComingSoon"
    :disabled="!isActive"
    @click="onItemClick"
  />
</template>
