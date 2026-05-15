class AddExecutionStatusToAutomationRules < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_rules, :last_execution_status, :string  # nullable; NULL = nunca executado
    add_column :automation_rules, :last_execution_error, :text
    add_column :automation_rules, :last_executed_at, :datetime
  end
end
