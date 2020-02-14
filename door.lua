local door = {}

function door.handler(kind, sender, name, payload)
  if name == "created" then
    if orisa.get_state(orisa.self, "created") == nil then
      orisa.set_attr(orisa.self, "name", payload.direction)
      if payload.destination then
        orisa.set_attr(orisa.self, "destination", destination)
      else
        orisa.create_object(nil, "system.room", {owner = payload.owner, entrance = orisa.self})
      end
    end
     -- we want object behavior, too. would be nice to have a nicer super()
    main("system.object", sender, name, payload)
  elseif name == "connect_destination" then
    if orisa.original_user == orisa.get_attr(orisa.self, "owner") and orisa.get_attr(orisa.self, "destination") == nil then
      orisa.set_attr(orisa.self, "destination", payload.destination)
    end
  else
    main("system.object", sender, name, payload)
  end
end

return door