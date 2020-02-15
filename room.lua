local room = {}

function room.handler(kind, sender, name, payload)
  if name == "tell" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", payload)
    end
  elseif name == "tell_others" then
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      if object ~= sender then
        orisa.send(object, "tell", payload)
      end
    end
  elseif name == "created" then
    if orisa.get_state(orisa.self, "created") == nil then
      if payload.entrance then 
        orisa.send(payload.entrance, "connect_destination", {destination = orisa.self})
      end
    end
    main("system.object", sender, name, payload)
  elseif name == "say" then
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_username(sender), payload.message)})
    end
  elseif name == "do" then
    print("would interpret this as a command:", payload.message)
  else
    main("system.object", sender, name, payload)
  end
end

return room 