local super = require "system.object"
local util = require "system.util"

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
  local verbs = {[orisa.self] = main("get_verbs")}
  for _, object in ipairs(orisa.get_children(orisa.self)) do
    verbs[object] = orisa.query(object, "get_verbs")
  end

  for object, verbs in pairs(verbs) do
    for name, verb_info in pairs(verbs) do
      for _, pat in ipairs(verb_info.patterns) do
        if pat == payload.message then
          print("Would execute", object, name)
          return
        end
      end
    end
  end
end

room.look = util.verb {
  {"look", "look|gaze|admire $self", "look|gaze|admire at $self"},
  function(payload)
    print("would look at ", orisa.self)
  end
}

return room 