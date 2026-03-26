import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './Index.vue';
import KanbanBoard from './KanbanBoard.vue';
import KanbanBoardSettings from './KanbanBoardSettings.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanIndex,
    name: 'kanban_view',
    meta,
    children: [
      {
        path: 'boards/:boardId',
        component: KanbanBoard,
        name: 'kanban_board',
        meta,
      },
      {
        path: 'boards/:boardId/settings',
        component: KanbanBoardSettings,
        name: 'kanban_board_settings',
        meta,
      },
    ],
  },
];
