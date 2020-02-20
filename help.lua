local help = {}

local util = require "system.util"
local etlua = require "system.etlua"

local topics = {}

local function topic(t)
  setmetatable(t, {__call = function(t, ...) return t[1](...) end})
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
  function()
    return "say, go, look, inspect, etc"
  end
}

topic { 
  name = "building", 
  summary = "How to build and edit new objects.",
  function()
    return "kinds, /create, /edit, /get, /set, /dig, etc"
  end
}

topic { 
  name = "code", 
  summary = "How to write Lua code for an object's behavior.",
  function()
    return "/eval, /run, orisa.send, orisa.query, attrs, state, inheritance + privacy, browser console"
  end
}

topic { 
  name = "libs", 
  summary = "Standard libraries available to Lua code.",
  function()
    return "require & packages, util.*, etlua, logging"
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