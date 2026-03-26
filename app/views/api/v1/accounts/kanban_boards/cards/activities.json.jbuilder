json.activities @activities do |audit|
  json.id audit.id
  json.action audit.action
  json.changes audit.audited_changes
  json.version audit.version
  json.created_at audit.created_at.iso8601
  if audit.user
    json.user do
      json.id audit.user.id
      json.name audit.user.name
      json.thumbnail audit.user.avatar_url
    end
  else
    json.user nil
  end
end
