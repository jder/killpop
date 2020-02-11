-- global list of handlers which modules can register themselves in
handlers = {}

base = require "base"

require "system_user"
require "system_room"

function main(kind, sender, name, payload)
  local underscored = string.gsub(kind, "/", "_")
  local handler = handlers[underscored]
  if handler then
    handler(kind, sender, name, payload)
  else
    print("Unknown kind " .. kind)
  end
end