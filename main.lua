
function main(sender, name, payload)
  if name == "say" then 
    if orisa.get_kind(orisa.self) == "system/user" then
      -- Backtick means "evaluate this"
      first, last, cmd = string.find(payload, '^`(.*)')
      if first then
        chunk, err = load("return (" .. cmd .. ")", "command", "t")
        if not chunk then
          orisa.tell("Compile Error: " .. err)
        else
          success, result = pcall(chunk)
          if success then
            orisa.tell("Result: " .. tostring(result))
          else
            orisa.tell("Runtime Error: " .. tostring(result))
          end
        end
      else 
        orisa.send(orisa.get_parent(orisa.self), "say", payload)
      end
    elseif orisa.get_kind(orisa.self) == "system/room" then
      for _, object in ipairs(orisa.get_children(orisa.self)) do
        orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_name(sender), payload)})
      end
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