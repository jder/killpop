local object = {}

function object.handler(kind, sender, name, payload)
  local from_owner = (sender == orisa.self or sender == orisa.get_attr(orisa.self, "owner") or sender == "#1")
  if name == "set" then 
    if from_owner then
      orisa.set_attr(orisa.self, payload.name, payload.value)
      orisa.send(sender, "tell", { message = payload.name .. " set" })
    else 
      print("ignoring unpermitted set")
    end
  elseif name == "move" then
    if from_owner then
      orisa.send_move_object(orisa.self, payload.destination)
    else 
      print("ignoring unpermitted set")
    end
  elseif name == "created" then
    -- the this is sent once, right after we are created, by send_create_object; see calls to that for payload
    if orisa.get_state(orisa.self, "created") == nil then
      orisa.set_attr(orisa.self, "owner", payload.owner)
      orisa.set_state(orisa.self, "created", true)
    else 
      print("Ignoring duplicate created message")
    end
  elseif not object.ignored_messages[name] then
    print("unknown message", name)
  end
end

object.ignored_messages = {tell = true, parent_changed = true, child_added = true}

return object