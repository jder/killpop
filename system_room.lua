local system_room = {}

function handlers.system_room(kind, sender, name, payload)
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
    main("system/object", sender, name, payload)
  else
    main("system/object", sender, name, payload)
  end
end

return system_room 