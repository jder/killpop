local base = {}

--- Matches patterns and calls functions with the captures
-- TODO: some actual parsing so we don't reject extra args like `/l foo` as "unknown command /l"
function base.parse(text, patterns)
  for pat, handler in pairs(patterns) do
    local captures = {string.match(text, pat)}
    if captures[1] ~= nil then
      orisa.send_user_tell(text)
      handler(table.unpack(captures))
      return true
    end
  end
  return false
end

--- Returns a pair of the kind's top-level package and the package name
-- e.g. base.split_kind("system.object") == "system", "object".
-- Returns nil if it does not match the expected pattern.
function base.split_kind(kind)
  return string.match(kind, "^([a-zA-Z0-9_]+)%.([a-zA-Z0-9_]+)$")
end

--- A quick description of this object
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

  if query == "me" then
    return orisa.original_user
  end

  if parent == nil then
    parent = orisa.get_parent(orisa.self)
  end

  if parent ~= nil then 
    for _, child in ipairs(orisa.get_children(parent)) do
      if base.get_name(child) == query then
        return child
      end
    end
  end

  for _, child in ipairs(orisa.get_children(orisa.self)) do
    if base.get_name(child) == query then
      return child
    end
  end

  -- TODO: adjectives etc

  return nil
end

return base