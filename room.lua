local super = require "system.object"
local util = require "system.util"
local commands = require "system.commands"

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
          table.insert(matches, {object = object, name = name})
          break
        end
      end
    end
  end

  if #matches == 0 then
    orisa.send(orisa.sender, "tell", {message = string.format("Sorry, I didn't understand.")})
  elseif #matches ~= 1 then
    local options = {}
    for _, match in ipairs(matches) do
      table.insert(options, string.format("%s with %s (%s)", match.name, util.get_name(match.object), match.object))
    end
    -- TODO: more helpful
    orisa.send(orisa.sender, "tell", {message = string.format("Sorry, that was ambiguous between: %s", table.concat(options, " or "))})
  else
    local match = matches[1]
    orisa.send(match.object, match.name, user_parsed)
  end
end

room.look = util.verb {
  {"watch", "admire $this", "gaze $this with $any", "look to $this"},
  function(payload)
    print("would look at", orisa.self, util.tostring(payload))
  end
}

return room 