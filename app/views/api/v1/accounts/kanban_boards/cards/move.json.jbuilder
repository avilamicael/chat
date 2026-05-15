json.partial! 'api/v1/accounts/kanban_boards/cards/kanban_card', kanban_card: @card
json.wip_exceeded @wip_exceeded || false
json.wip_active_count @wip_active_count if @wip_exceeded
