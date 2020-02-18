local super = require "system.object"
local util = require "system.util"
local commands = require "system.commands"
local etlua = require "system.etlua"

local room = util.kind(super)

function room.tell(payload)
  for _, object in ipairs(orisa.get_children(orisa.self)) do
    orisa.send(object, "tell", payload)
  end
end

function room.tell_others(payload)
  for _, object in ipairs(orisa.get_children(orisa.self)) do
    if object ~= orisa.sender then
      orisa.send(object, "tell", payload)
    end
  end
end

function room.say(payload)
  for _, object in ipairs(orisa.get_children(orisa.self)) do
    orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_username(orisa.sender), payload.message)})
  end
end

function room.command(payload)
  local success, user_parsed = pcall(commands.parse_user, payload.message)
  if not success then
    orisa.send(orisa.sender, "tell", {message = string.format("Unable to parse command: %s", user_parsed)})
    return
  end

  local verbs = {[orisa.self] = main("get_verbs")}
  for _, object in ipairs(orisa.get_children(orisa.self)) do
    verbs[object] = orisa.query(object, "get_verbs")
  end

  for _, object in ipairs(orisa.get_children(orisa.sender)) do
    verbs[object] = orisa.query(object, "get_verbs")
  end

  local matches = {}
  for object, verbs in pairs(verbs) do
    for name, verb_info in pairs(verbs) do
      for _, pat in ipairs(verb_info.patterns) do
        local success, matcher = pcall(commands.parse_matcher, pat)
        if not success then
          print("Failed to parse verb pattern", pat, matcher)
        elseif commands.match(user_parsed, matcher, object) then
          table.insert(matches, {object = object, name = name, priority = verb_info.priority})
          break
        end
      end
    end
  end

  if #matches == 0 then
    orisa.send(orisa.sender, "tell", {message = string.format("Sorry, I didn't understand.")})
    return
  elseif #matches ~= 1 then
    -- sort highest priority first
    table.sort(matches, function(a, b) return a.priority > b.priority end)
    local highest_priority = matches[1].priority
    if matches[2].priority == highest_priority then -- more than one of highest priority
      local options = {}
      for _, match in ipairs(matches) do
        if match.priority == highest_priority then
          table.insert(options, string.format("%s with %s (%s)", match.name, util.get_name(match.object), match.object))
        end
      end
      -- TODO: more helpful
      orisa.send(orisa.sender, "tell", {message = string.format("Sorry, that was ambiguous between: %s", table.concat(options, " or "))})
      return
    end
  end

  local match = matches[1]
  orisa.send(match.object, match.name, {user = orisa.sender, room = orisa.self, command = user_parsed})
end

--- Describe an action by payload.user to others as payload.others, to self as payload.me
--- e.g. orisa.send(room, "tell_action", {user = user, me = "You laugh", others = username .. " laughs."})
function room.tell_action(payload)
  if payload.others then
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      if object ~= payload.user then
        orisa.send(object, "tell", {message = payload.others})
      end
    end
  end

  if payload.me then
    orisa.send(payload.user, "tell", {message = payload.me})
  end
end

room.look = util.verb {
  {"l|look", "l|look at $this", "l|look $this"},
  function(payload)
    local children = orisa.get_children(orisa.self)
    local contents = {}
    for _, child in ipairs(children) do
      if not orisa.get_attr(child, "hidden") then
        table.insert(contents, util.get_name(child))
      end
    end
    orisa.send(payload.user, "tell_html", {html = room.look_template({
      room_name = util.get_name(orisa.self),
      room_description = orisa.get_attr(orisa.self, "description"),
      children_description = table.concat(contents, ", ")
    })})
  end
}

room.look_template = etlua.compile [[
<p><b><%= room_name %></b></p>
<p><%= room_description or "It's unremarkable" %></p>
<p>Present: <%= children_description %></p>
]]

room.examine = util.verb {
  {"x $any", "examine $any"},
  function(payload)
    local target, message = commands.disambig_object(payload.command.direct_object)
    if message then
      orisa.send(payload.user, "tell", {message = message})
    end

    if target then
      local description = orisa.get_attr(target, "description")
      if description == nil then
        orisa.send(payload.user, "tell", {message = util.get_name(target) .. " is uninteresting."})
      else
        orisa.send(payload.user, "tell", {message = description})
      end
    end
  end
}

room.inventory = util.verb {
  {"inventory|i"},
  function(payload)
    local children = orisa.get_children(payload.user)
    local contents = {}
    for i, child in ipairs(children) do
      table.insert(contents, util.get_name(child))
    end
    orisa.send(payload.user, "tell", {message = string.format("You are holding: %s", table.concat(contents, ", "))})
  end
}

return room 