class AddRespondToGroupsToCaptainInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_inboxes, :respond_to_groups, :boolean, default: false, null: false
  end
end
