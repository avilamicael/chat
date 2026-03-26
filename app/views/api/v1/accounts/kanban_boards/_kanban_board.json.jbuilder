json.id kanban_board.id
json.name kanban_board.name
json.description kanban_board.description
json.is_default kanban_board.is_default
json.filters kanban_board.filters
json.account_id kanban_board.account_id
json.created_at kanban_board.created_at
json.updated_at kanban_board.updated_at
if kanban_board.association(:kanban_columns).loaded?
  json.columns kanban_board.kanban_columns.order(:position), partial: 'api/v1/accounts/kanban_boards/columns/kanban_column', as: :kanban_column
  json.cards_total kanban_board.kanban_columns.sum { |col| col.kanban_cards.length }
end
