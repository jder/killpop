
function main(name, payload)
  if name == "command" then 
    for _, object in ipairs(orisa.get_children(orisa.id)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.name(orisa.sender), payload.text)})
    end
  elseif name == "tell" and orisa.kind == "system/user" then
    orisa.tell(payload.message)
  else
    print("unknown message", name)
  end
end