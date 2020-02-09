base = require "base"

function main(kind, sender, name, payload)
  local underscored = string.gsub(kind, "/", "_")
  local handler = _G["handle_" .. underscored]
  if handler then
    handler(kind, sender, name, payload)
  else
    print("Unknown kind " .. kind)
  end
end

function handle_system_user(kind, sender, name, payload)
  if name == "say" then 
    -- Backtick means "evaluate this"
    local first, last, cmd = string.find(payload, '^`(.*)')
    if first then
      local chunk, err = load("return (" .. cmd .. ")", "command", "t")
      if not chunk then
        orisa.send_user_tell("Compile Error: " .. err)
      else
        local success, result = pcall(chunk)
        if success then
          orisa.send_user_tell("Result: " .. tostring(result))
        else
          orisa.send_user_tell("Runtime Error: " .. tostring(result))
        end
      end
    else 
      orisa.send(orisa.get_parent(orisa.self), "say", payload)
    end
  elseif name == "tell" then
    orisa.send_user_tell(payload.message)
    local history = orisa.get_state(orisa.self, "history")
    if not history then
      history = {}
    end
    table.insert(history, payload.message)
    -- truncate history to latest 50% of rows once hits capacity
    local max_history = 100
    if #history > max_history then
      history = table.move(history, max_history/2, #history, 1, {})
    end
    orisa.set_state(orisa.self, "history", history)
  elseif name == "connected" then
    local history = orisa.get_state(orisa.self, "history")
    if history then
      orisa.send_user_backlog(history)
    end
    orisa.send_user_tell("Welcome Back! New features include lua errors appearing in console and backtick (`) meaning eval!")
  elseif name == "save_file" then
    orisa.send_save_custom_space_content(payload.name, payload.content)
  else
    print("unknown message", name)
  end
end

function handle_system_room(kind, sender, name, payload)
  if name == "say" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_name(sender), payload)})
    end
  else
    print("unknown message", name)
  end  
end