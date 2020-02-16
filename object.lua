local util = require "system.util"

local object = util.kind()

function object.from_owner()
  local sender = orisa.sender 
  return (sender == orisa.self or sender == orisa.get_attr(orisa.self, "owner") or sender == "#1")
end

function object.set(payload)
  if object.from_owner() then
    orisa.set_attr(orisa.self, payload.name, payload.value)
    orisa.send(sender, "tell", { message = payload.name .. " set" })
  else 
    print("ignoring unpermitted set")
  end
end

function object.move(payload)
  if object.from_owner() then
    orisa.send_move_object(orisa.self, payload.destination)
  else 
    print("ignoring unpermitted set")
  end
end

function object.created(payload)
  -- the this is sent once, right after we are created, by send_create_object; see calls to that for payload
  if orisa.get_state(orisa.self, "created") == nil then
    orisa.set_attr(orisa.self, "owner", payload.owner)
    orisa.set_state(orisa.self, "created", true)
    return true -- for subclasses to use
  else 
    print("Ignoring duplicate created message")
    return false
  end
end

-- things which are generally safe to ignore

function object.tell(payload)
end

function object.parent_changed(payload)
end

function object.child_added(payload)
end

return object