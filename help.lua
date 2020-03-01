local help = {}

local util = require "system.util"
local etlua = require "system.etlua"
local commands = require "system.commands"

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
    <h2>Communicating</h2>
    <p>You can talk to others in the same room you're in by 
    starting any command with <b>"</b> or <b>'</b>, for example <b>"Hello!</b></p>
    <p>You can also "emote", or perform actions by starting any command with : or 
    /me, for example <b>/me does a silly dance</b></p>
    <p>If you want to send a message to someone who isn't in the room,
    you can send a private message to them from anywhere with /tell, like <b>/tell
    YourFriend Hi there this is a private message!.</p>
    
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
      <li><b>drop (something)</b> to drop something you're holding in the room you're in.
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
      <li><b>/edit <%= username%>/live.apple</b> or <b>/edit apple</b> -- brings up a code editor for all objects of type <b><%= username %>/live.apple</b>.
      Click "save" to cause your edits to become live. (For now you have to try running that code before you will see errors.)
      See <b>/help objects</b> and <b>/help code</b> for more information.
      <li><b>/edit system.room</b> -- shows default code for rooms. You can't save code for system or other user's kinds but you can view it.
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
      <li><b>/edit me description</b> -- bring up the current value in the code editor for changing.
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
    <h2>Containment</h2>
    <p>Objects form a tree where each has an optional parent. The top-most parent of a given object
    is known as the "room" that object is in. You can inspect this tree with <b>orisa.get_parent(object)</b>
    and <b>orisa.get_children(object)</b> and alter it with <b>orisa.move_object(object, new_parent)</b>.
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
    <p>You can use the <b>/edit</b> command to edit (or view) code for any object. See <b>/help building</b> for more.</p>
    <p>You should have your browser's Javascript console visible while doing this, as compile errors, runtime errors, 
    and output from the Lua <b>print</b> function will appear there.</p>
    <p>Lua's standard <b>require</b> function acts slightly differently, allowing loading pre-packaged code from 
      <a href="https://github.com/jder/killpop/">the system repo</a> with names like <b>system.apple</b> and code from
      users, edited live in the UI with names like <b><%= username %>/live.apple</b>. 
    <p>There is also a button in the UI which reloads the system code (from disk). In the future we'd like to support
    additional github repos for other users to have code e.g. <b><%= username %>/reponame.something</b>.</p>
    <h2>System Utilities</h2>
    <p>The <a href="https://github.com/jder/killpop/blob/master/util.lua">system.util</a> package includes 
    helpful utilities for common tasks, including helpers for defining new types, finding objects based
    on text descriptions, querying containment, and string manipulation. We'll probably break this up at some point.</p>
    <p>Unlike other system packages you must <b>require</b>, this is globally available as <b>util</b>.</p>
    <h2>Logging</h2>
    <p>The system.util package also includes a simple logging system. Calling <b>util.logger("foo")</b> returns a
    function which acts like <b>print(string.format(...))</b>, except it displays tables more nicely via util.tostring.
    These log messages are by default not shown but can be enabled/disabled with attributes on your user object. 
    A message will appear in your browser console with more instructions when you call code which uses these loggers.</p>
    <h2>Templating</h2>
    <p>The <a href="https://github.com/jder/killpop/blob/master/etlua.lua">system.etlua</a> package is a fork of 
    <a href="https://github.com/leafo/etlua">etlua</a> which allows simple HTML templating in your code, mainly for
    sending to a user via <b>orisa.send_user_tell_html</b> (typically via sending a "tell_html" message to the user).
    Note that our version allows access to the global environment which includes the <b>util</b> global.
  ]],
  function(topic)
    return topic.template({topic = topic, username = orisa.get_username(orisa.original_user)})
  end
}

topic {
  name = "verbs", 
  summary = "How verbs and command-parsing work.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <p>Verbs are messages which have special metadata allowing the command-parser to call them based on user-entered text.
    This parsing and dispatch is done by rooms, and many of the common verbs are also defined on rooms. This is helpful
    because it reduces ambiguity and the room you're in is somewhat trusted by objects in it and so defines the basic
    rules for this space.</p>
    <h2>Defining New Verbs</h2>
    <p>You can define new verbs on your object or room by editing its code (see <b>/help building</b>) and using 
    <b>util.verb</b> to create a new verb. This function takes a table which contains 2 values:</p>
    <ul>
      <li>At index [1]: A string (or list of strings) giving the patterns that the verb matches, like <b>eat $this</b>.
      <li>At index [2]: A function to call to run the behavior of this verb.
    </ul>
    <p>There are other (named) properties you can set on this to control the verb behavior:</p>
    <ul>
        <li><b>priority</b> -- to give hints about how likely it is someone means to use this verb when there are other matching verbs. 
        Can be one of the constants in <b>util.priority.*</b>. By default verbs are <b>util.priority.normal</b>.
    </ul>
    <p>The result of <b>util.verb</b> must be assigned to a function in your object's package, so it is invoked when
      your object receives this message. For example:</p>
    <b>my_kind.eat = util.verb { "eat $this", function(payload) ... end }</b>
    <h2>Patterns</h2>
    <p>The general form of the verb pattern is a sequence of space-separated pieces:</p>
    <ul>
      <li>the verb itself, with options separated by <b>|</b> (a vertical bar). Required.
      <li>the direct object specifier, which may be absent or <b>$this</b> or <b>$any</b>. 
      <li>the preposition specifier, with options separated by <b>|</b> (a vertical bar). Required if there is an indirect object specifier.
        Only these prepositions are supported: <%= table.concat(prepositions, ", ") %>.
      <li>the indirect object specifier, which may be absent or <b>$this</b> or <b>$any</b>. 
    </ul>
    <p>For example: <b>give|hand $this to $any</b> or <b>jump on $this</b></p>
    <p>If you use <b>$this</b> that means the user must specify something which refers to the object which the verb is defined on.
    <b>$any</b> matches text referring to any object.</p>
    <h2>Payload & Disambiguation</h2>
    <p>When your verb pattern is matched by user text, the message sent has a payload with the following keys:</p>
    <ul>
      <li><b>user</b> -- the user which is acting
      <li><b>room</b> -- the room the user is in
      <li><b>command</b> -- the parsed command, with keys:
      <ul>
        <li><b>verb</b> -- the string matching the verb (i.e. one of the options from your patterns)
        <li><b>direct_object</b> -- nil or a table with:
          <ul><li><b>found</b> is a possibly-empty list of matching objects
              <li><b>text</b> is the matched text with single-spaced words
          </ul>
        <li><b>preposition</b> from the above list as a string
        <li><b>indirect_object</b> is nil or a table just like <b>direct_object</b>
      </ul>
    </ul>
    <p>Note that the <b>direct_object</b> and <b>indirect_object</b> could include multiple options and it is up to your verb
    to pick one or give an error. There is a helper function in <b>system.commands</b> called <b>disambig_object</b> which can 
    help here. Take a look at <a href="https://github.com/jder/killpop/blob/master/room.lua">system.room</a> for examples.</p>
    <p>You typically end by using the <b>tell</b> to the user or <b>tell_action</b> to the room. (See <b>/help messages</b> for more.)</p>
  ]],
  function(topic)
    local preps = {}
    for k, _ in pairs(commands.prepositions) do
      table.insert(preps, k)
    end
    table.sort(preps)
    return topic.template({topic = topic, prepositions = preps})
  end
}

topic { 
  name = "api", 
  summary = "Reference docs for orisa built-in functions.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    I'd like to have auto-generated docs here. In the meantime you can look at
    <a href="https://github.com/jder/orisa/blob/ec9f8da2a53ad1e1ea5b321a256c620b8e21717a/server/src/object/api.rs#L385">api.rs</a>
    which registers all the built-in functions.
  ]],
  function(topic)
    return topic.template({topic = topic})
  end
}

topic { 
  name = "messages", 
  summary = "Reference for the standard messages between objects.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    I'd like to have auto-generated docs here + sub-topics for each, which are type-checked 
    in main.lua when a message is received. In the meantime, here are some of the most important messages:
    <ul>
      <li><b>tell</b> with a payload of <b>{message = (some string)}</b> is sent to user objects to display text to the user.
      <li><b>tell_html</b> with a payload of <b>{html = (some string)}</b> is sent from rooms only to users to display HTML messages.
      <li><b>tell_action</b> with a payload of <b>{user = (some user), me = (some string), others = (some string)}</b> sent to 
      rooms to inform everyone in that room that the given user has taken some action (with the "others" text) and sent to the user
      themselves to inform them of their action (with the "me" text).
      <li><b>created</b> is a message sent to each object when it is first created to do initialization. The payload is passed 
      along from the <b>orisa.create_object</b> call. Take a look at <a href="https://github.com/jder/killpop/blob/master/user.lua">system.user</a>'s 
      <b>do_create</b> function for an example and <a href="https://github.com/jder/killpop/blob/master/object.lua">system.object</a> for handling
      of it. That handling also supports allows sub-kinds to do their own initialization. See <a href="https://github.com/jder/killpop/blob/master/door.lua">system.door</a>
        for an example.
      <li><b>command</b> with a payload of <b>{message = (some string)}</b> is sent to the user object when the user types text in the UI. The user object
      (if it doens't handle the command) sends it to the room to trigger verb parsing and acting. (See <b>/help verbs</b> for more.)
      <li><b>say</b> with a payload of <b>{message = (some string)}</b> sent to a room is how you speak in that room.
      <li><b>parent_changed</b> and <b>child_added</b> which are sent after a successful move with payload keys of <b>child</b> and <b>new_parent</b>.
      <li><b>connected</b> and <b>disconnected</b> are sent to your user object when your chat connection connects and disconnects</b>.
  ]],
  function(topic)
    return topic.template({topic = topic})
  end
}

topic { 
  name = "attrs", 
  summary = "Standard attributes and how they are used.",
  template = etlua.compile [[
    <h1><%= util.title(topic.name) %></h1>
    <p>Common attrs:</p>
    <ul>
      <li><b>name</b> -- displayed as the name of an object in look/examine descriptions. Also can be used to refer to this object in commands.
      <li><b>aliases</b> -- a list of additional strings that can be used to refer to this object in commands.
      <li><b>description</b> -- shown in response to <b>examine</b>
      <li><b>owner</b> -- set by <b>system.object</b> at creation time to a privileged object who can set attributes with the <b>set</b> message.
      <li><b>hidden</b> -- boolean attribute; if true, this object is not mentioned in <b>look</b>.
      <li><b>log_$name</b> -- boolean set on users to turn on/off log messages for the logger with name <b>$name</b>. 
    </ul>
    <p>Kind is not an attr (maybe it should be), but you can <b>orisa.get_kind(object)</b> to find out its kind.</p>
    <p>Similarly, the username of a given user is not an attr, but you can <b>orisa.get_username(object)</b>. (Though typically you'd just use <b>util.get_name</b>.)</p>
    <p>See <b>/help building</b> and <b>/help objects</b> for how to get and set attrs.</p>
  ]],
  function(topic)
    return topic.template({topic = topic})
  end
}

topic { 
  name = "concurrency", 
  summary = "Details of message-sending, visibility, isolation.",
  function()
    return "TODO. Single-threaded today, separate lua VMs per kind but might change to per user or shard further by object id. We'll ensure consistent read snapshots but could have write-skew someday when we multithread."
  end
}

return help