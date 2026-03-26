import ApiClient from './ApiClient';

class KanbanAPI extends ApiClient {
  constructor() {
    super('kanban_boards', { accountScoped: true });
  }

  getBoards() {
    return axios.get(this.url);
  }

  getBoard(boardId) {
    return axios.get(`${this.url}/${boardId}`);
  }

  createBoard({ template, ...data }) {
    return axios.post(this.url, { kanban_board: data, template });
  }

  updateBoard(boardId, data) {
    return axios.patch(`${this.url}/${boardId}`, { kanban_board: data });
  }

  deleteBoard(boardId) {
    return axios.delete(`${this.url}/${boardId}`);
  }

  getColumns(boardId) {
    return axios.get(`${this.url}/${boardId}/columns`);
  }

  createColumn(boardId, data) {
    return axios.post(`${this.url}/${boardId}/columns`, { kanban_column: data });
  }

  updateColumn(boardId, columnId, data) {
    return axios.patch(`${this.url}/${boardId}/columns/${columnId}`, {
      kanban_column: data,
    });
  }

  deleteColumn(boardId, columnId) {
    return axios.delete(`${this.url}/${boardId}/columns/${columnId}`);
  }

  reorderColumns(boardId, columns) {
    return axios.patch(`${this.url}/${boardId}/columns/reorder`, { columns });
  }

  getCards(boardId, params = {}) {
    return axios.get(`${this.url}/${boardId}/cards`, { params });
  }

  addCard(boardId, data) {
    return axios.post(`${this.url}/${boardId}/cards`, { kanban_card: data });
  }

  removeCard(boardId, cardId) {
    return axios.delete(`${this.url}/${boardId}/cards/${cardId}`);
  }

  moveCard(boardId, cardId, { column_id, position, outcome_reason }) {
    return axios.patch(`${this.url}/${boardId}/cards/${cardId}/move`, {
      kanban_card: { column_id, position, outcome_reason },
    });
  }

  updateCard(boardId, cardId, data) {
    return axios.patch(`${this.url}/${boardId}/cards/${cardId}`, {
      kanban_card: data,
    });
  }

  getArchivedCards(boardId, params = {}) {
    return axios.get(`${this.url}/${boardId}/cards/archived`, { params });
  }

  getConversationCard(conversationId) {
    return axios.get(`${this.url}/conversation_card`, {
      params: { conversation_id: conversationId },
    });
  }

  getCardActivities(boardId, cardId) {
    return axios.get(`${this.url}/${boardId}/cards/${cardId}/activities`);
  }
}

export default new KanbanAPI();
