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
    a set of "out of game" commands which let you build new objects in the world. 
    These are implemented in <a href="https://github.com/jder/killpop/blob/master/user.lua">system.user</a>.</p>
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
      Click "save" to cause your edits to become live. See <b>/help objects</b> and <b>/help code</b> for more information.
      <li><b>/dig north</b> -- creates a new <b>system.door</b> named "north" leading to a new
             <b>system.room</b>. This lets you then <b>go north</b>. You can also <b>/dig north #123</b>
              to connect to an existing room #123. 
      <li><b>/x apple</b> -- get details of the apple, including its kind and number.
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
      The "value" there is a Lua expression. (See <b>/help code</b> for helpful tips about Lua code in Orisa.)
    </ul>
  ]],
  function(topic)
    return topic.template({topic = topic, username = orisa.get_username(orisa.original_user)})
  end
}

topic { 
  name = "objects",
  summary = "The object, state and permission model for Lua.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <h2>Message Sending</h2>
    <p>Objects are isolated Lua environments (per kind) which primarily communicate by
    sending messages or accessing attributes of other objects. You can send a message
    to another object with e.g. <b>orisa.send("#123", "hello", {foo = "bar"})</b> which
    sends the "hello" message to object #123 and passes it a Lua table, commonly called
    the "payload". See <b>/help messages</b> for commonly-used messages.</p>
    <p>The currently-running object is called <b>orisa.self</b>.</p>
    <h2>Message Handling & Kinds</h2>
    <p>When an object is sent a message, we load <a href="https://github.com/jder/killpop/blob/master/main.lua">system.main</a>
    to handle that message. It <b>require</b>s a Lua package named the same as the object's
    kind and calls the <b>handler</b> function in that package. These packages are typically 
    created with <a href="https://github.com/jder/killpop/blob/master/util.lua">system.util</a>'s
    <b>kind</b> function which installs a standard handler function that looks for a function
    of the same name of the message and calls it.</p>
    <p>For example, try creating an object and editing its code to see the auto-generated 
    code which does this and sets up an example message handler. 
    See <b>/help code</b> for more about how to write the bodies of these functions 
    and <b>/help api</b> for a list of all builtin functions.</p>
    <p>Verbs are special messages which can be invoked by the room based on user-entered text
    like <b>go north</b>. See <b>/help verbs</b> for more information.</p>
    <h2>State</h2>
    <p>The isolated Lua environments which objects run in are temporary (e.g. are thrown
    away whenever their code is edited or the server is restarted) so any state you would
    like to persist between messages needs to either be stored in <b>attrs</b> or in <b>state</b>. The only 
    difference is that <b>attrs</b> are visible to all other objects and <b>state</b> is not.
    You can store any JSON-like Lua structure in these (tables, numbers & strings).</p>
    <p>These are read/written with <b>orisa.get_attr(object, key)</b> and <b>orisa.set_attr(object, key, value)</b>,
    and analagous methods for state. These only work on <b>orisa.self</b> except for <b>orisa.get_attr</b>
    which allows you to read the attributes of any object.</p>
    <h2>Queries</h2>
    <p>You can send special messages via <b>orisa.query</b> which has the same form as <b>orisa.send</b>
    with these behavior differences:</p>
    <ul>
      <li> Messages are handled immediately (as opposed to asynchronously) and can return a result.
      <li> While handling a query message, you cannot cause side effects, such as setting state or sending messages.
    </ul>
    <p>This is useful for "computed properties" which are side-effect free.</p> 
    <h2>Permissions</h2>
    <p>Most fundamental operations are either unrestricted (e.g. sending messages, reading attrs) or restricted 
    to the object itself (e.g. setting attrs/state, sending text to the user). There are a few exceptions:
    <ul>
      <li><b>orisa.move_object</b> is permitted when the target and current object are in the same room.
      <li><b>system.object</b> supports a <b>set</b> messages from its owner (i.e. creator)
      to set its attributes. This is how the <b>/set</b> command works. (See <b>/help building</b>.)
      <li><b>system.user</b> forwards <b>tell</b> and <b>tell_html</b> messages to the orisa.send_user_* messages
      to display text to the user; the latter is only permitted for messages from the current room.
    </ul>
    <p>Ultimately we'd like to change this to a capabilities model which are passed along during message sends
    and checked via queries, with errors automatically captured & reported to the user.</p>
  ]],
  function(topic)
    return topic.template({topic = topic})
  end
}

topic { 
  name = "code", 
  summary = "Tips & utilities for Lua code.",
  summary = "The object and state model for Lua.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <h2>Editing Code</h2>
    <p>You can use the <b>/edit</b> command to edit (or view) code for non-system objects. See <b>/help building</b> for more.</p>
    <p>You should have your browser's Javascript console visible while doing this, as compile errors, runtime errors, 
    and output from the Lua <b>print</b> function will appear there.</p>
    <p>There is also a button in the UI which reloads the system code (from disk). In the future we'd like to support
    additional github repos for other users to have code e.g. <b><%= username %>/reponame.something</b>.</p>
    <h2>System Utilities</h2>
    <p>The <a href="https://github.com/jder/killpop/blob/master/utils.lua">system.utils</a> package includes 
    helpful utilities for common tasks, including helpers for defining new types, finding objects based
    on text descriptions, querying containment, and string manipulation. We'll probably break this up at some point.</p>
    <p>Unlike other system packages you must <b>require</b>, this is globally available as <b>utils</b>.</p>
    <h2>Logging</h2>
    <p>The system.utils package also includes a simple logging system. Calling <b>util.logger("foo")</b> returns a
    function which acts like <b>print(string.format(...))</b>, except it displays tables more nicely via util.tostring.
    These log messages are by default not shown but can be enabled/disabled with attributes on your user object. 
    A message will appear in your browser console with more instructions when you call code which uses these loggers.</p>
    <h2>Templating</h2>
    <p>The <a href="https://github.com/jder/killpop/blob/master/etlua.lua">system.etlua</a> package is a fork of 
    <a href="https://github.com/leafo/etlua">etlua</a> which allows simple HTML templating in your code, mainly for
    sending to a user via <b>orisa.send_user_tell_html</b>. Note that our version allows access to the global environment
    which includes the <b>utils</b> global.
  ]],
  function(topic)
    return topic.template({topic = topic, username = orisa.get_username(orisa.original_user)})
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

-- topic { 
--   name = "concurrency", 
--   summary = "Details of message-sending, visibility, isolation.",
--   function()
--     return "single-threaded today, separate lua VMs per kind but might change to per user; snapshot isolation but could have write-skew someday"
--   end
-- }

-- topic { 
--   name = "contrib", 
--   summary = "How to help with Orisa.",
--   function()
--     return "links to github, todo/idea lists, etc"
--   end
-- }

return help