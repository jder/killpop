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
    
    <h2>Naming things</h2>
    <p>When referring to objects, you can either use their name, any aliases the creator provided,
    their object number (e.g. #123) or the special words <b>me</b> (meaning your user) or <b>here</b>,
    meaning the room you're in.

    <h2>Other Things</h2>
    <p>Here are some other things you might try:</p>
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
  name = "building", 
  summary = "How to build and edit out-of-character.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <p>In addition to "in game" verbs like <b>take</b> or <b>go</b>, there are also 
    a set of "out of game" commands which let you build new objects in the world.</p>
    <h2>Kinds</h2>
    <p>Every object has a kind, represented as a string like <b>system.object</b>.
    This corresponds to the name of a lua package whose code implements the behavior
    of that object.</p>
    <p>Standard types are named system.object, system.room, etc. You can make and
    edit code for your own types named e.g. <b><%= username %>/live.apple</b>. As a
    shortcut, you can refer to that as just <b>apple</b> in the commands below. Your own
    user has the type <b><%= username %>/live.user</b>.
    For example:
    <ul>
      <li><b>/create apple</b> -- creates a new object of type <b><%= username %>/live.apple</b>. 
      <li><b>/edit apple</b> -- brings up a code editor for all objects of type <b><%= username %>/live.apple</b>.
            See <b>/help objects</b> and <b>/help code</b>.
      <li><b>/dig north</b> -- creates a new <b>system.door</b> named "north" leading to a new
             <b>system.room</b>. This lets you then <b>go north</b>. You can also <b>/dig north #123</b>
              to connect to an existing room #123. 
    </ul>
    <h2>Parents</h2>
    <p>Objects form a tree of containment where each object has a parent. For example, your parent
    is usually the room you are in. You can move yourself and objects you own:
    <ul>
        <li><b>/move me #0</b> -- return to the entryway
        <li><b>/banish apple</b> -- sends the apple "away" (sets its parent to nil)
    </ul>
    <h2>Attributes</h2>
    <p>All objects have attributes which you can read, like <b>name</b> and <b>description</b>
    that are used by standard actions like <b>examine</b>. You can read these for any object
    and set them for your own objects. (See <b>/help objects</b> for more details.) For example:
    <ul>
      <li><b>/get here name</b> -- shows the name of the room you are in.
      <li><b>/set me description "Suave and sophisticated"</b> -- set a new description for yourself.
      The "value" there is a Lua expression (see the next section.)
    </ul>
    <h2>Running Code</h2>
    <p>You can use <b>/eval 1 + 2</b> or the shortcut <b>`1 + 2</b> (backtick) to evaluate a Lua
    expression. There is also <b>/run</b> which allows multiple statements separated by semicolons
    but requires you to <b>return</b> the final result, if any.</p>
  ]],
  function(topic)
    return topic.template({topic = topic, username = orisa.get_username(orisa.original_user)})
  end
}

topic { 
  name = "objects",
  summary = "The object and state model for Lua.",
  function()
    return "orisa.send, orisa.query, attrs, state, inheritance + privacy"
  end
}

topic { 
  name = "libs", 
  summary = "Utilities available to Lua code.",
  function()
    return "require & packages, util.*, etlua, logging, browser console"
  end
}

topic {
  name = "verbs", 
  summary = "How verbs and command-parsing work.",
  function()
    -- things usually trust the room they're in & rooms usually define common verbs
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