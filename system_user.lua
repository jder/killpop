local system_user = {}
base = require "base"

function handlers.system_user(kind, sender, name, payload)
  if name == "say" then
    local patterns = {
      -- Backtick means "evaluate this"
      ["^`(.*)"] = system_user.run_eval,
      ["^/look$"] = system_user.run_look,
      ["^/l$"] = system_user.run_look,
      ["^/inspect *(.*)"] = system_user.run_inspect,
      ["^/x *(.*)"] = system_user.run_inspect,
      ["^/edit +(%g+)"] = system_user.run_edit,
      ["^/set +(%g+) +(%g+) +(.+)"] = system_user.run_set,
      ["^/get +(%g+) +(%g+)"] = system_user.run_get,
      ["^/ping +(%g+)"] = system_user.run_ping,
      ["^/move +(%g+) +(%g+)"] = system_user.run_move,
      ["^/create +(%g+)"] = system_user.run_create,
      -- ["^/dig +(%g+)"] = system_user.run_dig, -- creating the door+room and connecting them will still be a pain without replies or immediate-creates
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

function system_user.run_eval(cmd) 
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

function system_user.run_look()
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

function system_user.run_inspect(query)
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

  local children = orisa.get_children(target)
  local contents = "Contents: "
  for i, child in ipairs(children) do
    if i ~= 1 then
      contents = contents .. ", "
    end
    contents = contents .. base.get_name(child) .. " (" .. child .. ")"
  end
  orisa.send_user_tell(contents)

end

function system_user.run_edit(kind)
  local current = orisa.get_custom_space_content(kind)
  if current == nil then
    current = string.gsub(system_user.edit_template, "$KIND", string.gsub(kind, "/", "_"))
  end
  orisa.send_user_edit_file(kind, current)
end

function system_user.run_set(query, attr, value)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send(target, "set", {name = attr, value = value})
end

function system_user.run_get(query, attr)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell(base.get_name(target) .. "." .. attr .. " = " .. orisa.get_attr(target, attr))
end

function system_user.run_ping(query)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell("sending ping to " .. base.get_name(target))
  orisa.send(target, "ping")
end

function system_user.run_move(query, dest_query)
  local target = base.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  local dest = base.find(dest_query)
  if dest == nil then 
    orisa.send_user_tell("I don't see " .. dest_query)
    return
  end

  orisa.send(target, "move", {destination = dest})
end

function system_user.run_create(kind)
  orisa.send_create_object(orisa.self, kind, {owner = orisa.self})
end

-- templates

system_user.edit_template = [[
require "main"

function handlers.$KIND(kind, sender, name, payload)
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

return system_user