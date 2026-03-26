json.payload do
  json.array! @columns, partial: 'api/v1/accounts/kanban_boards/columns/kanban_column', as: :kanban_column
end
