json.payload do
  json.array! @runs do |run|
    json.partial! 'api/v1/accounts/automation_rule_runs/run', formats: [:json], run: run
  end
end
json.meta do
  json.has_more @runs.size == (params[:limit].present? ? params[:limit].to_i : 20)
end
