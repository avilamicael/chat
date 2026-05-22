<script setup>
import { computed, watch, ref, nextTick } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import DeleteDialog from 'dashboard/components-next/captain/pageComponents/DeleteDialog.vue';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import ConnectInboxDialog from 'dashboard/components-next/captain/pageComponents/inbox/ConnectInboxDialog.vue';
import InboxCard from 'dashboard/components-next/captain/assistant/InboxCard.vue';
import InboxPageEmptyState from 'dashboard/components-next/captain/pageComponents/emptyStates/InboxPageEmptyState.vue';

const store = useStore();
const dialogType = ref('');
const route = useRoute();
const { t } = useI18n();

const assistantId = computed(() => route.params.assistantId);
const assistantUiFlags = useMapGetter('captainAssistants/getUIFlags');
const uiFlags = useMapGetter('captainInboxes/getUIFlags');
const isFetchingAssistant = computed(() => assistantUiFlags.value.fetchingItem);
const isFetching = computed(() => uiFlags.value.fetchingList);

const captainInboxes = useMapGetter('captainInboxes/getRecords');

const selectedInbox = ref(null);
const disconnectInboxDialog = ref(null);

const handleDelete = () => {
  disconnectInboxDialog.value.dialogRef.open();
};

const connectInboxDialog = ref(null);

const handleCreate = () => {
  dialogType.value = 'create';
  nextTick(() => connectInboxDialog.value.dialogRef.open());
};
const handleRespondToGroups = async (id, value) => {
  try {
    await store.dispatch('captainInboxes/update', {
      assistantId: assistantId.value,
      inboxId: id,
      respondToGroups: value,
    });
    useAlert(t('CAPTAIN.INBOXES.RESPOND_TO_GROUPS.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('CAPTAIN.INBOXES.RESPOND_TO_GROUPS.ERROR_MESSAGE'));
  }
};

const handleAction = ({ action, id, value }) => {
  if (action === 'updateRespondToGroups') {
    handleRespondToGroups(id, value);
    return;
  }
  selectedInbox.value = captainInboxes.value.find(inbox => id === inbox.id);
  nextTick(() => {
    if (action === 'delete') {
      handleDelete();
    }
  });
};

const handleCreateClose = () => {
  dialogType.value = '';
  selectedInbox.value = null;
};

watch(
  assistantId,
  newId => {
    store.dispatch('captainInboxes/get', {
      assistantId: newId,
    });
  },
  { immediate: true }
);
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.INBOXES.HEADER')"
    :button-label="$t('CAPTAIN.INBOXES.ADD_NEW')"
    :button-policy="['administrator']"
    :is-fetching="isFetchingAssistant || isFetching"
    :is-empty="!captainInboxes.length"
    :show-pagination-footer="false"
    :show-know-more="false"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    @click="handleCreate"
  >
    <template #emptyState>
      <InboxPageEmptyState @click="handleCreate" />
    </template>

    <template #body>
      <div class="flex flex-col gap-4">
        <InboxCard
          v-for="captainInbox in captainInboxes"
          :id="captainInbox.id"
          :key="captainInbox.id"
          :inbox="captainInbox"
          @action="handleAction"
        />
      </div>
    </template>

    <DeleteDialog
      v-if="selectedInbox"
      ref="disconnectInboxDialog"
      :entity="selectedInbox"
      :delete-payload="{
        assistantId: assistantId,
        inboxId: selectedInbox.id,
      }"
      type="Inboxes"
    />

    <ConnectInboxDialog
      v-if="dialogType"
      ref="connectInboxDialog"
      :assistant-id="assistantId"
      :type="dialogType"
      @close="handleCreateClose"
    />
  </PageLayout>
</template>
