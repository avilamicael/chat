class AddAbortOnFailToAutomationRules < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_rules, :abort_on_fail, :boolean, default: false, null: false
  end
end
