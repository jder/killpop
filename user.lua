local util = require "system.util"
local etlua = require "system.etlua"

local super = require "system.object"

local user = util.kind(super)

function user.command(payload)
  local patterns = {
    ["^`(.*)"] = user.run_eval,
    ["^[\"'](.*)"] = {handler = user.run_say, echo = false},
    ["^/run (.*)"] = user.run_run,
    ["^/eval (.*)"] = user.run_eval,
    ["^/inspect *(.*)"] = user.run_inspect,
    ["^/i *(.*)"] = user.run_inspect,
    ["^/edit +(%g+)"] = user.run_edit,
    ["^/set +(%g+) +(%g+) +(.+)"] = user.run_set,
    ["^/get +(%g+) +(%g+)"] = user.run_get,
    ["^/ping +(%g+)"] = user.run_ping,
    ["^/move +(%g+) +(%g+)"] = user.run_move,
    ["^/create +(%g+)"] = user.run_create,
    ["^/dig +(%g+)"] = user.run_dig,
    ["^/go +(%g+)"] = user.run_go,
    ["^/help"] = user.run_help,
    ["^([^/`'\"].*)"] = user.run_command,
    default = user.run_fallback
  }
  util.parse(payload.message, patterns)
end

function user.tell(payload)
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
end

function user.tell_html(payload)
  -- TODO: history or move history to backend
  if orisa.sender ~= orisa.get_parent(orisa.self) then
    print("Ignoring html tell from someone other than the room")
    return
  end

  orisa.send_user_tell_html(payload.html)
end

function user.connected(payload)
  local history = orisa.get_state(orisa.self, "history")
  if history then
    orisa.send_user_backlog(history)
  end
  orisa.send_user_tell("Welcome! Run /help for a quick tutorial.")
  orisa.send(orisa.get_parent(orisa.self), "tell_others", {message = string.format("%s wakes up.", orisa.get_username(orisa.self))})
end

function user.disconnected(payload)
  orisa.send(orisa.get_parent(orisa.self), "tell_others", {message = string.format("%s goes to sleep.", orisa.get_username(orisa.self))})
end

function user.save_file(payload)
  orisa.send_save_live_package_content(payload.name, payload.content)
end

function user.pong(payload)
  orisa.send_user_tell("got pong from " .. util.get_name(orisa.sender))
end

function user.run_fallback(text)
  orisa.send_user_tell("Unknown command " .. text)
end

function user.run_command(text)
  orisa.send(orisa.get_parent(orisa.self), "command", {message = text})
end

function user.run_say(text)
  orisa.send(orisa.get_parent(orisa.self), "say", {message = text})
end

function user.run_eval(cmd)
  return user.run_run("return (" .. cmd .. ")")
end

function user.run_run(cmd) 
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

function user.run_help()
  orisa.send_user_tell("Orisa Help:")
  orisa.send_user_tell("  <kildorf> jder! I got Orisa to run locally\
  <kildorf> > Welcome! Run /help for a quick tutorial.\
  <kildorf> > Unknown command help\
  <jder> ...\
  <jder> it's aspirational")  
end

function user.run_inspect(query)
  local target = util.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  local prefix = util.get_name(target) .. " (" .. target .. ", " .. orisa.get_kind(target) .. ")"
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
    contents = contents .. util.get_name(child) .. " (" .. child .. ")"
  end
  orisa.send_user_tell(contents)
end

function user.run_edit(kind)
  local current = orisa.get_live_package_content(kind)
  if current == nil then
    local top, package = util.split_kind(kind)
    local fallback = "system.object"
    if package == "user" then
      fallback = "system.user"
    end
    current = user.edit_template
    current = string.gsub(current, "$PACKAGE", package)
    current = string.gsub(current, "$FALLBACK", fallback)
  end
  orisa.send_user_edit_file(kind, current)
end

function user.run_set(query, attr, value)
  local target = util.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send(target, "set", {name = attr, value = value})
end

function user.run_get(query, attr)
  local target = util.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell(util.get_name(target) .. "." .. attr .. " = " .. orisa.get_attr(target, attr))
end

function user.run_ping(query)
  local target = util.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  orisa.send_user_tell("sending ping to " .. util.get_name(target))
  orisa.send(target, "ping")
end

function user.run_move(query, dest_query)
  local target = util.find(query)
  if target == nil then 
    orisa.send_user_tell("I don't see " .. query)
    return
  end

  local dest = util.find(dest_query)
  if dest == nil then 
    orisa.send_user_tell("I don't see " .. dest_query)
    return
  end

  orisa.send(target, "move", {destination = dest})
end

function user.run_create(kind)
  orisa.create_object(orisa.self, kind, {owner = orisa.self})
end

function user.run_dig(direction, destination_query)
  local parent = orisa.get_parent(orisa.self)
  if parent == nil then
    orisa.send_user_tell("You aren't anywhere.")
    return
  end
  
  local destination = nil
  if destination_query ~= nil then
    destination = util.find(destination_query)
    if destination == nil then
      orisa.send_user_tell("I don't see " .. destination_query .. " anywhere.")
      return
    end
  end

  orisa.create_object(parent, "system.door", {owner = orisa.self, direction = direction, destination = destination})
end

function user.run_go(direction)
  door = util.find(direction)
  if door == nil then
    orisa.send_user_tell("I don't see " .. direction .. " here.")
    return
  end

  destination = orisa.get_attr(door, "destination")
  orisa.send_user_tell("You go " .. direction .. ".")
  orisa.send_move_object(orisa.self, destination)
  local parent = orisa.get_parent(orisa.self)
  if parent then
    orisa.send(parent, "tell_others", {message = string.format("%s goes %s.", orisa.get_username(orisa.self), direction)})
  end
  orisa.send(destination, "tell_others", {message = string.format("%s arrives.", orisa.get_username(orisa.self))})
end

-- templates

user.edit_template = [[
local util = require "system.util"
local super = require "$FALLBACK"
local $PACKAGE = util.kind(super)

function $PACKAGE.ping(payload)
  -- sample message handling; try it with /ping
  orisa.send(orisa.sender, "pong", payload)
end

return $PACKAGE
]]

user.echo_template = etlua.compile [[<div class="echo"><%= text %></div>]]


return user