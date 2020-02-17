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
  print("would interpret this as a command:", payload.message)
end

room.look = util.verb {
  {"look|gaze|admire $self", "look|gaze|admire at $self"},
  function(payload)
    print("would look at ", orisa.self)
  end
}

return room 