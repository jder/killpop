local base = {}

-- patterns should be a map from lua patterns -> functions to call with the captures
function base.parse(text, patterns)
  for pat, handler in pairs(patterns) do
    local captures = {string.match(text, pat)}
    if captures[1] ~= nil then
      handler(table.unpack(captures))
      return true
    end
  end
  return false
end

function base.get_name(object)
  local username = orisa.get_username(object)
  if username ~= nil then 
    return username
  end

  local custom_name = orisa.get_attr(object, "name")
  if custom_name ~= nil then
    return custom_name
  end

  return "object"
end

function base.find(query, parent)
  if string.match(query, "#%d+") then return query end

  if parent == nil then
    parent = orisa.get_parent(orisa.self)
  end

  if parent == nil then return nil end 
  for _, child in ipairs(orisa.get_children(parent)) do
    if base.get_name(child) == query then
      return child
    end
  end

  -- TODO: adjectives etc

  return nil
end

return base