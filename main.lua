
function main(sender, name, payload)
  if name == "say" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_name(sender), payload)})
    end
  elseif name == "tell" and orisa.get_kind(orisa.self) == "system/user" then
    orisa.tell(payload.message)
    last = orisa.get_state(orisa.self, "last")      
    if last then
      orisa.tell("Last thing said was " .. last)
    end
    orisa.set_state(orisa.self, "last", payload.message)
  else
    print("unknown message", name)
  end
end