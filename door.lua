local super = require "system.object"
local util = require "system.util"

local door = util.kind(super)

function door.created(payload) 
  if super.created(payload) then
    orisa.set_attr(orisa.self, "name", payload.direction)
    local destination = payload.destination
    if not destination then
      destination = orisa.create_object(nil, "system.room", {owner = payload.owner})
    end
    orisa.set_attr(orisa.self, "destination", destination)
  end
end

return door