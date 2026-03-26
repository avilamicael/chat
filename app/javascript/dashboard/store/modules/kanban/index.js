import kanbanAPI from 'dashboard/api/kanban.js';

const state = {
  boards: [],
  columns: {}, // { boardId: [] }
  cards: {}, // { boardId: [] }
  archivedCards: {}, // { boardId: [] }
  uiFlags: {
    fetchingBoards: false,
    fetchingCards: false,
    movingCard: false,
  },
};

export const getters = {
  allBoards: _state => _state.boards,
  boardById: _state => id => _state.boards.find(b => b.id === Number(id)),
  boardColumns: _state => boardId => _state.columns[boardId] || [],
  boardCards: _state => boardId => _state.cards[boardId] || [],
  cardsByColumn: _state => (boardId, columnId) =>
    (_state.cards[boardId] || [])
      .filter(c => c.kanban_column_id === columnId)
      .sort((a, b) => a.position - b.position),
  archivedCardsByBoard: _state => boardId => _state.archivedCards[boardId] || [],
  uiFlags: _state => _state.uiFlags,
};

export const mutations = {
  SET_BOARDS(_state, boards) {
    _state.boards = boards;
  },
  ADD_BOARD(_state, board) {
    _state.boards.push(board);
  },
  UPDATE_BOARD(_state, board) {
    const idx = _state.boards.findIndex(b => b.id === board.id);
    if (idx !== -1) _state.boards.splice(idx, 1, board);
  },
  REMOVE_BOARD(_state, boardId) {
    const id = Number(boardId);
    _state.boards = _state.boards.filter(b => b.id !== id);
    const { [id]: _cols, ...restCols } = _state.columns;
    _state.columns = restCols;
    const { [id]: _cards, ...restCards } = _state.cards;
    _state.cards = restCards;
  },
  SET_COLUMNS(_state, { boardId, columns }) {
    _state.columns = { ..._state.columns, [boardId]: columns };
  },
  SET_CARDS(_state, { boardId, cards }) {
    _state.cards = { ..._state.cards, [boardId]: cards };
  },
  ADD_CARD(_state, { boardId, card }) {
    const existing = _state.cards[boardId] || [];
    _state.cards = { ..._state.cards, [boardId]: [...existing, card] };
  },
  REMOVE_CARD(_state, { boardId, cardId }) {
    const existing = _state.cards[boardId] || [];
    _state.cards = {
      ..._state.cards,
      [boardId]: existing.filter(c => c.id !== cardId),
    };
  },
  MOVE_CARD(_state, { boardId, cardId, columnId, position }) {
    const cards = _state.cards[boardId] || [];
    _state.cards = {
      ..._state.cards,
      [boardId]: cards.map(c =>
        c.id === cardId
          ? { ...c, kanban_column_id: columnId, position }
          : c
      ),
    };
  },
  UPDATE_CARD(_state, { boardId, card }) {
    const cards = _state.cards[boardId] || [];
    _state.cards = {
      ..._state.cards,
      [boardId]: cards.map(c =>
        c.id === card.id ? { ...c, ...card, position: c.position } : c
      ),
    };
  },
  SET_ARCHIVED_CARDS(_state, { boardId, cards }) {
    _state.archivedCards = { ..._state.archivedCards, [boardId]: cards };
  },
  SET_UI_FLAG(_state, flags) {
    _state.uiFlags = { ..._state.uiFlags, ...flags };
  },
  UPDATE_COLUMN(_state, { boardId, column }) {
    const cols = _state.columns[boardId] || [];
    const idx = cols.findIndex(c => c.id === column.id);
    if (idx !== -1) {
      const updated = [...cols];
      updated.splice(idx, 1, column);
      _state.columns = { ..._state.columns, [boardId]: updated };
    }
  },
};

export const actions = {
  async fetchBoards({ commit }) {
    commit('SET_UI_FLAG', { fetchingBoards: true });
    try {
      const { data } = await kanbanAPI.getBoards();
      commit('SET_BOARDS', data.payload);
    } catch {
      // silently ignore — boards will remain empty
    } finally {
      commit('SET_UI_FLAG', { fetchingBoards: false });
    }
  },

  async fetchBoard({ commit }, boardId) {
    const { data } = await kanbanAPI.getBoard(boardId);
    commit('UPDATE_BOARD', data);
    if (data.columns) {
      commit('SET_COLUMNS', { boardId, columns: data.columns });
    }
    return data;
  },

  async createBoard({ commit }, boardData) {
    const { data } = await kanbanAPI.createBoard(boardData);
    commit('ADD_BOARD', data);
    return data;
  },

  async updateBoard({ commit }, { boardId, ...boardData }) {
    const { data } = await kanbanAPI.updateBoard(boardId, boardData);
    commit('UPDATE_BOARD', data);
    return data;
  },

  async deleteBoard({ commit }, boardId) {
    await kanbanAPI.deleteBoard(boardId);
    commit('REMOVE_BOARD', boardId);
  },

  async fetchCards({ commit }, boardId) {
    commit('SET_UI_FLAG', { fetchingCards: true });
    try {
      const { data } = await kanbanAPI.getCards(boardId);
      commit('SET_CARDS', { boardId: Number(boardId), cards: data.payload });
    } finally {
      commit('SET_UI_FLAG', { fetchingCards: false });
    }
  },

  async addCard({ commit }, { boardId, ...cardData }) {
    const { data } = await kanbanAPI.addCard(boardId, cardData);
    commit('ADD_CARD', { boardId: Number(boardId), card: data });
    return data;
  },

  async updateCard({ commit }, { boardId, cardId, ...data }) {
    const { data: card } = await kanbanAPI.updateCard(boardId, cardId, data);
    commit('UPDATE_CARD', { boardId, card });
    return card;
  },

  async moveCard({ commit, state: _state }, { boardId, cardId, columnId, position, outcomeReason }) {
    const original = (_state.cards[boardId] || []).find(c => c.id === cardId);
    commit('MOVE_CARD', { boardId, cardId, columnId, position });
    try {
      await kanbanAPI.moveCard(boardId, cardId, { column_id: columnId, position, outcome_reason: outcomeReason });
    } catch (error) {
      if (original) {
        commit('MOVE_CARD', {
          boardId,
          cardId,
          columnId: original.kanban_column_id,
          position: original.position,
        });
      }
      throw error;
    }
  },

  handleCardMoved({ commit, state: _state }, { card, board_id: boardId }) {
    if (!_state.cards[boardId]) return;
    commit('MOVE_CARD', {
      boardId,
      cardId: card.id,
      columnId: card.kanban_column_id,
      position: card.position,
    });
  },

  handleCardAdded({ commit, state: _state }, { card, board_id: boardId }) {
    if (!_state.cards[boardId]) return;
    const exists = (_state.cards[boardId] || []).find(c => c.id === card.id);
    if (!exists) {
      commit('ADD_CARD', { boardId, card });
    }
  },

  handleCardRemoved({ commit }, { card_id: cardId, board_id: boardId }) {
    commit('REMOVE_CARD', { boardId, cardId });
  },

  handleCardUpdated({ commit, state: _state }, { card, board_id: boardId }) {
    if (!_state.cards[boardId]) return;
    commit('UPDATE_CARD', { boardId, card });
  },

  async fetchConversationCard(_, conversationId) {
    const { data } = await kanbanAPI.getConversationCard(conversationId);
    return data.payload;
  },

  async deleteCard({ commit }, { boardId, cardId }) {
    await kanbanAPI.removeCard(boardId, cardId);
    commit('REMOVE_CARD', { boardId: Number(boardId), cardId });
  },

  async updateColumn({ commit }, { boardId, columnId, ...data }) {
    const { data: response } = await kanbanAPI.updateColumn(boardId, columnId, data);
    commit('UPDATE_COLUMN', { boardId: Number(boardId), column: response });
  },

  async fetchArchivedCards({ commit }, { boardId, params = {} }) {
    const { data } = await kanbanAPI.getArchivedCards(boardId, params);
    commit('SET_ARCHIVED_CARDS', { boardId: Number(boardId), cards: data.payload });
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
