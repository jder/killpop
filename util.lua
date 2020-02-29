local util = {}

local etlua = require "system.etlua"

--- Create a new kind (module/package) which has a handler for messages
--- and supports collecting verbs defined with util.verb
function util.kind(superkind)
  local result = {}
  
  if type(superkind) == "string" then
    superkind = require(superkind)
  end

  --- If a message is unhandled, tries sending it to the superkind
  --- (this also affects verbs)
  function result.handler(name, payload)
    local to_call = result[name]
    if to_call then
      return to_call(payload)
    elseif superkind then
      return superkind.handler(name, payload)
    else
      print("Object", orisa.self, "ignoring message", name)
    end
  end

  -- special support for collecting verbs across superkinds 
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

util.priority = {
  normal = 2, 
  high = 3, 
  low = 1, 
  fallback = 0
}

function util.verb(verb)
  local patterns, body = table.unpack(verb)

  if type(patterns) == "string" then
    patterns = {patterns}
  end
  
  local result = { 
    verb_info = { 
      patterns = patterns,
      priority = verb.priority or util.priority.normal
    } 
  };
  setmetatable(result, { __call = function(t, ...)
    -- we drop the initial argument which is the table itself
    body(...) 
  end })

  return result
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

-- Quick method for finding an object assuming it's unambiguous
function util.find(query, from)
  local all = util.find_all(query, from)
  if #all == 0 then
    return nil
  end

  return all[1]
end

--- Find all matching objects in the current location or inside of `from`, defaulting to current user
--- TODO: prefixes, scores/ordering, normalizing whitespace/case (happens in commands right now)
function util.find_all(query, from)
  if string.match(query, "^#%d+$") then return {query} end

  -- in case someone copy-pastes "something (#13)"
  local paren_id = string.match(query, "%((#%d+)%)")
  if paren_id then return {paren_id} end

  if from == nil then
    from = orisa.original_user
  end

  if query == "me" then
    return {from}
  end

  if query == "here" then
    return {orisa.get_parent(from)}
  end

  local parent = orisa.get_parent(from)
  
  local results = {}

  if parent ~= nil then 
    for _, child in ipairs(orisa.get_children(parent)) do
      if util.object_matches(child, query) then
        table.insert(results, child)
      end
    end

    if util.object_matches(parent, query) then
      table.insert(results, parent)
    end
  end

  for _, child in ipairs(orisa.get_children(from)) do
    if util.object_matches(child, query) then
      table.insert(results, child)
    end
  end

  return results
end

--- Does the text given describe this object? (Assuming both are lowercase & space-separated.)
function util.object_matches(object, text)
  if util.get_name(object) == text then
    return true
  end

  local aliases = orisa.get_attr(object, "aliases") or {}
  for _, alias in ipairs(aliases) do
    if alias == text then
      return true
    end
  end

  return false
end

-- splits the string around the given punctuation character, ignoring doubled separators
-- e.g. util.split_punct("a,b,,c", ",") -> {"a", "b", "c"}
function util.split_punct(string, char)
  local result = {}
  string.gsub(string, "[^%" .. char .. "]+", function(piece) table.insert(result, piece) end)
  return result
end

-- like tostring but prints contents of k-v tables
function util.tostring(v)
  local t = type(v)
  if t == "table" then
    -- TODO: nicer handling for array-like tables
    local pieces = {}
    for k,v in pairs(v) do
      table.insert(pieces, string.format("%s = %s", util.tostring(k), util.tostring(v)))
    end
    return "{" .. table.concat(pieces, ", ") .. "}"
  else
    return tostring(v)
  end
end

-- Turn the value into a lua code which will produce that value
function util.tocode(v)
  local t = type(v)
  if t == "table" then
    -- TODO: nicer handling for array-like tables
    local pieces = {}
    for k,v in pairs(v) do
      -- TODO: nicer handling for 'normal' strings
      table.insert(pieces, string.format("%s = %s", util.tocode(k), util.tocode(v)))
    end
    return "{" .. table.concat(pieces, ", ") .. "}"
  elseif t == "string" then
    return string.format("%q", v)
  elseif t == "number" or t == "boolean" or t == "nil" then
    return tostring(v)
  else
    error("Unable to convert value of type ".. t .. " to code")
  end
end

local log_warned = {}

--- Build a logger which can be turned on/off by user attributes.
--- Returns a function to log which acts just like string.format except all args
--- are util.tostring'ed first. (i.e. use %s or %q to substitute them)
function util.logger(name)
  local prefix = string.format("%s:", name)
  local attr = "log_" .. name
  if not log_warned[orisa.original_user .. ':' .. name] then
    log_warned[orisa.original_user .. ':' .. name] = true
    if orisa.get_attr(orisa.original_user, attr) then
      print(string.format("Logger \"%s\" enabled; use `/set me %s false` to disable.", name, attr))
    else
      print(string.format("Logger \"%s\" disabled; use `/set me %s true` to enable.", name, attr))
    end
  end
  return function(format, ...)
    if orisa.get_attr(orisa.original_user, attr) then
      print(prefix, string.format(format, util.tostring_all(...)))
    end
  end
end

function util.tostring_all(...)
  -- This is pretty gross, sorry.
  -- This is the only combination I could find which handled nil arguments in the 
  -- middle of the list.
  local inputs = table.pack(...)
  local result = {}
  for key, raw in pairs(inputs) do
    result[key] = util.tostring(raw)
  end
  return table.unpack(result, 1, select("#", ...))
end

function util.title(t)
  return string.gsub(string.gsub(string.lower(t), "^%g", string.upper), "%f[%g]%g", string.upper)
end

function util.current_room(from)
  if from == nil then
    from = orisa.self
  end
  local parent = orisa.get_parent(from)
  if parent == nil then
    return from
  else
    return util.current_room(parent)
  end
end

function util.is_inside(child, parent)
  if child == parent or child == nil then
    return false
  end

  local next_child = orisa.get_parent(child)
  if next_child == parent then
    return true
  end
  
  return util.is_inside(next_child, parent)
end

function util.oxford_join(list, sep, sep_last)
  local count = #list
  if count < 1 then
    return ""
  elseif count == 1 then
    return tostring(list[1])
  else
    return table.concat({table.unpack(list, 1, #list - 1)}, sep) .. sep_last .. list[#list]
  end
end

return util