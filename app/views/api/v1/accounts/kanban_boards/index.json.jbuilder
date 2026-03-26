json.payload do
  json.array! @boards, partial: 'api/v1/accounts/kanban_boards/kanban_board', as: :kanban_board
end
