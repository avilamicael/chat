/* global axios */
import ApiClient from './ApiClient';

class AutomationRuleRunsAPI extends ApiClient {
  constructor() {
    super('automation_rule_runs', { accountScoped: true });
  }

  list(query = {}) {
    return axios.get(this.url, { params: query });
  }
}

export default new AutomationRuleRunsAPI();
