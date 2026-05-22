import CaptainInboxes from 'dashboard/api/captain/inboxes';
import { createStore } from '../storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

export default createStore({
  name: 'CaptainInbox',
  API: CaptainInboxes,
  actions: mutations => ({
    update: async function update(
      { commit },
      { inboxId, assistantId, respondToGroups }
    ) {
      commit(mutations.SET_UI_FLAG, { updatingItem: true });
      try {
        const { data } = await CaptainInboxes.update({
          inboxId,
          assistantId,
          respondToGroups,
        });
        commit(mutations.EDIT, data);
        return data;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        commit(mutations.SET_UI_FLAG, { updatingItem: false });
      }
    },
    delete: async function remove({ commit }, { inboxId, assistantId }) {
      commit(mutations.SET_UI_FLAG, { deletingItem: true });
      try {
        await CaptainInboxes.delete({ inboxId, assistantId });
        commit(mutations.DELETE, inboxId);
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return inboxId;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { deletingItem: false });
        return throwErrorMessage(error);
      }
    },
  }),
});
