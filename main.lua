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

function run_eval(cmd) 
  local chunk, err = load(cmd, "command", "t")
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
end

function run_look()
  local room = orisa.get_parent(orisa.self)
  if not room then
    orisa.send_user_tell("You aren't anywhere.")
  else 
    orisa.send_user_tell(base.get_name(room))
    local description = orisa.get_attr(room, "description")
    if description then
      orisa.send_user_tell(description)
    else
      orisa.send_user_tell("It's unremarkable.")
    end

    local children = orisa.get_children(room)
    local contents = "Present here: \n  "
    for i, child in ipairs(children) do
      if i ~= 1 then
        contents = contents .. ", "
      end
      contents = contents .. base.get_name(child) .. " (" .. child .. ")"
    end
    orisa.send_user_tell(contents)
  end
end

function run_inspect(query)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  local prefix = base.get_name(target) .. " (" .. target .. ", " .. orisa.get_kind(target) .. ")"
  local description = orisa.get_attr(target, "description")
  if description == nil then
    orisa.send_user_tell(prefix .. " is uninteresting.")
  else
    orisa.send_user_tell(prefix .. ": " .. description)
  end
end

edit_template = [[
  require "main"
  
  function handle_$KIND(kind, sender, name, payload)
    -- sample message handling; try it with /ping
    if name == "ping" then
      orisa.send(sender, "pong", payload)
    else 
      -- fallback to behavior of system/object, if you like
      -- (includes handling for /set)
      main("system/object", sender, name, payload)
    end
  end
]]  

function run_edit(kind)
  local current = orisa.get_custom_space_content(kind)
  if current == nil then
    current = string.gsub(edit_template, "$KIND", string.gsub(kind, "/", "_"))
  end
  orisa.send_user_edit_file(kind, current)
end

function run_set(query, attr, value)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send(target, "set", {name = attr, value = value})
end

function run_get(query, attr)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell(base.get_name(target) .. "." .. attr .. " = " .. orisa.get_attr(target, attr))
end

function run_ping(query)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell("sending ping to " .. base.get_name(target))
  orisa.send(target, "ping")
end

function handle_system_user(kind, sender, name, payload)
  if name == "say" then
    local patterns = {
      -- Backtick means "evaluate this"
      ["^`(.*)"] = run_eval,
      ["^/look$"] = run_look,
      ["^/l$"] = run_look,
      ["^/inspect *(.*)"] = run_inspect,
      ["^/x *(.*)"] = run_inspect,
      ["^/edit +(%g+)"] = run_edit,
      ["^/set +(%g+) +(%g+) +(.+)"] = run_set,
      ["^/get +(%g+) +(%g+)"] = run_get,
      ["^/ping +(%g+)"] = run_ping
    }
    if not base.parse(payload, patterns) then
      local unknown = string.match(payload, "^/(%g*)")
      if unknown ~= nil then
        orisa.send_user_tell("Unknown command " .. unknown)
      else 
        orisa.send(orisa.get_parent(orisa.self), "say", payload)
      end
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
    orisa.send(orisa.get_parent(orisa.self), "say", "(wakes up)")
  elseif name == "save_file" then
    orisa.send_save_custom_space_content(payload.name, payload.content)
  elseif name == "disconnected" then
    orisa.send(orisa.get_parent(orisa.self), "say", "(goes to sleep)")
  elseif name == "pong" then
    orisa.send_user_tell("got pong from " .. base.get_name(sender))
  else
    main("system/object", sender, name, payload)
  end
end

function handle_system_room(kind, sender, name, payload)
  if name == "say" then 
    for _, object in ipairs(orisa.get_children(orisa.self)) do
      orisa.send(object, "tell", {message = string.format("%s: %s", orisa.get_username(sender), payload)})
    end
  else
    main("system/object", sender, name, payload)
  end
end

function handle_system_object(kind, sender, name, payload)
  if name == "set" then 
    if sender == orisa.self or sender == orisa.get_attr(orisa.self, "owner") then
      orisa.set_attr(orisa.self, payload.name, payload.value)
      orisa.send(sender, "tell", { message = payload.name .. " set" })
    else 
      print("ignoring unpermitted set")
    end
  else 
    print("unknown message", name)
  end
end