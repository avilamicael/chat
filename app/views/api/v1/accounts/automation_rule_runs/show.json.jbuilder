json.payload do
  json.partial! 'api/v1/accounts/automation_rule_runs/run', formats: [:json], run: @run
end
