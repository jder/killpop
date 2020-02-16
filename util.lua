local util = {}

local etlua = require "system.etlua"

--- Calls
--- If a message is unhandled, tries sending it to the superkind
--- (this also affects verbs)
function util.kind(superkind)
  local result = {}

  function result.handler(name, payload)
    local to_call = result[name]
    if to_call then
      to_call(payload)
    elseif superkind then
      superkind.handler(name, payload)
    else
      print("Object", orisa.self, "ignoring message", name)
    end
  end

  function result.get_verbs()
    local verbs = {}
    if superkind and superkind.get_verbs then
      verbs = superkind.get_verbs()
    end

    for k, v in pairs(result) do
      if type(v) == "table" and v.verb_info then
        verbs[k] = v.verb_info
      end
    end

    return verbs
  end

  return result
end

function util.verb(verb)
  local patterns, body = table.unpack(verb)

  if type(patterns) == "string" then
    patterns = {patterns}
  end
  
  local result = { verb_info = { patterns = patterns } };
  setmetatable(result, { __call = body })

  return result
end

--- Matches patterns and calls functions with the captures
-- TODO: some actual parsing so we don't reject extra args like `/l foo` as "unknown command /l"
function util.parse(text, patterns)
  for pat, handler in pairs(patterns) do
    if pat ~= "default" then
      local captures = {string.match(text, pat)}
      if captures[1] ~= nil then
        local echo = true
        if type(handler) == "table" then
          echo = handler.echo
          handler = handler.handler
        end
        if echo then
          orisa.send_user_tell_html(util.echo_template({text = text}))
        end
        handler(table.unpack(captures))
        return
      end
    end
  end
  if patterns.default then
    patterns.default(text)
  end
end

--- Returns a pair of the kind's top-level package and the package name
-- e.g. util.split_kind("system.object") == "system", "object".
-- Returns nil if it does not match the expected pattern.
function util.split_kind(kind)
  return string.match(kind, "^([a-zA-Z0-9_/]+)%.([a-zA-Z0-9_]+)$")
end

--- A quick description of this object
function util.get_name(object)
  local username = orisa.get_username(object)
  if username ~= nil then 
    return username
  end

  local custom_name = orisa.get_attr(object, "name")
  if custom_name ~= nil then
    return custom_name
  end

  -- fall back to "object" or "room" etc
  local kind = orisa.get_kind(object)
  local _, name = util.split_kind(kind)

  return name or "object"
end

function util.find(query, parent)
  if string.match(query, "#%d+") then return query end

  if query == "me" then
    return orisa.original_user
  end

  if query == "here" then
    return orisa.get_parent(orisa.original_user)
  end

  if parent == nil then
    parent = orisa.get_parent(orisa.self)
  end

  if parent ~= nil then 
    for _, child in ipairs(orisa.get_children(parent)) do
      if util.get_name(child) == query then
        return child
      end
    end
  end

  for _, child in ipairs(orisa.get_children(orisa.self)) do
    if util.get_name(child) == query then
      return child
    end
  end

  -- TODO: adjectives etc

  return nil
end

util.echo_template = etlua.compile [[<div class="echo"><%= text %></div>]]

return util