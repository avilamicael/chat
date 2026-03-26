json.id kanban_card.id
json.position kanban_card.position
json.kanban_column_id kanban_card.kanban_column_id
json.kanban_board_id kanban_card.kanban_board_id
json.account_id kanban_card.account_id
json.conversation_id kanban_card.conversation_id
json.title kanban_card.title
json.description kanban_card.description
json.priority kanban_card.priority
json.task_status kanban_card.task_status
json.due_date kanban_card.due_date
json.reminder_at kanban_card.reminder_at
json.created_by_id kanban_card.created_by_id
json.assignee_id kanban_card.assignee_id
json.assignee_ids kanban_card.assignee_ids || []
json.team_id kanban_card.team_id
json.team_ids kanban_card.team_ids || []
assignees = User.where(id: kanban_card.assignee_ids || [])
json.assignees assignees do |agent|
  json.id agent.id
  json.name agent.name
  json.thumbnail agent.avatar_url
end
teams_list = Team.where(id: kanban_card.team_ids || [])
json.teams teams_list do |team|
  json.id team.id
  json.name team.name
end
json.created_at kanban_card.created_at
json.updated_at kanban_card.updated_at
json.archived_at kanban_card.archived_at
json.outcome kanban_card.outcome
json.outcome_reason kanban_card.outcome_reason

if kanban_card.association(:conversation).loaded? && kanban_card.conversation
  json.conversation do
    conv = kanban_card.conversation
    json.id conv.id
    json.display_id conv.display_id
    json.status conv.status
    json.created_at conv.created_at
    json.inbox_id conv.inbox_id
    json.channel conv.inbox&.channel_type
    json.meta do
      json.sender do
        json.id conv.contact&.id
        json.name conv.contact&.name
        json.thumbnail conv.contact&.avatar_url
      end
      if conv.assignee
        json.assignee do
          json.id conv.assignee.id
          json.name conv.assignee.name
          json.thumbnail conv.assignee.avatar_url
        end
      end
    end
  end
else
  json.conversation nil
end
