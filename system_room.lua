local system_room = {}

function handlers.system_room(kind, sender, name, payload)
  if name == "say" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_username(sender), payload)})
    end
  else
    main("system/object", sender, name, payload)
  end
end

return system_room 