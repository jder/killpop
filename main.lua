
function main(sender, name, payload)
  if name == "say" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_name(sender), payload)})
    end
  elseif name == "tell" and orisa.get_kind(orisa.self) == "system/user" then
    orisa.tell(payload.message)
  else
    print("unknown message", name)
  end
end