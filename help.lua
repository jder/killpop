local help = {}

local util = require "system.util"
local etlua = require "system.etlua"

local topics = {}

local function topic(t)
  setmetatable(t, {__call = function(...) return t[1](...) end})
  table.insert(topics, t)
  help[t.name] = t
end

local template_top = etlua.compile [[
  <h1>Welcome to Orisa</h1>
  <p>Orisa is a collaborative programming environment, chat room, and game.</p>
  <p>Here are some topics you can ask about:</p>
  <ul>
  <% for _, topic in ipairs(topics) do %>
    <li><b>/help <%= topic.name %></b> -- <%= topic.summary %></li>
  <% end %>
]]

function help.top()
  return template_top({topics = topics})
end

topic { 
  name = "basics", 
  summary = "Talking and walking around the world.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <h2>Talking</h2>
    <p>You can talk to others in the same room you're in by 
    starting any command with <b>"</b> or <b>'</b>, for example <b>"hello</b>. </p>
    <h2>Looking Around</h2>
    <p>You can get a description of where you are with <b>look</b> or <b>l</b>.
    To get a closer look at something, you can use <b>examine (something)</b> or <b>x (something)</b>. 
    For example <b>x apple</b> to look at an apple.</p>
    <h2>Other Commands</h2>
    <p>Here are some other commands you might try:</p>
    <ul>
      <li><b>go (direction)</b> to travel from your current location.
      <li><b>take (something)</b> to pick something up.
      <li><b>inventory</b> or <b>i</b> to see what you're holding.
      <li><b>drop (something)</b> to get rid of something you're holding.
    </ul>
  ]],
  function(topic)
    print(topic, topic.name)
    return topic.template({topic = topic})
  end
}

topic { 
  name = "commands", 
  summary = "How to build and edit out-of-character.",
  function()
    return "kinds, /create, /edit, /get, /set, /dig, /eval, /run etc"
  end
}

topic { 
  name = "objects", 
  summary = "How to write Lua code for an object's behavior.",
  function()
    return "packages, orisa.send, orisa.query, attrs, state, inheritance + privacy"
  end
}

topic { 
  name = "libs", 
  summary = "Standard libraries available to Lua code.",
  function()
    return "require & packages, util.*, etlua, logging, browser console"
  end
}

topic {
  name = "verbs", 
  summary = "How verbs and command-parsing work.",
  function()
    return "util.verb, objects, patterns, etc"
  end
}

topic { 
  name = "api", 
  summary = "Reference docs for orisa built-in functions.",
  function()
    return "auto-generated docs here"
  end
}

topic { 
  name = "messages", 
  summary = "Reference for the standard messages between objects.",
  function()
    return "auto-generated docs here + sub-topics for each e.g. created"
  end
}

topic { 
  name = "attrs", 
  summary = "Standard attributes and how they are used.",
  function()
    return "name, ~kind, aliases, owner, etc"
  end
}

topic { 
  name = "concurrency", 
  summary = "Details of message-sending, visibility, isolation.",
  function()
    return "asyncness, separate lua VMs, snapshot isolation but could have write-skew someday"
  end
}

topic { 
  name = "contrib", 
  summary = "How to help with Orisa.",
  function()
    return "links to github, todo/idea lists, etc"
  end
}

return help