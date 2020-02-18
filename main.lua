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
    local top, package_name = util.split_kind(kind)
    if top ~= "system" then
      local fallback = "system.object"
      -- some non-system package failed to load; fallback to an appropriate system package
      print(kind, "failed to load; defaulting to system.object", result)
      if package_name == "user" then
        -- for users, we fall back to system user so they can do anything
        -- since users are initially created before they have a package
        -- TODO: would be nice to make sure the user themselves sees this
        fallback = "system.user"
      end
      success, result = pcall(require, fallback)
      if success then
        -- for next time
        package.loaded[kind] = result
      end
    end
  end
  
  if success then
    if result.handler then
      return result.handler(name, payload)
    else
      print(kind, "doesn't have a handler")
    end
  else
    print("Unable to load package for", kind, "error:", result)
  end
end