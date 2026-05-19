/* global axios */
import ApiClient from './ApiClient';

class AutomationsAPI extends ApiClient {
  constructor() {
    super('automation_rules', { accountScoped: true });
  }

  clone(automationId) {
    return axios.post(`${this.url}/${automationId}/clone`);
  }

  dryRun(automationId, eventPayload) {
    return axios.post(`${this.url}/${automationId}/dry_run`, {
      event_payload: eventPayload,
    });
  }

  listRuns(automationId, query = {}) {
    return axios.get(`${this.url}/${automationId}/runs`, { params: query });
  }
}

export default new AutomationsAPI();
