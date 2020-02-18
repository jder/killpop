local super = require "system.object"
local util = require "system.util"

local door = util.kind(super)

function door.created(payload) 
  if super.created(payload) then
    orisa.set_attr(orisa.self, "name", payload.direction)
    orisa.set_attr(orisa.self, "hidden", true)
    local destination = payload.destination
    if not destination then
      destination = orisa.create_object(nil, "system.room", {owner = payload.owner})
    end
    orisa.set_attr(orisa.self, "destination", destination)
  end
end

door.go = util.verb {
  {"go|g $this"},
  function(payload)
    local destination = orisa.get_attr(orisa.self, "destination")
    local direction = orisa.get_attr(orisa.self, "name")
    local parent = orisa.get_parent(payload.user)
    if parent then
      orisa.send(parent, "tell_action", {user = payload.user, me = string.format("You go %s.", direction), others = string.format("%s goes %s.", orisa.get_username(payload.user), direction)})
    end
    orisa.move_object(payload.user, destination)
    orisa.send(destination, "tell_action", {user = payload.user, others = string.format("%s arrives.", orisa.get_username(payload.user))})
  end
}

return door