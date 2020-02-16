--[[ 
  system.main is always loaded and exports this single global function
  to handle messages. It loads modules named after object kinds and calls
  their handler function. 
    
  Other files in this repo are used with e.g. `require "system.object"`
]]

local util = require "system.util"

function main(name, payload)
  local kind = orisa.get_kind(orisa.self)

  local success, result = pcall(require, kind)
  if not success then
    local top, package = util.split_kind(kind)
    if package == "user" and top ~= "system" then
      -- for users, we fall back to system user as a safety mechanism and
      -- because users are initially created before they have a package
      print("Defaulting to system.user due to error", result)
      success, result = pcall(require, "system.user")
    end
  end
  
  if success then
    if result.handler then
      result.handler(name, payload)
    else
      print(kind, "doesn't have a handler")
    end
  else
    print("Unable to load package for", kind, "error:", result)
  end
end