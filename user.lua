local util = require "system.util"
local etlua = require "system.etlua"
local help = require "system.help"

local super = require "system.object"

local user = util.kind(super)

-- templates

local edit_template = [[
local util = require "system.util"
local super = require "$FALLBACK"
local $PACKAGE = util.kind(super)

function $PACKAGE.ping(payload)
  -- sample message handling; try it with /ping
  orisa.send(orisa.sender, "pong", payload)
end

return $PACKAGE
]]

local echo_template = etlua.compile [[<div class="echo"><%= text %></div>]]
local plain_template = etlua.compile [[<div class="text"><%= text %></div>]]

local function tell_html_with_history(html)
  orisa.send_user_tell_html(html)
  local history = orisa.get_state(orisa.self, "history")
  if not history then
    history = {}
  end
  table.insert(history, html)
  -- truncate history to latest 50% of rows once hits capacity
  local max_history = 100
  if #history > max_history then
    history = table.move(history, max_history/2, #history, 1, {})
  end
  orisa.set_state(orisa.self, "history", history)
end

local function text_reply(text)
  tell_html_with_history(plain_template({text = text}))
end

local function run_fallback(text)
  text_reply(string.format("Unknown command: %q", text))
end

local function run_command(text)
  orisa.send(util.current_room(orisa.self), "command", {message = text})
end

local function run_say(text)
  orisa.send(orisa.get_parent(orisa.self), "say", {message = text})
end

local function run_run(cmd) 
  local chunk, err = load(cmd, "command", "t")
  if not chunk then
    text_reply("Compile Error: " .. err)
  else
    local success, result = pcall(chunk)
    if success then
      text_reply("Result: " .. tostring(result))
    else
      text_reply("Runtime Error: " .. tostring(result))
    end
  end
end

local function run_eval(cmd)
  return run_run("return (" .. cmd .. ")")
end

local function run_help(topic, rest)
  if help[topic] then
    tell_html_with_history(help[topic](rest))
  else
    user.tell(string.format("No help found on %q", topic))
  end
end

local function run_help_top()
  run_help("top")
end

local function run_examine(query)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end

  local prefix = util.get_name(target) .. " (" .. target .. ", " .. orisa.get_kind(target) .. ")"
  local description = orisa.get_attr(target, "description")
  if description == nil then
    text_reply(prefix .. " has no description.")
  else
    text_reply(prefix .. ": " .. description)
  end

  local parent = orisa.get_parent(target)
  if parent then
    text_reply(string.format("Parent is %s (%s)", util.get_name(parent), parent))
  else
    text_reply("Has no parent.")
  end

  local children = orisa.get_children(target)
  local contents = "Contents: "
  for i, child in ipairs(children) do
    if i ~= 1 then
      contents = contents .. ", "
    end
    contents = contents .. util.get_name(child) .. " (" .. child .. ")"
  end
  text_reply(contents)
end

local function expand_kind(kind)
  local top, package = util.split_kind(kind)
  if top == nil then
    -- probably just "cake" instead of "jder/live.cake"
    kind = string.format("%s/live.%s", orisa.get_username(orisa.self), kind)
  end
  return kind
end

local function run_edit(kind)
  kind = expand_kind(kind)
  local current = orisa.get_package_content(kind)
  if current == nil then
    local top, package = util.split_kind(kind)
    local fallback = "system.object"
    if package == "user" then
      fallback = "system.user"
    end
    current = edit_template
    current = string.gsub(current, "$PACKAGE", package)
    current = string.gsub(current, "$FALLBACK", fallback)
  end
  orisa.send_user_edit_file(kind, current)
end

local function run_set(query, attr, value)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end

  local chunk, err = load("return (" .. value .. ")", "value", "t")
  if not chunk then
    text_reply("Error parsing value: " .. err)
    return
  end

  local success, result = pcall(chunk)
  if not success then
    text_reply("Error evaluating value: ".. result)
    return
  end

  orisa.send(target, "set", {name = attr, value = result})
end

local function run_get(query, attr)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end

  text_reply(string.format("%s.%s is %s", util.get_name(target), attr, orisa.get_attr(target, attr)))
end

local function run_ping(query)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end

  text_reply("sending ping to " .. util.get_name(target))
  orisa.send(target, "ping")
end

local function run_move(query, dest_query)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end

  local dest = util.find(dest_query)
  if dest == nil then 
    text_reply("I don't see " .. dest_query)
    return
  end

  orisa.send(target, "move", {destination = dest})
end

local function run_banish(query)
  local target = util.find(query)
  if target == nil then 
    text_reply("I don't see " .. query)
    return
  end
  orisa.send(target, "move", {destination = nil})
end

local function run_create(kind)
  orisa.create_object(orisa.self, expand_kind(kind), {owner = orisa.self})
end

local function run_dig(direction, destination_query)
  local parent = orisa.get_parent(orisa.self)
  if parent == nil then
    text_reply("You aren't anywhere.")
    return
  end
  
  local destination = nil
  if destination_query ~= nil then
    destination = util.find(destination_query)
    if destination == nil then
      text_reply("I don't see " .. destination_query .. " anywhere.")
      return
    end
  end

  orisa.create_object(parent, "system.door", {owner = orisa.self, direction = direction, destination = destination})
end

local function run_dig_reciprocal(direction, reciprocal_direction, destination_query)
  local parent = orisa.get_parent(orisa.self)
  if parent == nil then
    text_reply("You aren't anywhere.")
    return
  end

  local destination = nil
  if destination_query ~= nil then
    destination = util.find(destination_query)
    if destination == nil then
      text_reply("I don't see " .. destination_query .. " anywhere.")
      return
    end
  else
    destination = orisa.create_object(nil, "system.room", {owner = orisa.self})
  end
  
  orisa.create_object(parent, "system.door", {owner = orisa.self, direction = direction, destination = destination})
  orisa.create_object(destination, "system.door", {owner = orisa.self, direction = reciprocal_direction, destination = parent})
end


--- Matches patterns and calls functions with the captures
-- TODO: some actual parsing so we don't reject extra args like `/l foo` as "unknown command /l"
local function parse_user_command(text, patterns)
  for pat, handler in pairs(patterns) do
    if pat ~= "default" then
      local captures = {string.match(text, pat)}
      if captures[1] ~= nil then
        local echo = true
        if type(handler) == "table" then
          echo = handler.echo
          handler = handler.handler
        end
        if echo then
          tell_html_with_history(echo_template({text = text}))
        end
        handler(table.unpack(captures))
        return
      end
    end
  end
  if patterns.default then
    patterns.default(text)
  end
end

function user.command(payload)
  assert(orisa.sender == orisa.self, "refusing to run command from someone other than ourselves") -- only run commands from the user
  local patterns = {
    ["^`(.*)"] = run_eval,
    ["^[\"'](.*)"] = {handler = run_say, echo = false},
    ["^/say *(.*)"] = {handler = run_say, echo = false},
    ["^/run (.*)"] = run_run,
    ["^/eval (.*)"] = run_eval,
    ["^/examine *(.*)"] = run_examine,
    ["^/x *(.*)"] = run_examine,
    ["^/edit +(%g+)$"] = run_edit,
    ["^/set +(%g+) +(%g+) +(.+)"] = run_set,
    ["^/get +(%g+) +(%g+)$"] = run_get,
    ["^/ping +(%g+)$"] = run_ping,
    ["^/move +(%g+) +(%g+)$"] = run_move,
    ["^/banish +(%g+)$"] = run_banish,
    ["^/b +(%g+)$"] = run_banish,
    ["^/create +(%g+)$"] = run_create,
    ["^/dig +(%g+)|(%g+)$"] = run_dig_reciprocal,
    ["^/dig +(%g+)|(%g+) +(.+)"] = run_dig_reciprocal,
    ["^/dig +(%g+)$"] = run_dig,
    ["^/dig +(%g+) +(.+)"] = run_dig,
    ["^/help *$"] = run_help_top,
    ["^/help +([a-z%.]+) *$"] = run_help,
    ["^/help +([a-z%.]+) +(.+)"] = run_help,
    ["^([^/`'\"].*)"] = run_command,
    default = run_fallback
  }
  parse_user_command(payload.message, patterns)
end

function user.tell(payload)
  text_reply(payload.message)
end

function user.tell_html(payload)
  if orisa.sender ~= util.current_room(orisa.self) and orisa.sender ~= orisa.self then
    print("Ignoring html tell from someone other than the room or self")
    return
  end

  tell_html_with_history(payload.html)
end

function user.connected(payload)
  local history = orisa.get_state(orisa.self, "history")
  if history then
    orisa.send_user_backlog_html(history)
  end
  text_reply("Welcome! Run /help to see available help.")
  orisa.send(orisa.get_parent(orisa.self), "tell_others", {message = string.format("%s wakes up.", orisa.get_username(orisa.self))})
end

function user.disconnected(payload)
  orisa.send(orisa.get_parent(orisa.self), "tell_others", {message = string.format("%s goes to sleep.", orisa.get_username(orisa.self))})
end

function user.save_file(payload)
  orisa.send_save_package_content(payload.name, payload.content)
end

function user.pong(payload)
  text_reply("got pong from " .. util.get_name(orisa.sender))
end

function user.parent_changed(payload)
  run_command("look")
end

return user
