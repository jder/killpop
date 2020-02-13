--[[ 
  system.main is always loaded and exports this single global function
  to handle messages. It loads modules named after object kinds and calls
  their handler function. 
    
  Other files in this repo are used with e.g. `require "system.object"`

  Users can create objects of kinds $username.foo and edit lua files
  for the same name. They have the type $username.user.
]]

local base = require "system.base"

function main(kind, sender, name, payload)
  local success, result = pcall(require, kind)
  if success and result.handler then
    result.handler(kind, sender, name, payload)
  else
    local top, package = base.split_kind(kind)
    if package == "user" and top ~= "system" then
      -- for users, we fall back to system user as a safety mechanism and
      -- because users are initially created before they have a package
      print("Defaulting to system.user due to error", result)
      main("system.user", sender, name, payload)
    else
      if success then 
        print(kind, "doesn't have a handler")
      else
        print("No handler for kind", kind, "package error:", result)
      end
    end
  end
end