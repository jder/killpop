local util = {}

local etlua = require "system.etlua"

--- If a message is unhandled, tries sending it to the superkind
--- (this also affects verbs)
function util.kind(superkind)
  local result = {}

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

function util.verb(verb)
  local patterns, body = table.unpack(verb)

  if type(patterns) == "string" then
    patterns = {patterns}
  end
  
  local result = { verb_info = { patterns = patterns } };
  setmetatable(result, { __call = function(t, ...)
    -- we drop the initial argument which is the table itself
    body(...) 
  end })

  return result
end

--- Takes direct_object/indirect_object info from commands
--- Returns (true, thing) if there is one
--- If there is more than one, returns (false, message_for_user)
--- In the future we can pass more options here to help pick smartly
function util.disambig_object(object_info)
  if not object_info then
    return false, "Expected some object."
  elseif #object_info.found == 0 then
    return false, string.format("I don't see \"%s\" here.", object_info.text)
  elseif #object_info.found > 1 then
    local options = {}
    for _, match in ipairs(object_info.found) do
      table.insert(options, string.format("%s (%s)", util.get_name(match), match))
    end
    return false, string.format("Sorry, \"%s\" is ambiguous; could be: %s", object_info.text, table.concat(options, " or "))
  else
    return true, object_info.found[1]
  end
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

-- Quick method for finding an object assuming it's unambiguous
function util.find(query, from)
  local all = util.find_all(query, from)
  if #all == 0 then
    return nil
  end

  return all[1]
end

--- Find all matching objects in the current location or inside of `from`, defaulting to current user
--- TODO: support multiple words, adjectives/aliases, prefixes, etc
function util.find_all(query, from)
  if string.match(query, "^#%d+$") then return {query} end

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
      if util.get_name(child) == query then
        table.insert(results, child)
      end
    end

    if util.get_name(parent) == query then
      table.insert(results, parent)
    end
  end

  for _, child in ipairs(orisa.get_children(from)) do
    if util.get_name(child) == query then
      table.insert(results, child)
    end
  end


  return results
end

-- splits the string around the given punctuation character, ignoring doubled separators
-- e.g. util.split_punct("a,b,,c", ",") -> {"a", "b", "c"}
function util.split_punct(string, char)
  local result = {}
  string.gsub(string, "[^%" .. char .. "]+", function(piece) table.insert(result, piece) end)
  return result
end

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

util.echo_template = etlua.compile [[<div class="echo"><%= text %></div>]]

return util