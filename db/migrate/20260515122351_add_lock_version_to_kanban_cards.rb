# NOTA Pitfall 3: KanbanListener#conversation_status_changed usa update_columns que bypassa
# lock_version. Aceitável MVP — rescue_from no controller absorve eventual StaleObjectError.
# Refator para card.reload + update! antes de mexer no card é v2.
class AddLockVersionToKanbanCards < ActiveRecord::Migration[7.1]
  def change
    add_column :kanban_cards, :lock_version, :integer, default: 0, null: false
  end
end
