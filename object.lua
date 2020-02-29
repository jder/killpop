local util = require "system.util"

local object = util.kind()

local function from_owner()
  local sender = orisa.sender 
  return (sender == orisa.self or sender == orisa.get_attr(orisa.self, "owner") or sender == "#1")
end

function object.set(payload)
  if from_owner() then
    orisa.set_attr(orisa.self, payload.name, payload.value)
    orisa.send(orisa.sender, "tell", { message = string.format("%s set to %s", payload.name, util.tocode(payload.value)) })
  else 
    print("ignoring unpermitted set")
  end
end

function object.move(payload)
  if from_owner() then
    orisa.move_object(orisa.self, payload.destination)
  else 
    print("ignoring unpermitted move")
  end
end

function object.created(payload)
  -- this is sent once, right after we are created, by create_object; see calls to that for payload
  if orisa.get_state(orisa.self, "created") == nil then
    for k, v in pairs(payload.attrs or {}) do
      orisa.set_attr(orisa.self, k, v)
    end
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