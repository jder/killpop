local commands = {}

local util = require "system.util"

local prepositions = {
  with = true, 
  at = true, 
  to = true, 
  from = true, 
  on = true, 
  under = true
}

local log = util.logger("commands")

--- Breaks text into the following pieces based on the lambdamoo parsing structure.
--- (Any of these could be missing. A missing verb means the text was empty.)
--- * verb
--- * direct_object a nil or a table with {found = {...}, text = "..."}
---   where "found" is a possibly-empty list of matching objects and "text" is the matched text with spaces normalized
--- * preposition from the above list, text
--- * indirect_object is nil or a table just like direct_object
function commands.parse_user(text)
  log("Parsing text %q", text)

  local words = {}
  local preposition_index = nil
  local direct_object_text = nil
  local indirect_object_text = nil
  for w in string.gmatch(string.lower(text), "%g+") do
    table.insert(words, w)
    if prepositions[w] and preposition_index == nil then
      preposition_index = #words
    end
  end

  local result = {text = text}
  if #words == 0 then
    return result
  end

  result.verb = words[1]
  if preposition_index then
    if preposition_index > 2 then
      direct_object_text = table.concat(words, " ", 2, preposition_index - 1)
    end

    result.preposition = words[preposition_index]

    assert(preposition_index < #words, string.format("expected an indirect object after %s in %s", result.preposition, text))
    indirect_object_text = table.concat(words, " ", preposition_index + 1)
  elseif #words > 1 then
    -- no preposition, everything is direct object
    direct_object_text = table.concat(words, " ", 2)
  end

  if direct_object_text then
    result.direct_object = {found = util.find_all(direct_object_text), text = direct_object_text}
  end

  if indirect_object_text then
    result.indirect_object = {found = util.find_all(indirect_object_text), text = indirect_object_text}
  end

  log("Parse result: %s", result)
  return result
end

--- Parses a textual pattern for a verb to be matched against a user command
--- The general form of the verb pattern is a sequence of space separated pieces:
--- * the verb itself, with options separated by |. Required.
--- * the direct object specifier, which may be absent or $this or $any. (TODO: maybe types or requiring single-matches in the future)
--- * the preposition specifier, with options separated by |. Required if there is an indirect object specifier.
--- * the indirect object specifier, which may be absent or $this or $any. 
--- For example:
--- give|hand $this to $any
--- jump on $this
function commands.parse_matcher(text)
  -- todo: memoize
  log("Parsing matcher %q", text)
  local verb_options = nil
  local direct_type = nil
  local preposition_options = nil
  local indirect_type = nil

  for w in string.gmatch(string.lower(text), "%g+") do
    if verb_options == nil then
      verb_options = {}
      for _, v in ipairs(util.split_punct(w, "|")) do
        verb_options[v] = true
      end
    else
      if w == "$this" or w == "$any" then
        if preposition_options == nil then
          assert(direct_type == nil, string.format("set direct_type twice; was %s now %s in %s", direct_type, w, text))
          direct_type = w
        else
          assert(indirect_type == nil, string.format("set indirect_type twice; was %s now %s in %s", indirect_type, w, text))
          indirect_type = w
        end
      else
        assert(preposition_options == nil, string.format("set preposition_options options twice; was %s now %s in %s", preposition_options, w, text))
        -- not a verb or object specifier, must be preposition
        pieces = util.split_punct(w, "|")
        preposition_options = {}
        for _, p in ipairs(pieces) do
          assert(prepositions[p], string.format("%s is not a known preposition in %s", p, text))
          preposition_options[p] = true
        end
      end
    end
  end

  assert(verb_options, string.format("missing verb options in %s", text))
  assert(preposition_options ~= nil or indirect_type == nil, string.format("can't have indirect type %s without prepositions in %s", indirect_type, text))

  local result = {
    verb_options = verb_options,
    direct_type = direct_type or "$none",
    preposition_options = preposition_options or {},
    indirect_type = indirect_type or "$none"
  }
  log("Parse result: %s", result)
  return result
end

function match_type(object, type, verb_owner)
  if type == "$none" then
    return object == nil
  elseif type == "$any" then
    return true
  elseif type == "$this" then
    if object == nil then
      return false
    end
    for _, o in ipairs(object.found) do
      if o == verb_owner then
        return true
      end
    end
    return false
  else
    assert(false, string.format("unknown object type %s", type))
  end
end

function commands.match(user, matcher, verb_owner)
  log("Matching %q with matcher %s for %s", user.text, nil, verb_owner)
  if not (user.verb and matcher.verb_options[user.verb]) then
    log("Verb %s not in options %s", user.verb, matcher.verb_options)
    return false
  end

  if not match_type(user.direct_object, matcher.direct_type, verb_owner) then
    log("Direct object %s did not match type %s", user.direct_object, matcher.direct_type)
    return false
  end

  if not match_type(user.indirect_object, matcher.indirect_type, verb_owner) then
    log("Indirect object %s did not match type %s", user.indirect_object, matcher.indirect_type)
    return false
  end

  -- if there is a preposition, it must match
  -- if you didn't specify one and we expected one, we'll catch it in matching indirect object
  -- since we have prepositions iff we have an indirect object
  if user.preposition and not matcher.preposition_options[user.preposition] then
    log("Preposition %s not allowed by %s", user.preposition, matcher.preposition_options)
    return false
  end

  log("successful match")
  return true
end

--- Takes direct_object/indirect_object info
--- Returns (thing, optional_message) if there is one clear candidate
--- If there is more than one, returns (nil, message_for_user)
--- In the future we can pass more options here to help pick smartly,
--- have match scores, etc
function commands.disambig_object(object_info)
  if not object_info then
    return nil, "Expected some object."
  elseif #object_info.found == 0 then
    return nil, string.format("I don't see %q here.", object_info.text)
  elseif #object_info.found > 1 then
    local holding = {}
    for _, match in ipairs(object_info.found) do
      if orisa.get_parent(match) == orisa.original_user then
        table.insert(holding, match)
      end
    end

    if #holding == 1 then
      return holding[1], string.format("(Assuming the %s you are holding.)", object_info.text)
    end

    local options = {}
    for _, match in ipairs(object_info.found) do
      table.insert(options, string.format("%s (%s)", util.get_name(match), match))
    end
    return nil, string.format("Sorry, %q is ambiguous; could be: %s", object_info.text, table.concat(options, " or "))
  else
    return object_info.found[1], nil
  end
end

return commands