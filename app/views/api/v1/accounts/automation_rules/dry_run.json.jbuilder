json.payload do
  json.matched @result[:matched]
  json.conditions_evaluation @result[:conditions_evaluation]
  json.actions_preview @result[:actions_preview]
end
