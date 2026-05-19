import kanbanAPI from 'dashboard/api/kanban.js';

const state = {
  boards: [],
  columns: {}, // { boardId: [] }
  cards: {}, // { boardId: [] }
  archivedCards: {}, // { boardId: [] }
  // { boardId: { columnId: { exceeded, activeCount, wipLimit } } }
  columnWipStatus: {},
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
  archivedCardsByBoard: _state => boardId =>
    _state.archivedCards[boardId] || [],
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
        c.id === cardId ? { ...c, kanban_column_id: columnId, position } : c
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
  SET_COLUMN_WIP_STATUS(
    _state,
    { boardId, columnId, exceeded, activeCount, wipLimit }
  ) {
    const bId = Number(boardId);
    const cId = Number(columnId);
    const prevBoard = _state.columnWipStatus[bId] || {};
    const prevEntry = prevBoard[cId] || {};
    const nextEntry = {
      exceeded: exceeded ?? prevEntry.exceeded ?? false,
      activeCount: activeCount ?? prevEntry.activeCount ?? null,
      wipLimit: wipLimit ?? prevEntry.wipLimit ?? null,
    };
    _state.columnWipStatus = {
      ..._state.columnWipStatus,
      [bId]: { ...prevBoard, [cId]: nextEntry },
    };
  },
  // Phase 3 KAN-09: atualiza card_count + avg_dwell_seconds na coluna específica
  // dentro de _state.columns[boardId] (shape consistente com SET_COLUMNS).
  SET_COLUMN_METRICS(_state, { boardId, columnId, count, avgDwellSeconds }) {
    const bId = Number(boardId);
    const cId = Number(columnId);
    const cols = _state.columns[bId] || [];
    const idx = cols.findIndex(c => c.id === cId);
    if (idx === -1) return;
    const updated = [...cols];
    updated.splice(idx, 1, {
      ...cols[idx],
      card_count: count,
      cards_count: count,
      avg_dwell_seconds: avgDwellSeconds,
    });
    _state.columns = { ..._state.columns, [bId]: updated };
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

  async fetchCards({ commit }, payload) {
    // Aceita boardId direto (legacy) OU { boardId, ...filterParams }
    const isObject = payload && typeof payload === 'object';
    const boardId = isObject ? payload.boardId : payload;
    const params = isObject ? { ...payload } : {};
    delete params.boardId;
    commit('SET_UI_FLAG', { fetchingCards: true });
    try {
      const { data } = await kanbanAPI.getCards(boardId, params);
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

  async moveCard(
    { commit, state: _state, dispatch },
    { boardId, cardId, columnId, position, outcomeReason }
  ) {
    const original = (_state.cards[boardId] || []).find(c => c.id === cardId);
    commit('MOVE_CARD', { boardId, cardId, columnId, position });
    try {
      const { data } = await kanbanAPI.moveCard(boardId, cardId, {
        column_id: columnId,
        position,
        outcome_reason: outcomeReason,
      });
      // D-03: WIP exceeded e soft warning — NAO reverter o card.
      // O backend persistiu o movimento; so atualizamos o status para a UI.
      if (data?.wip_exceeded) {
        commit('SET_COLUMN_WIP_STATUS', {
          boardId,
          columnId,
          exceeded: true,
          activeCount: data.wip_active_count,
        });
      } else {
        commit('SET_COLUMN_WIP_STATUS', {
          boardId,
          columnId,
          exceeded: false,
        });
      }
    } catch (error) {
      if (original) {
        commit('MOVE_CARD', {
          boardId,
          cardId,
          columnId: original.kanban_column_id,
          position: original.position,
        });
      }
      // DEBT-04: server has a newer version of the card
      if (error?.response?.status === 409) {
        const serverCard = error.response.data?.card;
        if (serverCard) {
          commit('UPDATE_CARD', { boardId, card: serverCard });
        } else {
          await dispatch('fetchCards', boardId);
        }
        const stale = new Error('KANBAN_CARD_STALE');
        stale.code = 'KANBAN_CARD_STALE';
        throw stale;
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

  // D-04: broadcast `kanban.wip_exceeded` consumido por todas as abas autenticadas
  // na mesma account. Payload vem do KanbanListener#kanban_wip_exceeded (Plan A-04).
  handleWipExceeded(
    { commit },
    {
      board_id: boardId,
      column_id: columnId,
      active_count: activeCount,
      wip_limit: wipLimit,
    }
  ) {
    commit('SET_COLUMN_WIP_STATUS', {
      boardId,
      columnId,
      exceeded: true,
      activeCount,
      wipLimit,
    });
  },

  // Phase 3 KAN-09: broadcast `kanban.column_metrics_updated` — re-renderiza apenas
  // a coluna afetada (não o board inteiro). Payload de KanbanListener#kanban_column_metrics_updated.
  handleColumnMetricsUpdated(
    { commit },
    {
      board_id: boardId,
      column_id: columnId,
      count,
      avg_dwell_seconds: avgDwellSeconds,
    }
  ) {
    commit('SET_COLUMN_METRICS', {
      boardId,
      columnId,
      count,
      avgDwellSeconds,
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

  async linkConversationToCard(
    { commit },
    { boardId, cardId, conversationId }
  ) {
    const { data: card } = await kanbanAPI.linkConversationToCard(
      boardId,
      cardId,
      conversationId
    );
    commit('UPDATE_CARD', { boardId: Number(boardId), card });
    return card;
  },

  async unlinkConversationFromCard(
    { commit },
    { boardId, cardId, conversationId }
  ) {
    const { data: card } = await kanbanAPI.unlinkConversationFromCard(
      boardId,
      cardId,
      conversationId
    );
    commit('UPDATE_CARD', { boardId: Number(boardId), card });
    return card;
  },

  async updateColumn({ commit }, { boardId, columnId, ...data }) {
    const { data: response } = await kanbanAPI.updateColumn(
      boardId,
      columnId,
      data
    );
    commit('UPDATE_COLUMN', { boardId: Number(boardId), column: response });
  },

  async fetchArchivedCards({ commit }, { boardId, params = {} }) {
    const { data } = await kanbanAPI.getArchivedCards(boardId, params);
    commit('SET_ARCHIVED_CARDS', {
      boardId: Number(boardId),
      cards: data.payload,
    });
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
